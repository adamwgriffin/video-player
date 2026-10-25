import AVKit
import SwiftUI

struct ContentView: View {
  // One shared player for the whole process. The preview canvas can create more
  // than one ContentView on first launch, which can cause the audio to continue
  // to play after pausing the video. Sharing the player guarantees there is
  // only ever a single audio source to pause.
  private static let player: LoopingPlayer? = {
    if let url = Bundle.main.url(forResource: "marbles", withExtension: "mp4") {
      return LoopingPlayer(url: url)
    }
    return nil
  }()

  var body: some View {
    if let player = Self.player {
      VideoPlayer(player: player.queuePlayer)
        .onAppear { player.queuePlayer.play() }
        .onDisappear { player.queuePlayer.pause() }
    } else {
      ContentUnavailableView(
        "Video Not Found",
        systemImage: "video.slash",
        description: Text(
          "Add marbles.mp4 to the VideoPlayer target's Copy Bundle Resources."
        )
      )
    }
  }
}

final class LoopingPlayer {
  let queuePlayer = AVQueuePlayer()
  private let looper: AVPlayerLooper

  init(url: URL) {
    let item = AVPlayerItem(url: url)
    looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
  }
}

#Preview {
  ContentView()
}
