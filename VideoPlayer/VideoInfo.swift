import Foundation

/// Details about a video file, shown in the movie inspector.
struct VideoInfo {
  let name: String
  let videoCodec: String?
  let audioCodec: String?
  /// Samples per second, such as 48000.
  let audioSampleRate: Double?
  /// Width and height in pixels, with any rotation applied.
  let pixelSize: CGSize?
  let duration: Double
  let frameRate: Float
  /// Bits per second.
  let dataRate: Float
  /// Bytes.
  let fileSize: Int?
  /// The description stored in the file, such as one entered when exporting
  /// from iMovie. Nil if there isn't one.
  let descriptionText: String?
}
