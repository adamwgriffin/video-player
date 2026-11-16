import SwiftUI

/// A thin bar that fills up to the current position, with green and red
/// lines at the start and end times. Clicking or dragging anywhere on it jumps
/// to that point in the video.
struct SeekBar: View {
  let player: Player

  /// Where the person is dragging, shown instead of the playback position
  /// until they let go.
  @State private var scrubFraction: Double?

  private let trackHeight: CGFloat = 4
  private let rangeMarkerSize = CGSize(width: 2, height: 14)

  var body: some View {
    GeometryReader { geometry in
      let fraction = scrubFraction ?? playbackFraction
      ZStack(alignment: .leading) {
        Rectangle()
          .fill(.secondary.opacity(0.3))
          .frame(height: trackHeight)

        Rectangle()
          .fill(.secondary)
          .frame(width: geometry.size.width * fraction, height: trackHeight)

        if player.duration > 0 {
          rangeMarker(.green, at: startFraction, in: geometry.size.width)
          rangeMarker(.red, at: endFraction, in: geometry.size.width)
        }
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

  private var startFraction: Double {
    min(player.startTime / player.duration, 1)
  }

  /// With no end time set, the end is the end of the video.
  private var endFraction: Double {
    guard let endTime = player.endTime else { return 1 }
    return min(endTime / player.duration, 1)
  }

  /// A thin colored line across the track, kept fully inside it at both ends.
  private func rangeMarker(_ color: Color, at fraction: Double, in width: CGFloat) -> some View {
    Rectangle()
      .fill(color)
      .frame(width: rangeMarkerSize.width, height: rangeMarkerSize.height)
      .offset(x: (width - rangeMarkerSize.width) * fraction)
  }
}
