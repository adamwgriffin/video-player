import AVFoundation
import AppKit
import Observation
import UniformTypeIdentifiers

/// Holds the one video the app is showing. Opening another video replaces it.
@Observable
final class VideoModel {
  private(set) var player: Player?

  /// The video's file name without its extension, for the window title.
  private(set) var title = ""

  /// Whether the window is full screen, when the controls are hidden.
  var isFullScreen = false

  /// Whether a keyboard modifier is held down, which makes the arrow keys skip
  /// instead of step while paused. Kept up to date by the app delegate.
  var skipWhilePaused = false

  /// Whether the movie inspector panel is showing, for the menu item's title.
  var isInspectorShown = false

  /// Where a new crop starts: inset 10% from each edge of the picture, so its
  /// handles aren't on the edge of the video and are easy to grab.
  private static let initialCrop = CGRect(
    x: 0.1, y: 0.1, width: 0.8, height: 0.8)

  /// Whether the crop tool is showing over the video. The video is only
  /// cropped while it is: showing it starts a new crop, inset from the edges
  /// of the picture, and hiding it removes the crop.
  var isCropping = false {
    didSet {
      if isCropping, !oldValue {
        cropAspectRatio = .custom
        player?.setCrop(Self.initialCrop)
      }
      // Hiding the tool removes the crop, and its text fields, so anything
      // typed but not applied is dropped too.
      if !isCropping, oldValue {
        player?.removeCrop()
        pendingCropWidth = nil
        pendingCropHeight = nil
      }
    }
  }

  /// The shape the crop is held to, chosen in the crop toolbar. Choosing one
  /// reshapes the current crop to fit it.
  var cropAspectRatio: CropAspectRatio = .custom {
    didSet {
      guard let player, let videoSize = player.info?.pixelSize else { return }
      let wholePicture = CGRect(x: 0, y: 0, width: 1, height: 1)
      player.setCrop(
        cropAspectRatio.fit(
          player.cropRect ?? wholePicture, videoSize: videoSize))
    }
  }

  /// The crop's size in the video's pixels, or nil until the video's size is
  /// known. With no crop set, it's the whole picture.
  var cropPixelSize: CGSize? {
    guard let player, let videoSize = player.info?.pixelSize else { return nil }
    let crop = player.cropRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
    return CGSize(
      width: crop.width * videoSize.width,
      height: crop.height * videoSize.height)
  }

  /// Sets the crop's width or height in the video's pixels. With a ratio
  /// chosen, the other side follows to keep that shape.
  func setCropSize(width: CGFloat? = nil, height: CGFloat? = nil) {
    guard let player, let videoSize = player.info?.pixelSize else { return }
    let crop = player.cropRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
    player.setCrop(
      cropAspectRatio.resized(
        crop, width: width, height: height, videoSize: videoSize))
  }

  /// A width or height typed into the crop toolbar but not applied yet. Text
  /// fields update their value with every keystroke, so typed values wait
  /// here until editing ends.
  private var pendingCropWidth: Int?
  private var pendingCropHeight: Int?

  /// The crop's width for the crop toolbar's field: what's been typed, if
  /// anything, otherwise the crop's actual width.
  var cropWidthField: Int {
    get { pendingCropWidth ?? Int((cropPixelSize?.width ?? 0).rounded()) }
    // Fields write their value when editing starts and just after it ends,
    // not only when typed into. Only count a value written during editing that
    // differs from the crop's actual size, so those writes aren't applied.
    set {
      guard isEditingText else { return }
      let actual = Int((cropPixelSize?.width ?? 0).rounded())
      pendingCropWidth = newValue == actual ? nil : newValue
    }
  }

  /// The crop's height for the crop toolbar's field: what's been typed, if
  /// anything, otherwise the crop's actual height.
  var cropHeightField: Int {
    get { pendingCropHeight ?? Int((cropPixelSize?.height ?? 0).rounded()) }
    set {
      guard isEditingText else { return }
      let actual = Int((cropPixelSize?.height ?? 0).rounded())
      pendingCropHeight = newValue == actual ? nil : newValue
    }
  }

  /// Whether a text field has keyboard focus right now. Read from AppKit each
  /// time rather than kept as a copy, so it can't fall out of step.
  private var isEditingText: Bool {
    NSApp.keyWindow?.firstResponder is NSText
  }

  /// Applies whatever has been typed into the crop toolbar's fields. Called
  /// when focus leaves a field, however it leaves, and when Return is pressed.
  func applyPendingCropSize() {
    if let width = pendingCropWidth {
      pendingCropWidth = nil
      setCropSize(width: CGFloat(width))
    }
    if let height = pendingCropHeight {
      pendingCropHeight = nil
      setCropSize(height: CGFloat(height))
    }
  }

  /// Whether videos start over when they reach the end. On by default, and
  /// kept when another video is opened.
  var isLooping = true {
    didSet { player?.isLooping = isLooping }
  }

  // The sandbox only grants access to a chosen file while this is held open.
  private var accessedURL: URL?
  private var currentURL: URL?

  /// How far an export has got, from 0 to 1. Nil when nothing is exporting.
  private(set) var exportProgress: Double?

  /// The save dialog's re-encode checkbox. Off by default, and remembered for
  /// the next export while the app is running.
  private var reencodesExports = false

  /// Called after a video starts playing, so the app can show its window.
  var didOpen: (() -> Void)?

  /// Shows the standard macOS open dialog and plays the chosen video.
  func showOpenPanel() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.movie]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false

    if panel.runModal() == .OK, let url = panel.url {
      open(url)
    }
  }

  func open(_ url: URL) {
    // The same open request can arrive through more than one path.
    guard url != currentURL else { return }
    currentURL = url
    title = url.deletingPathExtension().lastPathComponent

    player?.queuePlayer.pause()
    accessedURL?.stopAccessingSecurityScopedResource()

    accessedURL = url.startAccessingSecurityScopedResource() ? url : nil
    isCropping = false
    player = Player(url: url, looping: isLooping)
    player?.queuePlayer.play()
    didOpen?()
  }

  /// Asks where to save, then exports the video trimmed to its start and end
  /// times and cropped to its crop, if either is set. The export is always an
  /// MPEG-4 file, whatever the original is.
  func export() {
    guard let player, exportProgress == nil else { return }

    let savePanel = ExportSavePanel(
      title: title,
      reencodes: reencodesExports,
      reencodeRequired: player.isCropped
    )
    guard let choice = savePanel.run() else { return }
    // When cropping forced the checkbox on, it wasn't a choice, so don't
    // remember it for the next export.
    if !player.isCropped {
      reencodesExports = choice.reencode
    }

    exportProgress = 0
    Task {
      do {
        try await player.export(
          to: choice.url, as: .mp4, reencode: choice.reencode
        ) { fraction in
          self.exportProgress = fraction
        }
      } catch {
        NSAlert(error: error).runModal()
      }
      exportProgress = nil
    }
  }

  /// Stops playback and releases the video, such as when its window closes.
  func close() {
    player?.queuePlayer.pause()
    player = nil
    isCropping = false
    accessedURL?.stopAccessingSecurityScopedResource()
    accessedURL = nil
    currentURL = nil
  }
}
