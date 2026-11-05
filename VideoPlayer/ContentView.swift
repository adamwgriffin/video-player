import AVKit
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

/// The video picture alone. AVPlayerView's built-in controls are turned off
/// because PlaybackControls replaces them.
struct VideoSurface: NSViewRepresentable {
  let player: AVPlayer

  func makeNSView(context: Context) -> AVPlayerView {
    let view = AVPlayerView()
    view.controlsStyle = .none
    view.player = player
    return view
  }

  func updateNSView(_ view: AVPlayerView, context: Context) {
    if view.player !== player {
      view.player = player
    }
  }
}

#Preview {
  ContentView(model: VideoModel())
}
