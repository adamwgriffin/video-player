import SwiftUI

/// Shows a seek preview's frame along the bottom of the space it fills,
/// centered under the pointer where there's room, and shrunk if needed to
/// fit inside.
struct SeekPreviewOverlay: View {
  let preview: SeekPreview
  /// The preview's largest width, margin, corner radius, and shadow.
  let attributes: ThumbnailAttributes

  /// The space the overlay fills, in global coordinates.
  @State private var container: CGRect = .zero

  private var maxWidth: CGFloat { attributes.maxWidth }
  private var margin: CGFloat { attributes.margin }

  var body: some View {
    Color.clear
      .overlay(alignment: .topLeading) {
        Image(decorative: preview.image, scale: 1)
          .resizable()
          .frame(width: fittedSize.width, height: fittedSize.height)
          .clipShape(.rect(cornerRadius: attributes.cornerRadius))
          .shadow(radius: attributes.shadowRadius)
          .offset(x: left, y: top)
      }
      .onGeometryChange(for: CGRect.self) { geometry in
        geometry.frame(in: .global)
      } action: { frame in
        container = frame
      }
      .allowsHitTesting(false)
  }

  /// The frame's width divided by its height.
  private var aspectRatio: CGFloat {
    CGFloat(preview.image.width) / CGFloat(max(preview.image.height, 1))
  }

  /// The largest size up to maxWidth wide that keeps the frame's shape and
  /// leaves a margin on every side.
  private var fittedSize: CGSize {
    let width = max(
      min(
        maxWidth,
        container.width - margin * 2,
        (container.height - margin * 2) * aspectRatio
      ), 0)
    return CGSize(width: width, height: width / max(aspectRatio, 0.01))
  }

  /// Centered under the pointer, but kept a margin inside both sides.
  private var left: CGFloat {
    let center = preview.pointerX - container.minX
    return min(
      max(center - fittedSize.width / 2, margin),
      container.width - fittedSize.width - margin)
  }

  /// A margin up from the bottom.
  private var top: CGFloat {
    container.height - fittedSize.height - margin
  }
}
