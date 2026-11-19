import SwiftUI

/// Play/pause button, elapsed and total time, and the seek bar.
struct PlaybackControls: View {
  let player: Player

  var body: some View {
    HStack(spacing: 12) {
      HStack(spacing: 6) {
        Button {
          player.setStartTime()
        } label: {
          Image(systemName: "timer")
            .scaleEffect(x: -1)
        }
        .buttonStyle(.plain)
        .help("Set Start")
        .accessibilityLabel("Set Start")

        Button {
          player.goToStartTime()
        } label: {
          Image(systemName: "backward.end.fill")
        }
        .buttonStyle(.plain)
        .help("Go to Start")
        .accessibilityLabel("Go to Start")

        Button {
          player.togglePlayback()
        } label: {
          Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

        Button {
          player.goToEndTime()
        } label: {
          Image(systemName: "forward.end.fill")
        }
        .buttonStyle(.plain)
        .help("Go to End")
        .accessibilityLabel("Go to End")

        Button {
          player.setEndTime()
        } label: {
          Image(systemName: "timer")
        }
        .buttonStyle(.plain)
        .help("Set End")
        .accessibilityLabel("Set End")
      }

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
