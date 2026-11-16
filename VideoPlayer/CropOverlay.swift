import SwiftUI

/// The crop tool drawn over the video
struct CropOverlay: View {
  let player: Player
  /// The video's size in pixels, used to find where the picture sits in the
  /// view, since it's letterboxed to fit.
  let videoSize: CGSize
  /// Whether resizing keeps the crop rectangle's current shape.
  let keepsShape: Bool

  /// The crop rectangle when the current drag began, so each drag moves it
  /// relative to where it started.
  @State private var dragStartRect: CGRect?
  /// Whether the rectangle itself is being dragged, for the closed hand.
  @State private var isMoving = false

  /// The overlay background.
  private let overlayBackground = Color.black.opacity(0.9)
  private let handleSize: CGFloat = 9
  private let handleBorderWidth: CGFloat = 1
  private let handleColor = Color(.sRGB, red: 0, green: 0.473, blue: 0.837)
  /// A larger area around each handle that can be grabbed.
  private let handleHitSize: CGFloat = 17
  /// The smallest the crop can be made, in points on screen.
  private let minimumCropSize: CGFloat = 20

  private static let wholePicture = CGRect(x: 0, y: 0, width: 1, height: 1)

  var body: some View {
    GeometryReader { geometry in
      let videoFrame = Self.aspectFitFrame(for: videoSize, in: geometry.size)
      let crop = Self.viewRect(for: player.cropRect ?? Self.wholePicture, in: videoFrame)

      ZStack(alignment: .topLeading) {
        // Everything outside the crop: the whole view with the crop cut out.
        Path { path in
          path.addRect(CGRect(origin: .zero, size: geometry.size))
          path.addRect(crop)
        }
        .fill(overlayBackground, style: FillStyle(eoFill: true))
        // Clicks pass through to whatever is underneath.
        .allowsHitTesting(false)

        marchingAnts(around: crop)

        Rectangle()
          .fill(.clear)
          .contentShape(Rectangle())
          .frame(width: crop.width, height: crop.height)
          .position(x: crop.midX, y: crop.midY)
          .pointerStyle(isMoving ? .grabActive : .grabIdle)
          .gesture(drag(handle: nil, videoFrame: videoFrame))

        ForEach(CropHandle.allCases, id: \.self) { handle in
          Circle()
            .fill(handleColor)
            .stroke(.white, lineWidth: handleBorderWidth)
            .frame(width: handleSize, height: handleSize)
            .frame(width: handleHitSize, height: handleHitSize)
            .contentShape(Rectangle())
            .pointerStyle(.frameResize(position: Self.resizePosition(for: handle)))
            .position(handle.position(in: crop))
            .gesture(drag(handle: handle, videoFrame: videoFrame))
        }
      }
    }
  }

  /// A dashed border that moves continuously around the rectangle.
  private func marchingAnts(around rect: CGRect) -> some View {
    TimelineView(.animation) { context in
      // Moves 16 points a second, repeating every 8 points: one dash and gap.
      let phase = (context.date.timeIntervalSinceReferenceDate * 16).truncatingRemainder(dividingBy: 8)
      ZStack {
        Path(rect).stroke(.black, style: StrokeStyle(lineWidth: 1, dash: [4, 4], dashPhase: phase))
        Path(rect).stroke(.white, style: StrokeStyle(lineWidth: 1, dash: [4, 4], dashPhase: phase + 4))
      }
    }
    .allowsHitTesting(false)
  }

  /// Dragging a handle resizes the crop. Dragging with no handle, inside the
  /// rectangle, moves it.
  private func drag(handle: CropHandle?, videoFrame: CGRect) -> some Gesture {
    DragGesture(minimumDistance: 2)
      .onChanged { value in
        let start = dragStartRect ?? player.cropRect ?? Self.wholePicture
        if dragStartRect == nil { dragStartRect = start }

        // The drag as fractions of the picture, to match the crop rectangle.
        let dx = value.translation.width / videoFrame.width
        let dy = value.translation.height / videoFrame.height
        if handle == nil, !isMoving {
          isMoving = true
        }
        if let handle {
          let minWidth = minimumCropSize / videoFrame.width
          let minHeight = minimumCropSize / videoFrame.height
          player.setCrop(
            keepsShape
              ? handle.resizeKeepingShape(start, dx: dx, dy: dy, minWidth: minWidth, minHeight: minHeight)
              : handle.resize(start, dx: dx, dy: dy, minWidth: minWidth, minHeight: minHeight)
          )
        } else {
          player.setCrop(Self.move(start, dx: dx, dy: dy))
        }
      }
      .onEnded { _ in
        dragStartRect = nil
        isMoving = false
      }
  }

  /// Which edge or corner a handle resizes from, so the pointer shows the
  /// system's resize arrows for it.
  private static func resizePosition(for handle: CropHandle) -> FrameResizePosition {
    switch handle {
    case .topLeft: .topLeading
    case .top: .top
    case .topRight: .topTrailing
    case .right: .trailing
    case .bottomRight: .bottomTrailing
    case .bottom: .bottom
    case .bottomLeft: .bottomLeading
    case .left: .leading
    }
  }

  /// The rectangle moved by dx and dy, kept inside the picture.
  private static func move(_ rect: CGRect, dx: CGFloat, dy: CGFloat) -> CGRect {
    var moved = rect
    moved.origin.x = min(max(rect.minX + dx, 0), 1 - rect.width)
    moved.origin.y = min(max(rect.minY + dy, 0), 1 - rect.height)
    return moved
  }

  /// Where the picture sits in the view: as large as fits, keeping its shape,
  /// and centered, which is how video is normally fitted to a view.
  private static func aspectFitFrame(for videoSize: CGSize, in viewSize: CGSize) -> CGRect {
    guard videoSize.width > 0, videoSize.height > 0 else { return CGRect(origin: .zero, size: viewSize) }
    let scale = min(viewSize.width / videoSize.width, viewSize.height / videoSize.height)
    let size = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
    return CGRect(
      x: (viewSize.width - size.width) / 2,
      y: (viewSize.height - size.height) / 2,
      width: size.width,
      height: size.height
    )
  }

  /// Converts a crop rectangle in fractions of the picture to points in the
  /// view.
  private static func viewRect(for crop: CGRect, in videoFrame: CGRect) -> CGRect {
    CGRect(
      x: videoFrame.minX + crop.minX * videoFrame.width,
      y: videoFrame.minY + crop.minY * videoFrame.height,
      width: crop.width * videoFrame.width,
      height: crop.height * videoFrame.height
    )
  }
}
