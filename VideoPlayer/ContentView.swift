import SwiftUI
import AVKit

struct ContentView: View {
  let model: VideoModel

  var body: some View {
    if let player = model.player {
      VideoPlayer(player: player.queuePlayer)
        .frame(minWidth: 480, minHeight: 270)
    }
  }
}

#Preview {
  ContentView(model: VideoModel())
}
