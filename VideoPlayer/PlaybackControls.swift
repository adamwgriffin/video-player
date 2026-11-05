import SwiftUI
import AVKit

/// Play/pause button, elapsed and total time, and the seek bar.
struct PlaybackControls: View {
  let player: LoopingPlayer

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

/// The system's AirPlay button. Clicking it lists nearby AirPlay devices, such
/// as an Apple TV or speaker, to send the video to.
struct AirPlayButton: NSViewRepresentable {
  let player: AVPlayer

  func makeNSView(context: Context) -> AVRoutePickerView {
    let view = AVRoutePickerView()
    view.isRoutePickerButtonBordered = false
    view.player = player
    return view
  }

  func updateNSView(_ view: AVRoutePickerView, context: Context) {
    if view.player !== player {
      view.player = player
    }
  }
}

/// A thin bar with a small vertical marker at the current position.
/// Clicking or dragging anywhere on it jumps to that point in the video.
struct SeekBar: View {
  let player: LoopingPlayer

  /// Where the person is dragging, shown instead of the playback position
  /// until they let go.
  @State private var scrubFraction: Double?

  private let trackHeight: CGFloat = 4
  private let markerSize = CGSize(width: 3, height: 14)

  var body: some View {
    GeometryReader { geometry in
      let fraction = scrubFraction ?? playbackFraction
      ZStack(alignment: .leading) {
        Capsule()
          .fill(.secondary.opacity(0.3))
          .frame(height: trackHeight)

        Capsule()
          .fill(.secondary)
          .frame(width: geometry.size.width * fraction, height: trackHeight)

        RoundedRectangle(cornerRadius: 1)
          .fill(.primary)
          .frame(width: markerSize.width, height: markerSize.height)
          // Keep the marker fully inside the bar at both ends.
          .offset(x: (geometry.size.width - markerSize.width) * fraction)
      }
      .frame(maxHeight: .infinity)
      // The whole row is clickable, not just the thin track.
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let fraction = value.location.x / max(geometry.size.width, 1)
            scrubFraction = min(max(fraction, 0), 1)
            player.seek(toFraction: fraction)
          }
          .onEnded { _ in
            scrubFraction = nil
          }
      )
    }
    .frame(height: 20)
    .accessibilityElement()
    .accessibilityLabel("Playback position")
    .accessibilityValue(Text(playbackFraction, format: .percent.precision(.fractionLength(0))))
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: player.seek(toFraction: playbackFraction + 0.05)
      case .decrement: player.seek(toFraction: playbackFraction - 0.05)
      @unknown default: break
      }
    }
  }

  private var playbackFraction: Double {
    player.duration > 0 ? min(player.currentTime / player.duration, 1) : 0
  }
}
