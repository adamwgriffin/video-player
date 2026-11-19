import SwiftUI

/// The window the video plays in, showing ContentView. It starts at the top
/// left of the screen, three quarters of the screen's width.
final class VideoWindow: NSWindow {
  private let videoModel: VideoModel

  init(videoModel: VideoModel) {
    self.videoModel = videoModel
    super.init(
      contentRect: .zero,
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    isReleasedWhenClosed = false
    collectionBehavior.insert(.fullScreenPrimary)
    // Windows only report mouse movement when asked to, which the full screen
    // pointer hiding relies on.
    acceptsMouseMovedEvents = true
    contentViewController = NSHostingController(
      rootView: ContentView().environment(videoModel))

    // visibleFrame excludes the menu bar and Dock.
    if let visibleFrame = NSScreen.main?.visibleFrame {
      setContentSize(Self.initialSize(in: visibleFrame))
      // Top left of the screen, just below the menu bar.
      setFrameTopLeftPoint(NSPoint(x: visibleFrame.minX, y: visibleFrame.maxY))
    } else {
      setContentSize(NSSize(width: 800, height: 450))
    }
  }

  /// Focus moving anywhere, including to another field, ends a text edit, so
  /// this applies whatever was typed into the crop size fields.
  @discardableResult
  override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
    let changed = super.makeFirstResponder(responder)
    videoModel.applyPendingCropSize()
    return changed
  }

  /// AppKit offers every key press here before the menu bar's shortcuts. While
  /// a text field is being edited, keys without Command go straight to it, so
  /// shortcuts on plain keys, such as space or the arrow keys, don't take the
  /// keys it needs for typing. This checks what has focus at the moment of
  /// each key press.
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if let textEditor = firstResponder as? NSText,
      !event.modifierFlags.contains(.command)
    {
      textEditor.keyDown(with: event)
      return true
    }
    return super.performKeyEquivalent(with: event)
  }

  /// Clicking anywhere other than a text field ends text editing. Normally a
  /// text field keeps focus until another control takes it, and most of this
  /// window, such as the video, never does.
  override func sendEvent(_ event: NSEvent) {
    if event.type == .leftMouseDown, firstResponder is NSText {
      let clickedView = contentView?.hitTest(event.locationInWindow)
      if !(clickedView is NSTextField || clickedView is NSText) {
        // Ending editing applies what was typed, as leaving the field does.
        makeFirstResponder(nil)
      }
    }
    super.sendEvent(event)
  }

  /// Three quarters of the screen's width, at a 16:9 shape, but never taller
  /// than the screen.
  private static func initialSize(in visibleFrame: NSRect) -> NSSize {
    let width = visibleFrame.width * 3 / 4
    let height = min(width * 9 / 16, visibleFrame.height)
    return NSSize(width: width, height: height)
  }
}
