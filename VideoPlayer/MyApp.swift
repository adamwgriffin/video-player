import SwiftUI

/// Receives videos opened from Finder and routes them to the one shared model,
/// so a new video replaces the current one instead of opening another window.
/// It also owns the player window, which only exists while a video is open, so
/// nothing is on screen when the app starts.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private var window: NSWindow?
  private var inspectorPanel: NSPanel?
  private var mouseMovedMonitor: Any?
  private var cursorHideTask: Task<Void, Never>?

  override init() {
    super.init()
    VideoModel.shared.didOpen = { [weak self] in self?.showWindow() }

    // The system adds these to every Edit menu on its own. They're no use
    // here, so ask it to leave them out.
    UserDefaults.standard.set(true, forKey: "NSDisabledDictationMenuItem")
    UserDefaults.standard.set(
      true,
      forKey: "NSDisabledCharacterPaletteMenuItem"
    )
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
      window.collectionBehavior.insert(.fullScreenPrimary)
      // Windows only report mouse movement when asked to, which the full
      // screen pointer hiding relies on.
      window.acceptsMouseMovedEvents = true
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

  /// Three quarters of the screen's width, at a 16:9 shape, but never taller
  /// than the screen.
  private func initialWindowSize(in visibleFrame: NSRect) -> NSSize {
    let width = visibleFrame.width * 3 / 4
    let height = min(width * 9 / 16, visibleFrame.height)
    return NSSize(width: width, height: height)
  }

  func windowWillEnterFullScreen(_ notification: Notification) {
    VideoModel.shared.isFullScreen = true
    startHidingCursorWhenIdle()
  }

  func windowWillExitFullScreen(_ notification: Notification) {
    VideoModel.shared.isFullScreen = false
    stopHidingCursorWhenIdle()
  }

  /// Hides the pointer after the mouse has been still for a couple of seconds.
  /// The system shows it again as soon as the mouse moves.
  private func startHidingCursorWhenIdle() {
    mouseMovedMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved)
    { [weak self] event in
      MainActor.assumeIsolated { self?.scheduleCursorHide() }
      return event
    }
  }

  /// Hide the pointer as soon as the full screen transition has finished,
  /// without waiting for the mouse to be still first.
  func windowDidEnterFullScreen(_ notification: Notification) {
    NSCursor.setHiddenUntilMouseMoves(true)
  }

  private func stopHidingCursorWhenIdle() {
    if let mouseMovedMonitor {
      NSEvent.removeMonitor(mouseMovedMonitor)
    }
    mouseMovedMonitor = nil
    cursorHideTask?.cancel()
    cursorHideTask = nil
  }

  /// Restarts the countdown to hiding the pointer.
  private func scheduleCursorHide() {
    cursorHideTask?.cancel()
    cursorHideTask = Task {
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      NSCursor.setHiddenUntilMouseMoves(true)
    }
  }

  /// Shows the movie inspector, or hides it if it's already showing.
  func toggleInspector() {
    if let inspectorPanel, inspectorPanel.isVisible {
      inspectorPanel.close()
      return
    }

    if inspectorPanel == nil {
      // A floating HUD panel: translucent and dark, and it stays above the
      // video window.
      let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.titled, .closable, .utilityWindow, .hudWindow],
        backing: .buffered,
        defer: false
      )
      panel.title = "Inspector"
      panel.isFloatingPanel = true
      // A floating panel sits above every app's windows, so hide it whenever
      // another app is in front, and it only floats over this app's windows.
      panel.hidesOnDeactivate = true
      panel.isReleasedWhenClosed = false
      panel.contentViewController = NSHostingController(
        rootView: MovieInspector(model: VideoModel.shared)
      )
      panel.delegate = self

      // Beside the video window, level with its top right corner.
      if let window {
        let gap: CGFloat = 8
        var x = window.frame.maxX + gap
        // If there isn't room beside the window, slide back over it rather
        // than hang off the edge of the screen.
        if let screen = window.screen {
          x = min(x, screen.visibleFrame.maxX - panel.frame.width)
        }
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: window.frame.maxY))
      } else {
        panel.center()
      }
      inspectorPanel = panel
    }

    inspectorPanel?.orderFront(nil)
    VideoModel.shared.isInspectorShown = true
  }

  func windowWillClose(_ notification: Notification) {
    // Compare against each window directly. Comparing optionals would treat a
    // never-opened inspector (nil) as a match for any window that isn't a panel.
    guard let closingWindow = notification.object as? NSWindow else { return }

    if closingWindow === inspectorPanel {
      VideoModel.shared.isInspectorShown = false
      return
    }
    guard closingWindow === window else { return }

    // The video window is closing, so there's nothing left to inspect.
    inspectorPanel?.close()
    VideoModel.shared.close()
    window = nil

    // The app is just this one window, so closing it quits.
    NSApp.terminate(nil)
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
        // There's nothing to edit, so remove the editing items from the Edit
        // menu. That leaves only Copy.
        CommandGroup(replacing: .undoRedo) {}
        CommandGroup(replacing: .textEditing) {}
        CommandGroup(replacing: .textFormatting) {}
        // As in QuickTime Player, Edit > Copy puts the current frame on the
        // clipboard as an image. There's no text or other content to copy.
        CommandGroup(replacing: .pasteboard) {
          Button("Copy") {
            Task { await VideoModel.shared.player?.copyCurrentFrame() }
          }
          .keyboardShortcut("c")
          .disabled(VideoModel.shared.player == nil)
        }
        // As in QuickTime Player, Cmd-I shows details about the video.
        CommandGroup(after: .windowArrangement) {
          Button(
            VideoModel.shared.isInspectorShown
              ? "Hide Movie Inspector" : "Show Movie Inspector"
          ) {
            appDelegate.toggleInspector()
          }
          .keyboardShortcut("i")
          .disabled(VideoModel.shared.player == nil)
        }
        // A menu shortcut works whichever view has focus, so the space bar
        // always toggles playback, as it does in the built-in controls.
        CommandMenu("Playback") {
          Button(VideoModel.shared.player?.isPlaying == true ? "Pause" : "Play")
          {
            VideoModel.shared.player?.togglePlayback()
          }
          .keyboardShortcut(.space, modifiers: [])
          .disabled(VideoModel.shared.player == nil)

          // The arrow keys skip 5 seconds while playing and step one frame
          // while paused, and the titles change to match.
          let isPlaying = VideoModel.shared.player?.isPlaying == true

          Button(isPlaying ? "Skip Back" : "Step Back") {
            VideoModel.shared.player?.arrowKey(forward: false)
          }
          .keyboardShortcut(.leftArrow, modifiers: [])
          .disabled(VideoModel.shared.player == nil)

          Button(isPlaying ? "Skip Forward" : "Step Forward") {
            VideoModel.shared.player?.arrowKey(forward: true)
          }
          .keyboardShortcut(.rightArrow, modifiers: [])
          .disabled(VideoModel.shared.player == nil)

          Divider()

          // Shows a checkmark when on. Cmd-L matches QuickTime Player.
          Toggle(
            "Loop",
            isOn: Binding(
              get: { VideoModel.shared.isLooping },
              set: { VideoModel.shared.isLooping = $0 }
            )
          )
          .keyboardShortcut("l")
        }
      }
  }
}
