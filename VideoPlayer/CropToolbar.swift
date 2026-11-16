import SwiftUI

/// A row of options for constraining a crop rectangle to a shape, such as
/// square or 16:9, with fields for its width and height.
struct CropToolbar: View {
  @Binding var aspectRatio: CropAspectRatio
  /// The crop's width and height, in whole pixels.
  @Binding var width: Int
  @Binding var height: Int
  /// Called when Return is pressed in the width or height field, which stays
  /// focused with its text selected.
  var onSubmit: () -> Void = {}

  var body: some View {
    HStack(spacing: 16) {
      Picker("Constrain:", selection: $aspectRatio) {
        ForEach(CropAspectRatio.allCases) { aspectRatio in
          Text(aspectRatio.title).tag(aspectRatio)
        }
      }
      .pickerStyle(.radioGroup)
      .horizontalRadioGroupLayout()
      .fixedSize()

      sizeField("Width:", value: $width)
      sizeField("Height:", value: $height)

      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
    .padding(.bottom, 2)
    .background(.bar)
  }

  /// Ends editing in whichever field has focus. This goes through the window
  /// rather than SwiftUI's focus state, which can put focus back into the
  /// field when its value changes. It waits until the key press has been
  /// handled, so AppKit's own handling of the key can't put focus back.
  private func leaveField() {
    Task {
      NSApp.keyWindow?.makeFirstResponder(nil)
    }
  }

  /// A labeled number field. Text that isn't a whole number is discarded,
  /// and the field goes back to the current value.
  private func sizeField(_ label: String, value: Binding<Int>) -> some View {
    HStack(spacing: 4) {
      Text(label)
      TextField(label, value: value, format: .number.grouping(.never))
        .labelsHidden()
        .multilineTextAlignment(.trailing)
        .monospacedDigit()
        .frame(width: 60)
        // Return keeps the field focused, as macOS text fields do. Escape
        // leaves it, so the keyboard goes back to the rest of the app.
        .onSubmit {
          onSubmit()
        }
        .onExitCommand {
          leaveField()
        }
    }
  }
}
