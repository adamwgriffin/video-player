import SwiftUI

/// A thin bar with a small vertical marker at the current position.
/// Clicking or dragging anywhere on it jumps to that point in the video.
struct SeekBar: View {
  let player: Player

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
    .accessibilityValue(
      Text(playbackFraction, format: .percent.precision(.fractionLength(0)))
    )
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
