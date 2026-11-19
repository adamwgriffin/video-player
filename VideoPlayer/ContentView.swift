import SwiftUI

struct ContentView: View {
  @Environment(VideoModel.self) private var videoModel
  /// The frame at the position hovered over on the seek bar, if any.
  @State private var seekPreview: SeekPreview?

  var body: some View {
    @Bindable var videoModel = videoModel

    if let player = videoModel.player {
      VStack(spacing: 0) {
        VideoSurface(player: player.queuePlayer)
          // A clear layer on top receives the clicks, since the AVPlayerView
          // underneath can swallow them. Clicks don't play or pause while the
          // crop tool is showing, so they can't interrupt adjusting the crop.
          .overlay {
            Color.clear
              .contentShape(Rectangle())
              .onTapGesture {
                if !videoModel.isCropping {
                  player.togglePlayback()
                }
              }
          }
          // The crop tool needs the picture's size to line up with it, which
          // is known once the video's details have loaded.
          .overlay {
            if videoModel.isCropping, let videoSize = player.info?.pixelSize {
              CropOverlay(
                player: player,
                videoSize: videoSize,
                keepsShape: videoModel.cropAspectRatio != .custom
              )
            }
          }
          // Over the bottom of the video, just above the controls.
          .overlay {
            if let seekPreview {
              SeekPreviewOverlay(
                preview: seekPreview,
                attributes: player.thumbnailAttributes
              )
            }
          }
        if !videoModel.isFullScreen {
          if videoModel.isCropping {
            CropToolbar(
              aspectRatio: $videoModel.cropAspectRatio,
              width: $videoModel.cropWidthField,
              height: $videoModel.cropHeightField,
              // Typed sizes otherwise wait until focus leaves the field.
              onSubmit: { videoModel.applyPendingCropSize() }
            )
          }
          PlaybackControls(
            player: player,
            showsSeekPreview: videoModel.showsPreviewThumbnails,
            seekPreview: $seekPreview
          )
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
