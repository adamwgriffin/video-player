import SwiftUI

/// A thin bar that fills up to the current position, with triangles
/// above it marking the start and end times. Clicking or dragging
/// anywhere on it jumps to that point in the video.
struct SeekBar: View {
  let player: Player

  /// Where the person is dragging, shown instead of the playback position
  /// until they let go.
  @State private var scrubFraction: Double?

  private let trackHeight: CGFloat = 4
  /// The start and end triangles: the same symbol as the buttons that set
  /// those times, at half the buttons' 10 points.
  private let markerSymbolSize: CGFloat = 6
  private let markerFrameSize: CGFloat = 7
  /// Space between the bottom of the triangles and the top of the track.
  private let markerGap: CGFloat = 2

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
          // The start triangle's right edge sits on the start position, and
          // the end triangle's left edge on the end position.
          rangeMarker(mirrored: false)
            .offset(x: geometry.size.width * startFraction - markerFrameSize, y: markerOffsetY)
          rangeMarker(mirrored: true)
            .offset(x: geometry.size.width * endFraction, y: markerOffsetY)
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
    // Tall enough for the triangles above the track. The track stays in the
    // middle, level with the time labels beside it.
    .frame(height: 28)
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

  /// Moves a triangle up from the middle of the row to just above the track.
  private var markerOffsetY: CGFloat {
    -(trackHeight / 2 + markerGap + markerFrameSize / 2)
  }

  /// The triangle used by the Set Start Time button, or mirrored for Set End
  /// Time. It's pushed to one side of its frame so the triangle's straight,
  /// vertical edge is flush with that side of the frame.
  private func rangeMarker(mirrored: Bool) -> some View {
    Image(systemName: "righttriangle.fill")
      .font(.system(size: markerSymbolSize))
      .foregroundStyle(.primary)
      .scaleEffect(x: mirrored ? -1 : 1)
      .frame(
        width: markerFrameSize,
        height: markerFrameSize,
        alignment: mirrored ? .leading : .trailing
      )
  }
}
