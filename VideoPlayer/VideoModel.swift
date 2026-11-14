import AVFoundation
import AppKit
import Observation
import UniformTypeIdentifiers

/// Holds the one video the app is showing. Opening another video replaces it.
@Observable
final class VideoModel {
  private(set) var player: Player?

  /// The video's file name without its extension, for the window title.
  private(set) var title = ""

  /// Whether the window is full screen, when the controls are hidden.
  var isFullScreen = false

  /// Whether a keyboard modifier is held down, which makes the arrow keys skip instead of
  /// step while paused. Kept up to date by the app delegate.
  var skipWhilePaused = false

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

  /// How far an export has got, from 0 to 1. Nil when nothing is exporting.
  private(set) var exportProgress: Double?

  /// The save dialog's re-encode checkbox. Off by default, and remembered for
  /// the next export while the app is running.
  private var reencodesExports = false

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

  /// Asks where to save, then exports the video trimmed to its start and end
  /// times. The export is always an MPEG-4 file, whatever the original is.
  func exportTrimmedVideo() {
    guard let player, exportProgress == nil else { return }

    let savePanel = ExportSavePanel(title: title, reencodes: reencodesExports)
    guard let choice = savePanel.run() else { return }
    reencodesExports = choice.reencode

    exportProgress = 0
    Task {
      do {
        try await player.exportTrimmed(to: choice.url, as: .mp4, reencode: choice.reencode) { fraction in
          self.exportProgress = fraction
        }
      } catch {
        NSAlert(error: error).runModal()
      }
      exportProgress = nil
    }
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
