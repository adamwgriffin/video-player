import SwiftUI

/// A thin bar that fills up to the current position, with green and red
/// lines at the start and end times. Clicking or dragging anywhere on it jumps
/// to that point in the video, and hovering over it loads the frame there
/// into `preview`.
struct SeekBar: View {
  let player: Player
  /// Whether hovering loads frames into `preview`. When off, it stays nil.
  let showsPreview: Bool
  /// The frame at the hovered position, or nil when the pointer isn't over
  /// the bar. The last frame is kept until the next one loads, so a preview
  /// of it doesn't flicker.
  @Binding var preview: SeekPreview?

  /// Where the person is dragging, shown instead of the playback position
  /// until they let go.
  @State private var scrubFraction: Double?
  /// Where the pointer is over the bar, or nil when it isn't.
  @State private var hoverFraction: Double?
  /// The pointer's horizontal position in global coordinates.
  @State private var hoverX: CGFloat = 0

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
      .onContinuousHover(coordinateSpace: .global) { phase in
        updateHover(phase, barFrame: geometry.frame(in: .global))
      }
    }
    .frame(height: 20)
    // Starting a new load cancels the one for the previous position.
    .task(id: hoverFraction) {
      await loadThumbnail()
    }
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

  /// `location` and `barFrame` are both in global coordinates.
  private func updateHover(_ phase: HoverPhase, barFrame: CGRect) {
    switch phase {
    case .active(let location) where showsPreview && player.duration > 0:
      let fraction = (location.x - barFrame.minX) / max(barFrame.width, 1)
      hoverFraction = min(max(fraction, 0), 1)
      hoverX = location.x
      // Follow the pointer right away, even before the new frame loads.
      preview?.pointerX = location.x
    default:
      hoverFraction = nil
      preview = nil
    }
  }

  private func loadThumbnail() async {
    guard let hoverFraction else { return }
    let seconds = hoverFraction * player.duration
    guard let image = await player.thumbnailer.image(atSeconds: seconds),
      !Task.isCancelled
    else { return }
    preview = SeekPreview(image: image, pointerX: hoverX)
  }

  /// A thin colored line across the track, kept fully inside it at both ends.
  private func rangeMarker(
    _ color: Color, at fraction: Double, in width: CGFloat
  ) -> some View {
    Rectangle()
      .fill(color)
      .frame(width: rangeMarkerSize.width, height: rangeMarkerSize.height)
      .offset(x: (width - rangeMarkerSize.width) * fraction)
  }
}
