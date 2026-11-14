import AVFoundation

/// Reads a video file's details for the movie inspector, and returns them as
/// a VideoInfo.
struct VideoInfoLoader {
  let url: URL
  let asset: AVAsset
  
  /// Reads the details from the file. Anything the file doesn't say is left
  /// out rather than failing the whole load.
  func load() async -> VideoInfo {
    let videoTrack = try? await asset.loadTracks(withMediaType: .video).first
    let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first
    
    return await VideoInfo(
      name: url.lastPathComponent,
      videoCodec: codec(of: videoTrack),
      audioCodec: codec(of: audioTrack),
      audioSampleRate: sampleRate(of: audioTrack),
      pixelSize: pixelSize(of: videoTrack),
      duration: duration(),
      frameRate: frameRate(of: videoTrack),
      dataRate: dataRate(of: videoTrack),
      fileSize: fileSize(),
      descriptionText: descriptionText()
    )
  }
  
  /// The readable name of the track's codec, such as "H.264".
  private func codec(of track: AVAssetTrack?) async -> String? {
    guard let description = await formatDescription(of: track) else { return nil }
    return codecName(CMFormatDescriptionGetMediaSubType(description))
  }
  
  /// Samples per second of an audio track, such as 48000.
  private func sampleRate(of track: AVAssetTrack?) async -> Double? {
    guard let description = await formatDescription(of: track) else { return nil }
    return CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee.mSampleRate
  }
  
  /// Width and height in pixels, with any rotation applied, so a portrait
  /// phone video is taller than it is wide.
  private func pixelSize(of track: AVAssetTrack?) async -> CGSize? {
    guard let track,
          let (naturalSize, transform) = try? await track.load(.naturalSize, .preferredTransform)
            else { return nil }
    let size = naturalSize.applying(transform)
    return CGSize(width: abs(size.width), height: abs(size.height))
  }
  
  /// Length in seconds, or 0 if it isn't known.
  private func duration() async -> Double {
    let seconds = (try? await asset.load(.duration).seconds) ?? 0
    return seconds.isFinite ? seconds : 0
  }
  
  /// Frames per second, or 0 if it isn't known.
  private func frameRate(of track: AVAssetTrack?) async -> Float {
    guard let track else { return 0 }
    return (try? await track.load(.nominalFrameRate)) ?? 0
  }
  
  /// Bits per second, or 0 if it isn't known.
  private func dataRate(of track: AVAssetTrack?) async -> Float {
    guard let track else { return 0 }
    return (try? await track.load(.estimatedDataRate)) ?? 0
  }
  
  /// Size of the file in bytes.
  private func fileSize() -> Int? {
    try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
  }
  
  /// The first non-empty description stored in the file. Different tools store
  /// it under different keys, so this tries the common ones in turn.
  private func descriptionText() async -> String? {
    // The common metadata is loaded separately because items in the full
    // metadata keep their own format's identifiers, not the common ones.
    let metadata = (try? await asset.load(.metadata)) ?? []
    let commonMetadata = (try? await asset.load(.commonMetadata)) ?? []
    
    let identifiers: [AVMetadataIdentifier] = [
      .quickTimeUserDataDescription,
      .commonIdentifierDescription,
      .quickTimeMetadataDescription,
      .iTunesMetadataDescription,
      .id3MetadataComments,
    ]
    for identifier in identifiers {
      for item in AVMetadataItem.metadataItems(from: metadata + commonMetadata, filteredByIdentifier: identifier) {
        if let value = try? await item.load(.stringValue), !value.isEmpty {
          return value
        }
      }
    }
    return nil
  }
  
  /// The track's first format description, which says how it's encoded.
  private func formatDescription(of track: AVAssetTrack?) async -> CMFormatDescription? {
    guard let track else { return nil }
    return try? await track.load(.formatDescriptions).first
  }
  
  /// Readable codec names, keyed by four-character code, such as "avc1" for
  /// "H.264". Read once from CodecNames.plist in the app bundle.
  private static let codecNames: [String: String] = {
    guard let url = Bundle.main.url(forResource: "CodecNames", withExtension: "plist"),
      let data = try? Data(contentsOf: url),
      let names = try? PropertyListDecoder().decode([String: String].self, from: data)
    else {
      // Codecs would still show, as their raw codes, so only stop debug builds.
      assertionFailure("CodecNames.plist is missing from the app bundle or isn't valid")
      return [:]
    }
    return names
  }()

  /// A readable name for a codec, or its four-character code if it's one
  /// CodecNames.plist doesn't list.
  private func codecName(_ code: FourCharCode) -> String {
    let fourCC =
      String(
        bytes: [24, 16, 8, 0].map { UInt8((code >> $0) & 0xff) },
        encoding: .macOSRoman
      ) ?? ""
    return Self.codecNames[fourCC] ?? fourCC.trimmingCharacters(in: .whitespaces)
  }
}
