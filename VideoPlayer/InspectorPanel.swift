import SwiftUI

/// The movie inspector's window: a floating HUD panel, translucent and dark,
/// that stays above the video window and shows MovieInspector.
final class InspectorPanel: NSPanel {
  init(videoModel: VideoModel) {
    super.init(
      contentRect: .zero,
      styleMask: [.titled, .closable, .utilityWindow, .hudWindow],
      backing: .buffered,
      defer: false
    )
    title = "Inspector"
    isFloatingPanel = true
    // A floating panel sits above every app's windows, so hide it whenever
    // another app is in front, and it only floats over this app's windows.
    hidesOnDeactivate = true
    isReleasedWhenClosed = false

    let hostingController = NSHostingController(rootView: MovieInspector(model: videoModel))
    contentViewController = hostingController
    // Size the panel to its contents now, so its width is known before it's
    // positioned. Until then it can still be zero.
    setContentSize(hostingController.view.fittingSize)
  }

  /// Places the panel beside the window, level with its top right corner, or
  /// in the middle of the screen if there's no window.
  func position(beside window: NSWindow?) {
    guard let window else {
      center()
      return
    }

    let gap: CGFloat = 8
    var x = window.frame.maxX + gap
    // If there isn't room beside the window, as in full screen or when the
    // window is wide, keep the panel on screen by overlapping the video.
    if let screen = window.screen {
      x = min(x, screen.visibleFrame.maxX - frame.width)
    }
    setFrameTopLeftPoint(NSPoint(x: x, y: window.frame.maxY))
  }
}
