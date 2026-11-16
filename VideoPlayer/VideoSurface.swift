import AVKit
import SwiftUI

/// The video picture alone, with AVPlayerView's built-in controls turned off
/// so other controls can be used instead.
struct VideoSurface: NSViewRepresentable {
  let player: AVPlayer

  func makeNSView(context: Context) -> PassivePlayerView {
    let view = PassivePlayerView()
    view.controlsStyle = .none
    view.player = player
    return view
  }

  func updateNSView(_ view: PassivePlayerView, context: Context) {
    if view.player !== player {
      view.player = player
    }
  }
}
