import AVFoundation

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

  /// Reads the details from the file. Anything the file doesn't say is left
  /// out rather than failing the whole load.
  static func load(from url: URL, asset: AVAsset) async -> VideoInfo {
    var videoCodec: String?
    var pixelSize: CGSize?
    var frameRate: Float = 0
    var dataRate: Float = 0

    if let track = try? await asset.loadTracks(withMediaType: .video).first {
      if let descriptions = try? await track.load(.formatDescriptions),
         let description = descriptions.first {
        videoCodec = codecName(CMFormatDescriptionGetMediaSubType(description))
      }
      if let (naturalSize, transform) = try? await track.load(.naturalSize, .preferredTransform) {
        let size = naturalSize.applying(transform)
        pixelSize = CGSize(width: abs(size.width), height: abs(size.height))
      }
      if let (rate, bitRate) = try? await track.load(.nominalFrameRate, .estimatedDataRate) {
        frameRate = rate
        dataRate = bitRate
      }
    }

    var audioCodec: String?
    var audioSampleRate: Double?
    if let track = try? await asset.loadTracks(withMediaType: .audio).first,
       let descriptions = try? await track.load(.formatDescriptions),
       let description = descriptions.first {
      audioCodec = codecName(CMFormatDescriptionGetMediaSubType(description))
      audioSampleRate = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee.mSampleRate
    }

    let duration = (try? await asset.load(.duration).seconds) ?? 0
    let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize

    var descriptionText: String?
    // The common metadata is loaded separately because items in the full
    // metadata keep their own format's identifiers, not the common ones.
    let metadata = (try? await asset.load(.metadata)) ?? []
    let commonMetadata = (try? await asset.load(.commonMetadata)) ?? []
    descriptionText = await description(in: metadata + commonMetadata)

    return VideoInfo(
      name: url.lastPathComponent,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      audioSampleRate: audioSampleRate,
      pixelSize: pixelSize,
      duration: duration.isFinite ? duration : 0,
      frameRate: frameRate,
      dataRate: dataRate,
      fileSize: fileSize,
      descriptionText: descriptionText
    )
  }

  /// The first non-empty description found. Different tools store it under
  /// different keys, so this tries the common ones in turn.
  private static func description(in metadata: [AVMetadataItem]) async -> String? {
    let identifiers: [AVMetadataIdentifier] = [
      .quickTimeUserDataDescription,
      .commonIdentifierDescription,
      .quickTimeMetadataDescription,
      .iTunesMetadataDescription,
      .id3MetadataComments,
    ]
    for identifier in identifiers {
      for item in AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier) {
        if let value = try? await item.load(.stringValue), !value.isEmpty {
          return value
        }
      }
    }
    return nil
  }

  /// A readable name for a codec, or its four-character code if it's one this
  /// doesn't recognize.
  private static func codecName(_ code: FourCharCode) -> String {
    let fourCC = String(
      bytes: [24, 16, 8, 0].map { UInt8((code >> $0) & 0xff) },
      encoding: .macOSRoman
    ) ?? ""

    switch fourCC {
    case "avc1", "avc3": return "H.264"
    case "hvc1", "hev1": return "HEVC"
    case "av01": return "AV1"
    case "vp09": return "VP9"
    case "mp4v": return "MPEG-4 Video"
    case "jpeg": return "Photo JPEG"
    case "apcn", "apch", "apcs", "apco", "ap4h", "ap4x": return "Apple ProRes"
    case "mp4a", "aac ": return "MPEG-4 AAC"
    case "lpcm": return "Linear PCM"
    case "alac": return "Apple Lossless"
    case "ac-3": return "AC-3"
    case "ec-3": return "E-AC-3"
    default: return fourCC.trimmingCharacters(in: .whitespaces)
    }
  }
}
