import SwiftUI

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
        // Greyed out until a start or end time is set, and while an export
        // is already running.
        CommandGroup(replacing: .importExport) {
          Button("Export Trimmed Video…") {
            VideoModel.shared.exportTrimmedVideo()
          }
          .disabled(
            VideoModel.shared.player?.isTrimmed != true
              || VideoModel.shared.exportProgress != nil
          )
        }
        // There's nothing to edit, so remove the editing items from the Edit
        // menu. That leaves only Copy.
        CommandGroup(replacing: .undoRedo) {}
        CommandGroup(replacing: .textEditing) {}
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
          Button(VideoModel.shared.player?.isPlaying == true ? "Pause" : "Play") {
            VideoModel.shared.player?.togglePlayback()
          }
          .keyboardShortcut(.space, modifiers: [])
          .disabled(VideoModel.shared.player == nil)

          // The arrow keys skip 5 seconds while playing and step one frame
          // while paused. Holding Command makes them skip while paused too. The
          // titles change to match, and so does the shortcut, since a menu
          // shortcut only fires when its modifier keys are exactly the ones
          // held down.
          let isCommandKeyDown = VideoModel.shared.isCommandKeyDown
          let arrowKeysSkip = VideoModel.shared.player?.isPlaying == true || isCommandKeyDown
          let arrowModifiers: EventModifiers = isCommandKeyDown ? .command : []

          Button(arrowKeysSkip ? "Skip Back" : "Step Back") {
            VideoModel.shared.player?.arrowKey(forward: false)
          }
          .keyboardShortcut(.leftArrow, modifiers: arrowModifiers)
          .disabled(VideoModel.shared.player == nil)

          Button(arrowKeysSkip ? "Skip Forward" : "Step Forward") {
            VideoModel.shared.player?.arrowKey(forward: true)
          }
          .keyboardShortcut(.rightArrow, modifiers: arrowModifiers)
          .disabled(VideoModel.shared.player == nil)

          Divider()

          // I and O are the usual keys for in and out points in video editing
          // apps, and Shift jumps to them.
          Button("Set Start Time") {
            VideoModel.shared.player?.setStartTime()
          }
          .keyboardShortcut("i", modifiers: [])
          .disabled(VideoModel.shared.player == nil)

          Button("Set End Time") {
            VideoModel.shared.player?.setEndTime()
          }
          .keyboardShortcut("o", modifiers: [])
          .disabled(VideoModel.shared.player == nil)

          Button("Go to Start Time") {
            VideoModel.shared.player?.goToStartTime()
          }
          .keyboardShortcut("i", modifiers: .shift)
          .disabled(VideoModel.shared.player == nil)

          Button("Go to End Time") {
            VideoModel.shared.player?.goToEndTime()
          }
          .keyboardShortcut("o", modifiers: .shift)
          .disabled(VideoModel.shared.player == nil)

          // Option-X matches Final Cut Pro's Clear Range. Greyed out when
          // the times are already at the beginning and end of the video.
          Button("Reset Start and End Times") {
            VideoModel.shared.player?.resetStartAndEndTimes()
          }
          .keyboardShortcut("x", modifiers: .option)
          .disabled(
            VideoModel.shared.player.map { $0.startTime == 0 && $0.endTime == nil } ?? true
          )

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
