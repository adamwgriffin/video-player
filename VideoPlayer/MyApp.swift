import SwiftUI

@main struct MyApp: App {
  @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

  private var videoModel: VideoModel { .shared }
  private var player: Player? { videoModel.player }

  /// Whether the arrow keys skip 5 seconds rather than step one frame: while
  /// playing, or while paused with Option held down.
  private var arrowKeysSkip: Bool {
    player?.isPlaying == true || videoModel.skipWhilePaused
  }

  /// The modifier keys for the arrow keys' shortcuts. A menu shortcut only
  /// fires when its modifier keys are exactly the ones held down, so this
  /// includes Option while it's held.
  private var arrowKeyModifiers: EventModifiers {
    videoModel.skipWhilePaused ? .option : []
  }

  var body: some Scene {
    // SwiftUI needs at least one scene, and unlike a Window or WindowGroup this
    // one doesn't open at launch. The player window is managed by AppDelegate.
    Settings { EmptyView() }
      .commands {
        CommandGroup(replacing: .appSettings) {}
        CommandGroup(replacing: .newItem) {
          Button("Open…") { videoModel.showOpenPanel() }
            .keyboardShortcut("o")
        }
        // Greyed out until a start or end time is set, and while an export
        // is already running.
        CommandGroup(replacing: .importExport) {
          Button("Export Trimmed Video…") {
            videoModel.exportTrimmedVideo()
          }
          .disabled(
            player?.isTrimmed != true
              || videoModel.exportProgress != nil
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
            Task { await player?.copyCurrentFrame() }
          }
          .keyboardShortcut("c")
          .disabled(player == nil)
        }
        // As in QuickTime Player, Cmd-I shows details about the video.
        CommandGroup(after: .windowArrangement) {
          Button(
            videoModel.isInspectorShown
              ? "Hide Movie Inspector" : "Show Movie Inspector"
          ) {
            appDelegate.toggleInspector()
          }
          .keyboardShortcut("i")
          .disabled(player == nil)
        }
        // A menu shortcut works whichever view has focus, so the space bar
        // always toggles playback, as it does in the built-in controls.
        CommandMenu("Playback") {
          Button(player?.isPlaying == true ? "Pause" : "Play") {
            player?.togglePlayback()
          }
          .keyboardShortcut(.space, modifiers: [])
          .disabled(player == nil)

          // The titles and shortcuts change with whether the arrow keys skip
          // or step.
          Button(arrowKeysSkip ? "Skip Back" : "Step Back") {
            player?.arrowKey(forward: false)
          }
          .keyboardShortcut(.leftArrow, modifiers: arrowKeyModifiers)
          .disabled(player == nil)

          Button(arrowKeysSkip ? "Skip Forward" : "Step Forward") {
            player?.arrowKey(forward: true)
          }
          .keyboardShortcut(.rightArrow, modifiers: arrowKeyModifiers)
          .disabled(player == nil)

          Divider()

          // I and O are the usual keys for in and out points in video editing
          // apps, and Shift jumps to them.
          Button("Set Start Time") {
            player?.setStartTime()
          }
          .keyboardShortcut("i", modifiers: [])
          .disabled(player == nil)

          Button("Set End Time") {
            player?.setEndTime()
          }
          .keyboardShortcut("o", modifiers: [])
          .disabled(player == nil)

          Button("Go to Start Time") {
            player?.goToStartTime()
          }
          .keyboardShortcut("i", modifiers: .shift)
          .disabled(player == nil)

          Button("Go to End Time") {
            player?.goToEndTime()
          }
          .keyboardShortcut("o", modifiers: .shift)
          .disabled(player == nil)

          // Option-X matches Final Cut Pro's Clear Range. Greyed out when
          // the times are already at the beginning and end of the video.
          Button("Reset Start and End Times") {
            player?.resetStartAndEndTimes()
          }
          .keyboardShortcut("x", modifiers: .option)
          .disabled(
            player.map { $0.startTime == 0 && $0.endTime == nil } ?? true
          )

          Divider()

          // Shows a checkmark when on. Cmd-L matches QuickTime Player.
          Toggle(
            "Loop",
            isOn: Binding(
              get: { videoModel.isLooping },
              set: { videoModel.isLooping = $0 }
            )
          )
          .keyboardShortcut("l")
        }
      }
  }
}
