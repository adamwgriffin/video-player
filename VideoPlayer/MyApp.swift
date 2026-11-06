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
