import AppKit
import AVFoundation
import Observation

/// Owns the player, starts the video over when it ends if looping is on,
/// and publishes the playback state that the custom controls display.
@Observable
final class Player {
  let queuePlayer = AVQueuePlayer()
  private let asset: AVAsset

  /// Whether the video starts over when it reaches the end.
  var isLooping: Bool

  /// Seconds into the current pass through the video.
  private(set) var currentTime: Double = 0
  /// Length of the video in seconds, or 0 until it has loaded.
  private(set) var duration: Double = 0
  private(set) var isPlaying = false

  /// Details for the movie inspector. Nil until they've loaded.
  private(set) var info: VideoInfo?

  @ObservationIgnored private var timeObserver: Any?
  @ObservationIgnored private var endObserver: Task<Void, Never>?

  init(url: URL, looping: Bool) {
    let item = AVPlayerItem(url: url)
    asset = item.asset
    isLooping = looping

    // Stop on the last frame at the end, rather than removing the video from
    // the player. Looping, when it's on, is handled in itemDidReachEnd().
    queuePlayer.actionAtItemEnd = .pause
    queuePlayer.insert(item, after: nil)

    endObserver = Task { [weak self] in
      let ends = NotificationCenter.default.notifications(
        named: AVPlayerItem.didPlayToEndTimeNotification,
        object: item
      )
      for await _ in ends {
        self?.itemDidReachEnd()
      }
    }

    Task {
      let length = try? await item.asset.load(.duration).seconds
      if let length, length.isFinite {
        duration = length
      }
    }

    Task {
      info = await VideoInfo.load(from: url, asset: item.asset)
    }

    // The observer is delivered on the main queue, so it's safe to update
    // the main-actor state directly.
    timeObserver = queuePlayer.addPeriodicTimeObserver(
      forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600),
      queue: .main
    ) { [weak self] time in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.currentTime = time.seconds.isFinite ? time.seconds : 0
        self.isPlaying = self.queuePlayer.rate != 0
      }
    }
  }

  deinit {
    if let timeObserver {
      queuePlayer.removeTimeObserver(timeObserver)
    }
    endObserver?.cancel()
  }

  private func itemDidReachEnd() {
    if isLooping {
      queuePlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
      queuePlayer.play()
    } else {
      isPlaying = false
    }
  }

  func togglePlayback() {
    if queuePlayer.rate == 0 {
      // With looping off, playing again after the end starts from the top.
      if let item = queuePlayer.currentItem, item.currentTime() >= item.duration {
        queuePlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
      }
      queuePlayer.play()
    } else {
      queuePlayer.pause()
    }
    isPlaying = queuePlayer.rate != 0
  }

  /// Copies the frame on screen to the clipboard as an image, at the video's
  /// full resolution.
  func copyCurrentFrame() async {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    // Exactly the frame being shown, not the nearest keyframe.
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero

    do {
      let (cgImage, _) = try await generator.image(
        at: queuePlayer.currentTime()
      )
      let image = NSImage(cgImage: cgImage, size: .zero)
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.writeObjects([image])
    } catch {
      NSSound.beep()
    }
  }

  /// Moves forward by the given number of seconds, or back if it's negative,
  /// stopping at the start or end of the video.
  func skip(bySeconds seconds: Double) {
    guard duration > 0 else { return }
    seek(toFraction: (currentTime + seconds) / duration)
  }

  /// What the arrow keys do, as QuickTime Player does it: while playing, skip
  /// 5 seconds; while paused, move one frame at a time.
  func arrowKey(forward: Bool) {
    if queuePlayer.rate != 0 {
      skip(bySeconds: forward ? 5 : -5)
    } else {
      queuePlayer.currentItem?.step(byCount: forward ? 1 : -1)
    }
  }

  /// Jumps to a position in the video, where 0 is the start and 1 is the end.
  func seek(toFraction fraction: Double) {
    guard duration > 0 else { return }
    let clamped = min(max(fraction, 0), 1)
    currentTime = clamped * duration
    queuePlayer.seek(
      to: CMTime(seconds: currentTime, preferredTimescale: 600),
      toleranceBefore: .zero,
      toleranceAfter: .zero
    )
  }
}
