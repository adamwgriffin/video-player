import SwiftUI

/// The window the video plays in, showing ContentView. It starts at the top
/// left of the screen, three quarters of the screen's width.
final class VideoWindow: NSWindow {
  init(videoModel: VideoModel) {
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
    contentViewController = NSHostingController(rootView: ContentView(model: videoModel))

    // visibleFrame excludes the menu bar and Dock.
    if let visibleFrame = NSScreen.main?.visibleFrame {
      setContentSize(Self.initialSize(in: visibleFrame))
      // Top left of the screen, just below the menu bar.
      setFrameTopLeftPoint(NSPoint(x: visibleFrame.minX, y: visibleFrame.maxY))
    } else {
      setContentSize(NSSize(width: 800, height: 450))
    }
  }

  /// Three quarters of the screen's width, at a 16:9 shape, but never taller
  /// than the screen.
  private static func initialSize(in visibleFrame: NSRect) -> NSSize {
    let width = visibleFrame.width * 3 / 4
    let height = min(width * 9 / 16, visibleFrame.height)
    return NSSize(width: width, height: height)
  }
}
