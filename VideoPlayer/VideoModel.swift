import AVFoundation
import AppKit
import Observation
import UniformTypeIdentifiers

/// Holds the one video the app is showing. Opening another video replaces it.
@Observable
final class VideoModel {
  /// Shared so the app delegate, which receives Finder open requests, can
  /// reach the same model the window displays.
  static let shared = VideoModel()

  private(set) var player: Player?

  /// The video's file name without its extension, for the window title.
  private(set) var title = ""

  /// Whether the window is full screen, when the controls are hidden.
  var isFullScreen = false

  /// Whether the movie inspector panel is showing, for the menu item's title.
  var isInspectorShown = false

  /// Whether videos start over when they reach the end. On by default, and
  /// kept when another video is opened.
  var isLooping = true {
    didSet { player?.isLooping = isLooping }
  }

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
    player = Player(url: url, looping: isLooping)
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
