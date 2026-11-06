import SwiftUI

struct ContentView: View {
  let model: VideoModel

  var body: some View {
    if let player = model.player {
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
        if !model.isFullScreen {
          PlaybackControls(player: player)
        }
      }
      .frame(minWidth: 480, minHeight: 270)
    }
  }
}

#Preview {
  ContentView(model: VideoModel())
}
