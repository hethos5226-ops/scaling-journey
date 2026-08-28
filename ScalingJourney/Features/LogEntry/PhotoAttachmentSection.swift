import PhotosUI
import SwiftUI

/// The photo half of the logging form.
///
/// A weight without a photo is still a valid entry — the brief is explicit that
/// saving must not be blocked — so this section persuades rather than gates:
/// the empty state explains *why* a photo is worth adding, and the two ways to
/// provide one sit right underneath.
struct PhotoAttachmentSection: View {
    var state: LogEntryViewModel.PhotoState
    var isProcessing: Bool
    var isCameraAvailable: Bool
    /// The photo's own capture date, when it disagrees with the entry's date.
    var suggestedDate: Date?

    @Binding var pickerSelection: PhotosPickerItem?

    var onTakePhoto: () -> Void
    var onRemove: () -> Void
    var onApplySuggestedDate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("Progress photo")
                .sjLabelStyle()
                .padding(.leading, Theme.Space.xxs)

            SJCard(padding: Theme.Space.md) {
                VStack(spacing: Theme.Space.md) {
                    preview
                    if let suggestedDate { dateSuggestion(suggestedDate) }
                    actions
                }
            }
        }
    }

    // MARK: Preview

    @ViewBuilder
    private var preview: some View {
        switch state {
        case .none:
            VStack(spacing: Theme.Space.xs) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.sjTertiaryText)
                Text("Photos make progress visible in a way numbers cannot.")
                    .font(.sjCaption)
                    .foregroundStyle(Color.sjSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.lg)

        case .pending(let image):
            attachedPhoto {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }

        case .stored(let photo):
            attachedPhoto {
                SJPhotoImage(assetIdentifier: photo.assetIdentifier, variant: .full) {
                    SJPhotoPlaceholder(systemImage: "photo")
                }
            }
        }
    }

    /// Shared chrome for an attached photo: fixed 4:5 frame with a remove
    /// affordance, so switching between a pending and a stored image does not
    /// shift the layout.
    private func attachedPhoto<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        SJAspectFill(cornerRadius: Theme.Radius.medium, content: content)
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.5), in: Circle())
                }
                .padding(Theme.Space.xs)
                .accessibilityLabel("Remove photo")
            }
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.2)
                        ProgressView().tint(.white)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                }
            }
    }


    // MARK: Date suggestion

    /// Offered, never applied automatically. Silently re-dating an entry
    /// because of a photo's metadata would be a surprising, hard-to-notice
    /// change to the user's own record.
    private func dateSuggestion(_ date: Date) -> some View {
        HStack(spacing: Theme.Space.xs) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(Color.sjAccent)

            Text("This photo was taken on \(date.formatted(.dateTime.day().month(.abbreviated).year())).")
                .font(.sjCaption)
                .foregroundStyle(Color.sjSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Theme.Space.xs)

            Button("Use", action: onApplySuggestedDate)
                .font(.sjCaptionEmphasis)
        }
        .padding(Theme.Space.sm)
        .background(Color.sjSurfaceElevated, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: Theme.Space.sm) {
            if isCameraAvailable {
                Button(action: onTakePhoto) {
                    Label(state.hasPhoto ? "Retake" : "Take Photo", systemImage: "camera")
                }
                .buttonStyle(SJSecondaryButtonStyle())
            }

            PhotosPicker(selection: $pickerSelection, matching: .images, photoLibrary: .shared()) {
                Label(state.hasPhoto ? "Replace" : "Choose Photo", systemImage: "photo.on.rectangle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.sjAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Color.sjSurfaceElevated,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    )
            }
        }
    }
}
