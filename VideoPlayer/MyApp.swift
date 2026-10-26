import SwiftUI

/// Receives videos opened from Finder and routes them to the one shared model,
/// so a new video replaces the current one instead of opening another window.
/// It also owns the player window, which only exists while a video is open, so
/// nothing is on screen when the app starts.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private var window: NSWindow?

  override init() {
    super.init()
    VideoModel.shared.didOpen = { [weak self] in self?.showWindow() }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Like QuickTime Player, ask for a video at startup. A video opened from
    // Finder is already playing by now, so only ask if there isn't one.
    Task { @MainActor in
      if VideoModel.shared.player == nil {
        VideoModel.shared.showOpenPanel()
      }
    }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    // Only one video plays at a time, so use the last one if several arrive.
    if let url = urls.last {
      VideoModel.shared.open(url)
    }
  }

  private func showWindow() {
    if window == nil {
      let window = NSWindow(
        contentViewController: NSHostingController(
          rootView: ContentView(model: VideoModel.shared)
        )
      )
      window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
      window.isReleasedWhenClosed = false
      window.delegate = self
      // visibleFrame excludes the menu bar and Dock.
      if let screen = NSScreen.main {
        let visibleFrame = screen.visibleFrame
        window.setContentSize(initialWindowSize(in: visibleFrame))
        // Top left of the screen, just below the menu bar.
        window
          .setFrameTopLeftPoint(
            NSPoint(x: visibleFrame.minX, y: visibleFrame.maxY)
          )
      } else {
        window.setContentSize(NSSize(width: 800, height: 450))
      }
      self.window = window
    }
    // Set every time, because opening another video reuses the window.
    window?.title = VideoModel.shared.title
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate()
  }

  /// Two thirds of the screen's width, at a 16:9 shape, but never taller than
  /// the screen.
  private func initialWindowSize(in visibleFrame: NSRect) -> NSSize {
    let width = visibleFrame.width * 2 / 3
    let height = min(width * 9 / 16, visibleFrame.height)
    return NSSize(width: width, height: height)
  }

  func windowWillClose(_ notification: Notification) {
    VideoModel.shared.close()
    window = nil
  }
}

@main struct MyApp: App {
  @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

  var body: some Scene {
    // SwiftUI needs at least one scene, and unlike a Window or WindowGroup this
    // one doesn't open at launch. The player window is managed by AppDelegate.
    Settings { EmptyView() }
      .commands {
        CommandGroup(replacing: .appSettings) {}
        CommandGroup(replacing: .newItem) {
          Button("Open…") { VideoModel.shared.showOpenPanel() }
            .keyboardShortcut("o")
        }
      }
  }
}
