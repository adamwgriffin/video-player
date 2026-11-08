import AVKit

/// An AVPlayerView that ignores the keyboard. Even with its controls turned
/// off, AVPlayerView handles keys like the space bar itself, and would play
/// from the very beginning instead of the start time. Ignoring them lets the
/// Playback menu's shortcuts handle every key.
final class PassivePlayerView: AVPlayerView {
  override var acceptsFirstResponder: Bool { false }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    false
  }
}
