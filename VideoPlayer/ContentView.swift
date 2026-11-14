import SwiftUI

struct ContentView: View {
  @Environment(VideoModel.self) private var videoModel

  var body: some View {
    if let player = videoModel.player {
      VStack(spacing: 0) {
        VideoSurface(player: player.queuePlayer)
          // A clear layer on top receives the clicks, since the AVPlayerView
          // underneath can swallow them.
          .overlay {
            Color.clear
              .contentShape(Rectangle())
              .onTapGesture {
                player.togglePlayback()
              }
          }
        if !videoModel.isFullScreen {
          PlaybackControls(player: player)
        }
      }
      .overlay(alignment: .top) {
        if let progress = videoModel.exportProgress {
          ProgressView("Exporting…", value: progress)
            .frame(width: 240)
            .padding(12)
            .background(.regularMaterial, in: .rect(cornerRadius: 8))
            .padding(.top, 16)
        }
      }
      .frame(minWidth: 480, minHeight: 270)
    }
  }
}
