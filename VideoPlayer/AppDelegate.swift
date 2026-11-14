import SwiftUI

/// Receives videos opened from Finder and routes them to the one shared model,
/// so a new video replaces the current one instead of opening another window.
/// It also owns the player window, which only exists while a video is open, so
/// nothing is on screen when the app starts.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private var window: VideoWindow?
  private var inspectorPanel: InspectorPanel?
  private var mouseMovedMonitor: Any?
  private var modifierKeysMonitor: Any?
  private var cursorHideTask: Task<Void, Never>?

  private var videoModel: VideoModel { .shared }
  private var player: Player? { videoModel.player }

  override init() {
    super.init()
    videoModel.didOpen = { [weak self] in self?.showWindow() }

    // The system adds these to every Edit menu on its own. They're no use
    // here, so ask it to leave them out.
    UserDefaults.standard.set(true, forKey: "NSDisabledDictationMenuItem")
    UserDefaults.standard.set(
      true,
      forKey: "NSDisabledCharacterPaletteMenuItem"
    )
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Track Option so the Playback menu can switch the arrow keys between
    // stepping and skipping as it's pressed and released.
    modifierKeysMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      self?.videoModel.skipWhilePaused = event.modifierFlags.contains(.option)
      return event
    }

    // Like QuickTime Player, ask for a video at startup. A video opened from
    // Finder is already playing by now, so only ask if there isn't one.
    Task { @MainActor in
      if player == nil {
        videoModel.showOpenPanel()
      }
    }
  }

  /// Option could have been pressed or released while another app was in
  /// front, when this app doesn't see key changes, so check it again.
  func applicationDidBecomeActive(_ notification: Notification) {
    videoModel.skipWhilePaused = NSEvent.modifierFlags.contains(.option)
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    // Only one video plays at a time, so use the last one if several arrive.
    if let url = urls.last {
      videoModel.open(url)
    }
  }

  private func showWindow() {
    if window == nil {
      let window = VideoWindow(videoModel: videoModel)
      // So this hears about full screen changes and the window closing.
      window.delegate = self
      self.window = window
    }
    // Set every time, because opening another video reuses the window.
    window?.title = videoModel.title
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate()
  }

  func windowWillEnterFullScreen(_ notification: Notification) {
    videoModel.isFullScreen = true
    startHidingCursorWhenIdle()
  }

  func windowWillExitFullScreen(_ notification: Notification) {
    videoModel.isFullScreen = false
    stopHidingCursorWhenIdle()
  }

  /// Hides the pointer after the mouse has been still for a couple of seconds.
  /// The system shows it again as soon as the mouse moves.
  private func startHidingCursorWhenIdle() {
    mouseMovedMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) {
      [weak self] event in
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
      let panel = InspectorPanel(videoModel: videoModel)
      // So windowWillClose(_:) hears when the panel closes.
      panel.delegate = self
      panel.position(beside: window)
      inspectorPanel = panel
    }

    inspectorPanel?.orderFront(nil)
    videoModel.isInspectorShown = true
  }

  func windowWillClose(_ notification: Notification) {
    // Compare against each window directly. Comparing optionals would treat a
    // never-opened inspector (nil) as a match for any window that isn't a panel.
    guard let closingWindow = notification.object as? NSWindow else { return }

    if closingWindow === inspectorPanel {
      videoModel.isInspectorShown = false
      return
    }
    guard closingWindow === window else { return }

    // The video window is closing, so there's nothing left to inspect.
    inspectorPanel?.close()
    videoModel.close()
    window = nil

    // The app is just this one window, so closing it quits.
    NSApp.terminate(nil)
  }
}
