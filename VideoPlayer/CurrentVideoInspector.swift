import SwiftUI

/// Shows MovieInspector for the video that's open, and updates it when another
/// video is opened.
struct CurrentVideoInspector: View {
  @Environment(VideoModel.self) private var videoModel

  var body: some View {
    MovieInspector(info: videoModel.player?.info)
  }
}
