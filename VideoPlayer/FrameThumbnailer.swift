import AVFoundation

/// Makes small images of a video's frames, such as for previewing a position
/// before jumping to it.
final class FrameThumbnailer {
  private let generator: AVAssetImageGenerator
  private let preferredTimescale: CMTimeScale

  /// `maximumSize` is in pixels. Images are scaled down to fit inside it,
  /// keeping their shape. `preferredTimescale` is the units per second used
  /// for the times frames are requested at. The default, 600, divides evenly
  /// by common frame rates such as 24, 25, and 30.
  init(
    asset: AVAsset, maximumSize: CGSize, preferredTimescale: CMTimeScale = 600
  ) {
    self.preferredTimescale = preferredTimescale
    generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = maximumSize
    // Any nearby frame will do, so the generator can use the nearest keyframe
    // instead of decoding forward to the exact one, which is much faster.
    generator.requestedTimeToleranceBefore = .positiveInfinity
    generator.requestedTimeToleranceAfter = .positiveInfinity
  }

  /// A frame near the given number of seconds into the video, usually the
  /// closest keyframe, or nil if it couldn't be made, such as when the task
  /// was cancelled.
  func image(atSeconds seconds: Double) async -> CGImage? {
    let time = CMTime(
      seconds: seconds, preferredTimescale: preferredTimescale)
    return try? await generator.image(at: time).image
  }
}
