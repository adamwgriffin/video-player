import CoreGraphics

/// A frame from the position someone is hovering over on a seek bar, and
/// where the pointer is.
struct SeekPreview {
  let image: CGImage
  /// The pointer's horizontal position in global coordinates.
  var pointerX: CGFloat
}
