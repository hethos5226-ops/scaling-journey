import SwiftUI

/// The most recent progress photo, shown large.
///
/// The photo is the app's differentiator, so it gets a full-width card and the
/// weight is laid over it rather than beside it — one glance answers "what did
/// I look like at this weight".
struct LatestPhotoCard: View {
    var entry: WeightEntrySnapshot?
    var formatter: WeightFormatter
    var onTap: (WeightEntrySnapshot) -> Void
    var onAddPhoto: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SJSectionHeader("Latest photo")

            if let entry, let photo = entry.photo {
                Button {
                    onTap(entry)
                } label: {
                    photoCard(entry: entry, photo: photo)
                }
                .buttonStyle(.plain)
            } else {
                SJCard {
                    SJEmptyState(
                        systemImage: "camera",
                        title: "No photos yet",
                        message: "A photo alongside the number is what makes progress visible. Add one the next time you log."
                    ) {
                        Button("Add a photo", action: onAddPhoto)
                            .buttonStyle(SJSecondaryButtonStyle())
                            .frame(maxWidth: 220)
                    }
                }
            }
        }
    }

    private func photoCard(entry: WeightEntrySnapshot, photo: PhotoSnapshot) -> some View {
        // A fixed 4:5 frame keeps the Home layout stable regardless of the
        // source photo's aspect ratio; the image fills and crops to it.
        SJAspectFill {
            ZStack(alignment: .bottom) {
                SJPhotoImage(assetIdentifier: photo.assetIdentifier, variant: .full) {
                    SJPhotoPlaceholder(systemImage: "photo")
                }
                caption(for: entry)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Latest progress photo")
        .accessibilityValue(
            "\(formatter.string(fromKilograms: entry.weightKilograms)) on \(entry.measuredAt.formatted(date: .abbreviated, time: .omitted))"
        )
        .accessibilityAddTraits(.isButton)
    }

    /// Weight and date over a bottom scrim, so light photos keep the text legible.
    private func caption(for entry: WeightEntrySnapshot) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(formatter.string(fromKilograms: entry.weightKilograms))
                .font(.system(size: 26, weight: .semibold))
                .monospacedDigit()

            Spacer()

            Text(entry.measuredAt, format: .dateTime.day().month(.abbreviated).year())
                .font(.sjCaptionEmphasis)
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Theme.Space.md)
        .padding(.bottom, Theme.Space.md)
        .padding(.top, Theme.Space.xxl)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
