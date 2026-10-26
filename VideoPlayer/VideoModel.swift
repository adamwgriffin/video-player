import SwiftUI
import AVKit
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
final class LoopingPlayer {
  let queuePlayer = AVQueuePlayer()
  private let looper: AVPlayerLooper

  init(url: URL) {
    let item = AVPlayerItem(url: url)
    looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
  }
}
