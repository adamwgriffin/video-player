import CoreGraphics

/// How large a frame thumbnail is shown and how it's drawn, along with how
/// many pixels to make it with so it stays sharp at that size.
struct ThumbnailAttributes {
  /// The widest the thumbnail is shown, in points.
  var maxWidth: CGFloat = 120
  /// The space kept between the thumbnail and the edges of the area it's
  /// shown in, in points.
  var margin: CGFloat = 12
  var cornerRadius: CGFloat = 8
  /// How far the shadow blurs out past the thumbnail's edges, in points.
  var shadowRadius: CGFloat = 8
  /// Pixels per point to make the image with, such as 2 for Retina screens.
  var pixelScale: CGFloat = 2

  /// The largest image to make, in pixels: maxWidth scaled up by pixelScale,
  /// in both directions.
  var maximumPixelSize: CGSize {
    let side = maxWidth * pixelScale
    return CGSize(width: side, height: side)
  }
}
