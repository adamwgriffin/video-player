import AppKit
import UniformTypeIdentifiers

/// The save dialog for exporting a trimmed video.
///
/// It wraps an NSSavePanel rather than subclassing it, because sandboxed apps
/// can't subclass the system's open and save panels.
struct ExportSavePanel {
  /// The video's title, used for the suggested file name.
  let title: String
  /// Whether the re-encode checkbox starts ticked.
  let reencodes: Bool

  /// Shows the dialog and waits for the person to choose. Returns where to
  /// save and whether to re-encode, or nil if they cancel.
  func run() -> (url: URL, reencode: Bool)? {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.mpeg4Movie]
    panel.nameFieldStringValue = fileName()
    // Set every time, so the dialog always opens in Downloads instead of the
    // last folder used. In the sandbox, downloadsDirectory is a link inside
    // the app's container to the real Downloads folder, so follow it.
    panel.directoryURL = URL.downloadsDirectory.resolvingSymlinksInPath()

    let reencodeCheckbox = makeReencodeCheckbox()
    let accessory = NSStackView(views: [reencodeCheckbox])
    accessory.edgeInsets = NSEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
    panel.accessoryView = accessory

    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    return (url, reencodeCheckbox.state == .on)
  }

  /// A checkbox under the save dialog's file browser.
  private func makeReencodeCheckbox() -> NSButton {
    let checkbox = NSButton(checkboxWithTitle: "Re-encode for frame-accurate cuts", target: nil, action: nil)
    checkbox.state = reencodes ? .on : .off
    checkbox.toolTip = """
      Off copies the video without re-encoding: faster and lossless, but the start can only be cut at a keyframe. \
      Videos whose codecs MP4 doesn't allow will fail unless you enable this.
      """
    return checkbox
  }

  /// The suggested name: the video's title and the current Unix timestamp,
  /// such as "marbles-1794099727".
  private func fileName() -> String {
    "\(title)-\(Int(Date.now.timeIntervalSince1970))"
  }
}
