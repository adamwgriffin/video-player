import AVKit

/// An AVPlayerView that ignores the keyboard. Even with its controls turned
/// off, AVPlayerView handles keys like the space bar itself. Ignoring them
/// leaves every key to the rest of the app, such as its menu shortcuts.
final class PassivePlayerView: AVPlayerView {
  override var acceptsFirstResponder: Bool { false }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    false
  }
}
