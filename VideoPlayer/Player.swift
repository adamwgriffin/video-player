import AVFoundation
import AppKit
import Observation

/// Owns the player, starts the video over when it ends if looping is on,
/// and publishes its playback state, such as the current time, for display.
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

  /// Where playback begins again when it loops or restarts, in seconds.
  private(set) var startTime: Double = 0
  /// Where playback stops or loops, in seconds. Nil means the end of the video.
  private(set) var endTime: Double?

  /// Details about the video file, such as its codecs and size. Nil until
  /// they've loaded.
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
      info = await VideoInfoLoader(url: url, asset: item.asset).load()
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
      seekToStartTime()
      queuePlayer.play()
    } else {
      isPlaying = false
    }
  }

  func togglePlayback() {
    if queuePlayer.rate == 0 {
      // Frame steps move the position without updating this, so check it
      // against the end time before playing.
      updatePlaybackEnd(forPosition: queuePlayer.currentTime().seconds)

      // With looping off, playing again after the end starts from the start
      // time. The end is the end time if it applies.
      if let item = queuePlayer.currentItem {
        let end = item.forwardPlaybackEndTime.isValid ? item.forwardPlaybackEndTime : item.duration
        if item.currentTime() >= end {
          seekToStartTime()
        }
      }
      queuePlayer.play()
    } else {
      queuePlayer.pause()
    }
    isPlaying = queuePlayer.rate != 0
  }

  /// Makes the current position the start time. Beeps and does nothing if it
  /// isn't before the end time.
  func setStartTime() {
    let time = queuePlayer.currentTime().seconds
    guard time.isFinite else { return }
    if let endTime, time >= endTime {
      NSSound.beep()
      return
    }
    startTime = time
  }

  /// Makes the current position the end time. Beeps and does nothing if it
  /// isn't after the start time.
  func setEndTime() {
    let time = queuePlayer.currentTime().seconds
    guard time.isFinite else { return }
    guard time > startTime else {
      NSSound.beep()
      return
    }
    endTime = time
    updatePlaybackEnd(forPosition: time)
  }

  /// Whether a start or end time has been set, so there's a trimmed range to
  /// export.
  var isTrimmed: Bool {
    startTime > 0 || endTime != nil
  }

  /// The part of the picture to keep when exporting, as fractions of the
  /// picture's width and height measured from its top left, such as
  /// (x: 0.1, y: 0, width: 0.8, height: 1). Nil keeps the whole picture.
  private(set) var cropRect: CGRect?

  /// Whether a crop smaller than the whole picture is set.
  var isCropped: Bool {
    guard let cropRect else { return false }
    return cropRect != CGRect(x: 0, y: 0, width: 1, height: 1)
  }

  func setCrop(_ rect: CGRect) {
    cropRect = rect
  }

  /// Goes back to keeping the whole picture.
  func removeCrop() {
    cropRect = nil
  }

  /// Writes the part of the video between the start and end times to a new
  /// file. `progress` is called as the export runs, with values from 0 to 1.
  ///
  /// With `reencode` on, the video is re-encoded at the highest quality, which
  /// makes the cut exact to the frame. With it off, the video is copied as is:
  /// faster and lossless, but it can only cut at keyframes, so the start could
  /// move earlier, and it fails if the codecs aren't allowed in the file type.
  ///
  /// If a crop is set, the export is cropped to it too. Cropping changes the
  /// picture, so it always re-encodes, whatever `reencode` says.
  func export(
    to url: URL,
    as fileType: AVFileType,
    reencode: Bool,
    progress: @escaping (Double) -> Void
  ) async throws {
    let preset = reencode || isCropped ? AVAssetExportPresetHighestQuality : AVAssetExportPresetPassthrough
    guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
      throw CocoaError(.fileWriteUnknown)
    }
    session.timeRange = CMTimeRange(
      start: CMTime(seconds: startTime, preferredTimescale: 600),
      end: CMTime(seconds: endTime ?? duration, preferredTimescale: 600)
    )
    if let cropRect, isCropped {
      session.videoComposition = try await CropCompositionBuilder(asset: asset, crop: cropRect).build()
    }

    let progressUpdates = Task {
      for await state in session.states(updateInterval: 0.1) {
        if case .exporting(let exportProgress) = state {
          progress(exportProgress.fractionCompleted)
        }
      }
    }
    defer { progressUpdates.cancel() }

    // The save panel has already confirmed replacing an existing file, and
    // the export fails if one is in the way.
    try? FileManager.default.removeItem(at: url)
    try await session.export(to: url, as: fileType)
  }

  /// Puts the start and end times back to the beginning and end of the video.
  func resetStartAndEndTimes() {
    startTime = 0
    endTime = nil
    updatePlaybackEnd(forPosition: currentTime)
  }

  private func seekToStartTime() {
    updatePlaybackEnd(forPosition: startTime)
    queuePlayer.seek(
      to: CMTime(seconds: startTime, preferredTimescale: 600),
      toleranceBefore: .zero,
      toleranceAfter: .zero
    )
  }

  /// The end time only applies once playback is inside the range. From a
  /// position past it, such as after clicking later in the timeline, the
  /// video plays on to its real end instead. Call this whenever the position
  /// jumps, before seeking.
  private func updatePlaybackEnd(forPosition position: Double) {
    guard let item = queuePlayer.currentItem else { return }
    if let endTime, position <= endTime {
      // Playback treats this as the end of the video, so looping and stopping
      // at the end happen here.
      item.forwardPlaybackEndTime = CMTime(seconds: endTime, preferredTimescale: 600)
    } else {
      item.forwardPlaybackEndTime = .invalid
    }
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

  /// Moves forward or back: 5 seconds while playing, or one frame while
  /// paused. Holding Option while paused moves 5 seconds instead.
  func skipOrStep(forward: Bool) {
    if queuePlayer.rate != 0 || NSEvent.modifierFlags.contains(.option) {
      skip(bySeconds: forward ? 5 : -5)
    } else {
      queuePlayer.currentItem?.step(byCount: forward ? 1 : -1)
    }
  }

  /// Jumps to the start time set with setStartTime(), or the beginning of the
  /// video if none has been set.
  func goToStartTime() {
    guard duration > 0 else { return }
    seek(toFraction: startTime / duration)
  }

  /// Jumps to the end time set with setEndTime(), or the end of the video if
  /// none has been set.
  func goToEndTime() {
    guard duration > 0 else { return }
    seek(toFraction: (endTime ?? duration) / duration)
  }

  /// Jumps to a position in the video, where 0 is the start and 1 is the end.
  func seek(toFraction fraction: Double) {
    guard duration > 0 else { return }
    let clamped = min(max(fraction, 0), 1)
    currentTime = clamped * duration
    // Before seeking: while playing, landing past an end time that's still
    // set counts as reaching the end, and would loop back to the start.
    updatePlaybackEnd(forPosition: currentTime)
    queuePlayer.seek(
      to: CMTime(seconds: currentTime, preferredTimescale: 600),
      toleranceBefore: .zero,
      toleranceAfter: .zero
    )
  }
}
