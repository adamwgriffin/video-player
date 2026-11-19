import CoreGraphics

/// A shape the crop rectangle can be constrained to
enum CropAspectRatio: CaseIterable, Identifiable {
  case custom, square, fourByThree, sixteenByNine

  var id: Self { self }

  var title: String {
    switch self {
    case .custom: "Custom"
    case .square: "Square"
    case .fourByThree: "4:3"
    case .sixteenByNine: "16:9"
    }
  }

  /// Width divided by height, in pixels. Nil for Custom, which allows any
  /// shape.
  var ratio: CGFloat? {
    switch self {
    case .custom: nil
    case .square: 1
    case .fourByThree: 4 / 3
    case .sixteenByNine: 16 / 9
    }
  }

  /// The largest rectangle of this shape that fits inside the given one,
  /// centered on it. Rectangles are in fractions of the picture, as the crop
  /// is stored, so the video's size is needed to work out the shape.
  func fit(_ rect: CGRect, videoSize: CGSize) -> CGRect {
    guard let ratio, videoSize.width > 0, videoSize.height > 0, rect.height > 0
    else { return rect }
    let fractionRatio = Self.fractionRatio(ratio, videoSize: videoSize)
    let size = Self.largestSize(withRatio: fractionRatio, inside: rect.size)
    return Self.rect(of: size, centeredOn: CGPoint(x: rect.midX, y: rect.midY))
  }

  /// The rectangle with a new width or height in pixels. With a ratio, the
  /// other side follows to keep this shape. The result keeps the same center,
  /// moving only as far as needed to stay inside the picture, and is never
  /// larger than the picture or smaller than 2 pixels a side. Rectangles are
  /// in fractions of the picture.
  func resized(
    _ rect: CGRect, width: CGFloat? = nil, height: CGFloat? = nil,
    videoSize: CGSize
  ) -> CGRect {
    guard videoSize.width > 0, videoSize.height > 0 else { return rect }
    let requested = CGSize(
      width: width ?? rect.width * videoSize.width,
      height: height ?? rect.height * videoSize.height
    )
    let shaped = shapedSize(
      requested, widthChanged: width != nil, heightChanged: height != nil)
    let pixelSize = limitedSize(shaped, to: videoSize)
    let size = CGSize(
      width: pixelSize.width / videoSize.width,
      height: pixelSize.height / videoSize.height)
    let centered = Self.rect(
      of: size, centeredOn: CGPoint(x: rect.midX, y: rect.midY))
    return Self.movedInsidePicture(centered)
  }

  /// The ratio as fractions of the picture rather than pixels. A fraction of
  /// the width and a fraction of the height are different lengths unless the
  /// picture is square.
  private static func fractionRatio(_ ratio: CGFloat, videoSize: CGSize)
    -> CGFloat
  {
    ratio * videoSize.height / videoSize.width
  }

  /// The largest size with the given width-to-height ratio that fits inside
  /// the given size.
  private static func largestSize(withRatio ratio: CGFloat, inside size: CGSize)
    -> CGSize
  {
    if size.width / size.height > ratio {
      return CGSize(width: size.height * ratio, height: size.height)
    }
    return CGSize(width: size.width, height: size.width / ratio)
  }

  /// A size in pixels with the side that wasn't changed recalculated to keep
  /// this shape. Custom leaves both sides as they are.
  private func shapedSize(
    _ size: CGSize, widthChanged: Bool, heightChanged: Bool
  ) -> CGSize {
    guard let ratio else { return size }
    if widthChanged {
      return CGSize(width: size.width, height: size.width / ratio)
    }
    if heightChanged {
      return CGSize(width: size.height * ratio, height: size.height)
    }
    return size
  }

  /// A size in pixels limited to the picture and at least 2 pixels a side.
  /// With a ratio, both sides shrink together so the shape is kept. Custom
  /// limits each side on its own.
  private func limitedSize(_ size: CGSize, to videoSize: CGSize) -> CGSize {
    let limited: CGSize
    if ratio != nil {
      let scale = min(
        1, videoSize.width / size.width, videoSize.height / size.height)
      limited = CGSize(width: size.width * scale, height: size.height * scale)
    } else {
      limited = CGSize(
        width: min(size.width, videoSize.width),
        height: min(size.height, videoSize.height))
    }
    return CGSize(width: max(limited.width, 2), height: max(limited.height, 2))
  }

  /// A rectangle of the given size centered on the given point.
  private static func rect(of size: CGSize, centeredOn center: CGPoint)
    -> CGRect
  {
    CGRect(
      x: center.x - size.width / 2,
      y: center.y - size.height / 2,
      width: size.width,
      height: size.height
    )
  }

  /// The rectangle moved only as far as needed to sit inside the picture,
  /// which runs from 0 to 1 on each axis.
  private static func movedInsidePicture(_ rect: CGRect) -> CGRect {
    var moved = rect
    moved.origin.x = min(max(rect.minX, 0), 1 - rect.width)
    moved.origin.y = min(max(rect.minY, 0), 1 - rect.height)
    return moved
  }
}
