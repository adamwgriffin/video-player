import CoreGraphics

/// One of the handles on the crop rectangle's corners and edges that
/// resize it.
enum CropHandle: CaseIterable {
  case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

  /// Where the handle sits on the rectangle.
  func position(in rect: CGRect) -> CGPoint {
    let x: CGFloat =
      movesLeftEdge ? rect.minX : movesRightEdge ? rect.maxX : rect.midX
    let y: CGFloat =
      movesTopEdge ? rect.minY : movesBottomEdge ? rect.maxY : rect.midY
    return CGPoint(x: x, y: y)
  }

  /// The rectangle after dragging this handle by dx and dy. All values are
  /// fractions of the picture, so the result stays between 0 and 1 and never
  /// gets smaller than the minimum size.
  func resize(
    _ rect: CGRect, dx: CGFloat, dy: CGFloat, minWidth: CGFloat,
    minHeight: CGFloat
  ) -> CGRect {
    var minX = rect.minX
    var maxX = rect.maxX
    var minY = rect.minY
    var maxY = rect.maxY
    if movesLeftEdge { minX = min(max(minX + dx, 0), maxX - minWidth) }
    if movesRightEdge { maxX = max(min(maxX + dx, 1), minX + minWidth) }
    if movesTopEdge { minY = min(max(minY + dy, 0), maxY - minHeight) }
    if movesBottomEdge { maxY = max(min(maxY + dy, 1), minY + minHeight) }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  /// The rectangle after dragging this handle, keeping its shape. Corners stay
  /// pinned to the opposite corner and follow whichever side the drag changed
  /// more. Edges stay pinned to the opposite edge and stay centered on the
  /// other axis. The rectangle is kept inside the picture and above the
  /// minimum size.
  func resizeKeepingShape(
    _ rect: CGRect,
    dx: CGFloat,
    dy: CGFloat,
    minWidth: CGFloat,
    minHeight: CGFloat
  ) -> CGRect {
    guard rect.width > 0, rect.height > 0 else { return rect }
    let dragged = resize(
      rect, dx: dx, dy: dy, minWidth: minWidth, minHeight: minHeight)
    let anchor = opposite.position(in: rect)
    let limits = scaleLimits(
      for: rect, anchoredAt: anchor, minWidth: minWidth, minHeight: minHeight)
    let scale = min(
      max(dragScale(from: rect, to: dragged), limits.lowerBound),
      limits.upperBound)
    return scaled(rect, by: scale, anchoredAt: anchor)
  }

  /// The handle across the rectangle from this one, which stays still while
  /// this one is dragged.
  private var opposite: CropHandle {
    switch self {
    case .topLeft: .bottomRight
    case .top: .bottom
    case .topRight: .bottomLeft
    case .right: .left
    case .bottomRight: .topLeft
    case .bottom: .top
    case .bottomLeft: .topRight
    case .left: .right
    }
  }

  /// How much a free drag, from rect to dragged, changed the rectangle's size.
  /// A corner follows whichever side changed more, growing or shrinking.
  private func dragScale(from rect: CGRect, to dragged: CGRect) -> CGFloat {
    let widthScale = dragged.width / rect.width
    let heightScale = dragged.height / rect.height
    switch (movesHorizontally, movesVertically) {
    case (true, true):
      return abs(widthScale - 1) >= abs(heightScale - 1)
        ? widthScale : heightScale
    case (true, false): return widthScale
    default: return heightScale
    }
  }

  /// The smallest and largest the rectangle can be scaled: no smaller than the
  /// minimum size, and no larger than the room between the anchor and the
  /// picture's edges.
  private func scaleLimits(
    for rect: CGRect,
    anchoredAt anchor: CGPoint,
    minWidth: CGFloat,
    minHeight: CGFloat
  ) -> ClosedRange<CGFloat> {
    let room = roomToGrow(from: anchor)
    let largest = min(room.width / rect.width, room.height / rect.height)
    let smallest = max(minWidth / rect.width, minHeight / rect.height)
    // If even the minimum size doesn't fit, staying inside the picture wins.
    return min(smallest, largest)...largest
  }

  /// The space from the anchor to the picture's edges, in the directions the
  /// rectangle grows. On an axis where it stays centered, it grows both ways,
  /// so the room is twice the distance to the nearer edge.
  private func roomToGrow(from anchor: CGPoint) -> CGSize {
    CGSize(
      width: movesLeftEdge
        ? anchor.x
        : movesRightEdge ? 1 - anchor.x : 2 * min(anchor.x, 1 - anchor.x),
      height: movesTopEdge
        ? anchor.y
        : movesBottomEdge ? 1 - anchor.y : 2 * min(anchor.y, 1 - anchor.y)
    )
  }

  /// The rectangle at the given scale, placed so the anchor stays where it is.
  private func scaled(
    _ rect: CGRect, by scale: CGFloat, anchoredAt anchor: CGPoint
  ) -> CGRect {
    let width = rect.width * scale
    let height = rect.height * scale
    return CGRect(
      x: movesLeftEdge
        ? anchor.x - width : movesRightEdge ? anchor.x : anchor.x - width / 2,
      y: movesTopEdge
        ? anchor.y - height
        : movesBottomEdge ? anchor.y : anchor.y - height / 2,
      width: width,
      height: height
    )
  }

  private var movesHorizontally: Bool { movesLeftEdge || movesRightEdge }
  private var movesVertically: Bool { movesTopEdge || movesBottomEdge }
  private var movesLeftEdge: Bool {
    [.topLeft, .left, .bottomLeft].contains(self)
  }
  private var movesRightEdge: Bool {
    [.topRight, .right, .bottomRight].contains(self)
  }
  private var movesTopEdge: Bool { [.topLeft, .top, .topRight].contains(self) }
  private var movesBottomEdge: Bool {
    [.bottomLeft, .bottom, .bottomRight].contains(self)
  }
}
