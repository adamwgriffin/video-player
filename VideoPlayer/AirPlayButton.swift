import AVKit
import SwiftUI

/// The system's AirPlay button. Clicking it lists nearby AirPlay devices, such
/// as an Apple TV or speaker, to send the video to.
struct AirPlayButton: NSViewRepresentable {
  let player: AVPlayer

  func makeNSView(context: Context) -> AVRoutePickerView {
    let view = AVRoutePickerView()
    view.isRoutePickerButtonBordered = false
    view.player = player
    return view
  }

  func updateNSView(_ view: AVRoutePickerView, context: Context) {
    if view.player !== player {
      view.player = player
    }
  }
}
