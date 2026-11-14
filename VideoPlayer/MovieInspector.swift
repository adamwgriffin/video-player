import SwiftUI

/// The contents of the movie inspector panel: details about the open video.
struct MovieInspector: View {
  let videoModel: VideoModel

  var body: some View {
    Group {
      if let info = videoModel.player?.info {
        VStack(spacing: 10) {
          // The title, with the description beneath it if the file has one.
          VStack(spacing: 4) {
            Text(info.name)
              .font(.headline)
              .lineLimit(2)
              .truncationMode(.middle)
              .multilineTextAlignment(.center)
              .textSelection(.enabled)

            if let description = info.descriptionText {
              Text(description)
                .font(.caption)
                .multilineTextAlignment(.center)
                // Lets the text wrap onto as many lines as it needs.
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            }
          }

          Divider()

          Grid(
            alignment: .leadingFirstTextBaseline,
            horizontalSpacing: 12,
            verticalSpacing: 6
          ) {
            row("Video Format", info.videoCodec ?? "Unknown")
            row("Audio Format", audioFormat(of: info))
            row("Resolution", size(of: info))
            row("Aspect Ratio", aspectRatio(of: info))
            row("Duration", duration(of: info))
            row("Frame Rate", frameRate(of: info))
            row("Data Size", dataSize(of: info))
            row("Data Rate", dataRate(of: info))
          }
        }
      } else {
        Text("Loading…")
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .frame(minWidth: 380)
    // Darkens the panel's translucent background. A higher opacity is darker.
    .background(.black.opacity(0.3))
  }

  private func row(_ label: String, _ value: String) -> some View {
    GridRow {
      Text(label)
        .foregroundStyle(.secondary)
        .gridColumnAlignment(.trailing)
      Text(value)
        .textSelection(.enabled)
    }
  }

  /// The audio codec and sample rate, such as "MPEG-4 AAC, 48000 Hz".
  private func audioFormat(of info: VideoInfo) -> String {
    guard let codec = info.audioCodec else { return "None" }
    guard let sampleRate = info.audioSampleRate, sampleRate > 0 else {
      return codec
    }
    return "\(codec), \(Int(sampleRate)) Hz"
  }

  private func size(of info: VideoInfo) -> String {
    guard let size = info.pixelSize else { return "Unknown" }
    return "\(Int(size.width)) × \(Int(size.height))"
  }

  /// The shape of the picture, such as 16:9. Sizes that don't reduce to small
  /// numbers, like 1366 × 768, are shown as a decimal instead (1.78:1).
  private func aspectRatio(of info: VideoInfo) -> String {
    guard let size = info.pixelSize, size.width > 0, size.height > 0 else {
      return "Unknown"
    }

    let width = Int(size.width)
    let height = Int(size.height)
    let divisor = greatestCommonDivisor(width, height)
    let reducedWidth = width / divisor
    let reducedHeight = height / divisor

    if max(reducedWidth, reducedHeight) <= 30 {
      return "\(reducedWidth):\(reducedHeight)"
    }
    return String(format: "%.2f:1", size.width / size.height)
  }

  private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
    b == 0 ? a : greatestCommonDivisor(b, a % b)
  }

  private func duration(of info: VideoInfo) -> String {
    Duration
      .seconds(Int(info.duration))
      .formatted(.time(pattern: .hourMinuteSecond))
  }

  private func frameRate(of info: VideoInfo) -> String {
    info.frameRate > 0 ? String(format: "%.2f fps", info.frameRate) : "Unknown"
  }

  private func dataSize(of info: VideoInfo) -> String {
    guard let fileSize = info.fileSize else { return "Unknown" }
    return fileSize.formatted(.byteCount(style: .file))
  }

  private func dataRate(of info: VideoInfo) -> String {
    info.dataRate > 0
      ? String(
        format: "%.1f Mbps",
        info.dataRate / 1_000_000
      ) : "Unknown"
  }
}
