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

  /// Whether Option is held down, which makes the arrow keys skip instead of
  /// step while paused. Kept up to date by the app delegate.
  var isOptionKeyDown = false

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

    let panel = NSSavePanel()
    panel.allowedContentTypes = [.mpeg4Movie]
    panel.nameFieldStringValue = exportFileName()
    // Set every time, so the dialog always opens in Downloads instead of the
    // last folder used.
    panel.directoryURL = userDownloadsFolder()

    // A checkbox under the save dialog's file browser.
    let reencodeCheckbox = NSButton(
      checkboxWithTitle:
        "Re-encode for frame-accurate cuts",
      target: nil,
      action: nil
    )
    reencodeCheckbox.state = reencodesExports ? .on : .off
    reencodeCheckbox.toolTip = """
      Off copies the video without re-encoding: faster and lossless, but the start can only be cut at a keyframe. \
      Videos whose codecs MP4 doesn't allow will fail unless you enable this.
      """
    let accessory = NSStackView(views: [reencodeCheckbox])
    accessory.edgeInsets = NSEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
    panel.accessoryView = accessory

    guard panel.runModal() == .OK, let url = panel.url else { return }
    reencodesExports = reencodeCheckbox.state == .on
    let reencode = reencodesExports

    exportProgress = 0
    Task {
      do {
        try await player.exportTrimmed(to: url, as: .mp4, reencode: reencode) { fraction in
          self.exportProgress = fraction
        }
      } catch {
        NSAlert(error: error).runModal()
      }
      exportProgress = nil
    }
  }

  /// The user's real Downloads folder. In the sandbox, URL.downloadsDirectory
  /// is a folder inside the app's own container instead, so this starts from
  /// the account's home folder.
  private func userDownloadsFolder() -> URL? {
    guard let home = getpwuid(getuid())?.pointee.pw_dir else { return nil }
    return URL(fileURLWithPath: String(cString: home)).appending(path: "Downloads")
  }

  /// The suggested name for an export: the video's title and the current Unix
  /// timestamp, such as "marbles-1794099727".
  private func exportFileName() -> String {
    "\(title)-\(Int(Date.now.timeIntervalSince1970))"
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
