import AVFoundation

/// Builds a video composition that renders only part of a video's picture.
/// The output is the size of the crop, with the crop's top left corner at the
/// output's top left.
struct CropCompositionBuilder {
  let asset: AVAsset
  /// The part of the picture to keep, as fractions of its width and height
  /// measured from its top left, such as (x: 0.1, y: 0, width: 0.8, height: 1).
  let crop: CGRect

  func build() async throws -> AVVideoComposition {
    let track = try await videoTrack()
    let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
    let pixelCrop = pixelRect(in: Self.displayedSize(of: naturalSize, transform: transform))
    let instruction = try await instruction(for: track, transform: transform, shiftedBy: pixelCrop.origin)
    return try await composition(renderSize: pixelCrop.size, instruction: instruction)
  }

  /// The asset's first video track.
  private func videoTrack() async throws -> AVAssetTrack {
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
      throw CocoaError(.fileReadCorruptFile)
    }
    return track
  }

  /// The picture's size as it's shown, with any rotation applied, so a crop
  /// chosen on screen lines up with it.
  private static func displayedSize(of naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
    let rotated = naturalSize.applying(transform)
    return CGSize(width: abs(rotated.width), height: abs(rotated.height))
  }

  /// The crop in whole pixels. Video encoders need even dimensions, so the size
  /// is rounded to even numbers, and the result is kept inside the picture.
  private func pixelRect(in pictureSize: CGSize) -> CGRect {
    let width = min(Self.evenPixels(crop.width * pictureSize.width), pictureSize.width)
    let height = min(Self.evenPixels(crop.height * pictureSize.height), pictureSize.height)
    return CGRect(
      x: min((crop.minX * pictureSize.width).rounded(), pictureSize.width - width),
      y: min((crop.minY * pictureSize.height).rounded(), pictureSize.height - height),
      width: width,
      height: height
    )
  }

  /// An instruction covering the whole video that turns the picture upright,
  /// as the track's own transform does, then shifts it so the given point
  /// lands at the output's top left.
  private func instruction(
    for track: AVAssetTrack,
    transform: CGAffineTransform,
    shiftedBy offset: CGPoint
  ) async throws -> AVVideoCompositionInstruction {
    var layerInstruction = AVVideoCompositionLayerInstruction.Configuration(assetTrack: track)
    let shift = CGAffineTransform(translationX: -offset.x, y: -offset.y)
    layerInstruction.setTransform(transform.concatenating(shift), at: .zero)

    let duration = try await asset.load(.duration)
    return AVVideoCompositionInstruction(
      configuration: AVVideoCompositionInstruction.Configuration(
        backgroundColor: nil,
        enablePostProcessing: false,
        layerInstructions: [AVVideoCompositionLayerInstruction(configuration: layerInstruction)],
        requiredSourceSampleDataTrackIDs: [],
        timeRange: CMTimeRange(start: .zero, duration: duration)
      )
    )
  }

  /// A composition that keeps the asset's own settings, such as its frame
  /// rate, but renders at the given size using the given instruction.
  private func composition(
    renderSize: CGSize,
    instruction: AVVideoCompositionInstruction
  ) async throws -> AVVideoComposition {
    var configuration = try await AVVideoComposition.Configuration(for: asset, prototypeInstruction: nil)
    configuration.renderSize = renderSize
    configuration.instructions = [instruction]
    return AVVideoComposition(configuration: configuration)
  }

  /// Rounds to the nearest even number of pixels, and at least 2.
  private static func evenPixels(_ value: CGFloat) -> CGFloat {
    max(2, (value / 2).rounded() * 2)
  }
}
