import AVKit
import SwiftUI
import UniformTypeIdentifiers

/// Holds the one video the app is showing. Opening another video replaces it.
@Observable
final class VideoModel {
  /// Shared so the app delegate, which receives Finder open requests, can
  /// reach the same model the window displays.
  static let shared = VideoModel()

  private(set) var player: LoopingPlayer?

  /// The video's file name without its extension, for the window title.
  private(set) var title = ""

  /// Whether the window is full screen, when the controls are hidden.
  var isFullScreen = false

  /// Whether the movie inspector panel is showing, for the menu item's title.
  var isInspectorShown = false

  // The sandbox only grants access to a chosen file while this is held open.
  private var accessedURL: URL?
  private var currentURL: URL?

  /// Called after a video starts playing, so the app can show its window.
  var didOpen: (() -> Void)?

  /// Shows the standard macOS open dialog and plays the chosen video.
  func showOpenPanel() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.movie]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false

    if panel.runModal() == .OK, let url = panel.url {
      open(url)
    }
  }

  func open(_ url: URL) {
    // The same open request can arrive through more than one path.
    guard url != currentURL else { return }
    currentURL = url
    title = url.deletingPathExtension().lastPathComponent

    player?.queuePlayer.pause()
    accessedURL?.stopAccessingSecurityScopedResource()

    accessedURL = url.startAccessingSecurityScopedResource() ? url : nil
    player = LoopingPlayer(url: url)
    player?.queuePlayer.play()
    didOpen?()
  }

  /// Stops playback and releases the video, such as when its window closes.
  func close() {
    player?.queuePlayer.pause()
    player = nil
    accessedURL?.stopAccessingSecurityScopedResource()
    accessedURL = nil
    currentURL = nil
  }
}

/// Owns the queue player and the looper. AVPlayerLooper must be retained
/// for as long as looping should continue.
/// It also publishes the playback state that the custom controls display.
@Observable
final class LoopingPlayer {
  let queuePlayer = AVQueuePlayer()
  private let looper: AVPlayerLooper
  private let asset: AVAsset

  /// Seconds into the current pass through the video.
  private(set) var currentTime: Double = 0
  /// Length of the video in seconds, or 0 until it has loaded.
  private(set) var duration: Double = 0
  private(set) var isPlaying = false

  /// Details for the movie inspector. Nil until they've loaded.
  private(set) var info: VideoInfo?

  @ObservationIgnored private var timeObserver: Any?

  init(url: URL) {
    let item = AVPlayerItem(url: url)
    asset = item.asset
    looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

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
  }

  func togglePlayback() {
    if queuePlayer.rate == 0 {
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
