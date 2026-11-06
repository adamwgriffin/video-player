import SwiftUI

/// Play/pause button, elapsed and total time, and the seek bar.
struct PlaybackControls: View {
  let player: Player

  var body: some View {
    HStack(spacing: 12) {
      Button {
        player.togglePlayback()
      } label: {
        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
          .frame(width: 16)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

      Text(formatted(player.currentTime))
        .monospacedDigit()

      SeekBar(player: player)

      Text(formatted(player.duration))
        .monospacedDigit()

      AirPlayButton(player: player.queuePlayer)
        .frame(width: 24, height: 20)

      Button {
        NSApp.keyWindow?.toggleFullScreen(nil)
      } label: {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
          .frame(width: 16)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Enter Full Screen")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.bar)
  }

  private func formatted(_ seconds: Double) -> String {
    Duration.seconds(Int(seconds)).formatted(.time(pattern: .minuteSecond))
  }
}
