import SwiftUI

// MARK: - Card

/// The app's one card treatment: a rounded surface with no border and no
/// shadow. Depth comes from the background contrast, which stays calm in both
/// light and dark mode where a drop shadow would not.
struct SJCard<Content: View>: View {
    var padding: CGFloat = Theme.Space.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.sjSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
    }
}

// MARK: - Buttons

/// The single prominent action on a screen, e.g. "Log Weight".
struct SJPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Color.sjAccent.opacity(isEnabled ? 1 : 0.35),
                in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}

/// A quieter secondary action that sits next to the primary one.
struct SJSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color.sjAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Color.sjSurfaceElevated,
                in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}

// MARK: - Section header

struct SJSectionHeader<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.sjSectionTitle)
                .foregroundStyle(Color.sjPrimaryText)
            Spacer(minLength: Theme.Space.sm)
            trailing
        }
    }
}

extension SJSectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

// MARK: - Stat tile

/// A labelled number. Used in grids on Home and Progress.
struct SJStatTile: View {
    var label: String
    var value: String
    var tint: Color = .sjPrimaryText
    /// Shown under the value, e.g. "since 12 Aug".
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(label)
                .sjLabelStyle()
                .lineLimit(1)

            Text(value)
                .font(.sjStatNumber)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let caption {
                Text(caption)
                    .font(.sjCaption)
                    .foregroundStyle(Color.sjTertiaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(caption.map { "\(value), \($0)" } ?? value))
    }
}

// MARK: - Empty state

/// Consistent empty state: an icon, a short title, one line of guidance and an
/// optional action. Used wherever a screen has nothing to show yet.
struct SJEmptyState<Action: View>: View {
    var systemImage: String
    var title: String
    var message: String
    @ViewBuilder var action: Action

    init(
        systemImage: String,
        title: String,
        message: String,
        @ViewBuilder action: () -> Action
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.action = action()
    }

    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.sjTertiaryText)
                .padding(.bottom, Theme.Space.xxs)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.sjPrimaryText)

            Text(message)
                .font(.sjCaption)
                .foregroundStyle(Color.sjSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            action
                .padding(.top, Theme.Space.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xl)
    }
}

extension SJEmptyState where Action == EmptyView {
    init(systemImage: String, title: String, message: String) {
        self.init(systemImage: systemImage, title: title, message: message) { EmptyView() }
    }
}

// MARK: - Entry row

/// One entry in a list: date, weight, change, and a thumbnail when there is a
/// photo. Shared by Home's recent list and (later) the calendar day sheet.
struct SJEntryRow: View {
    var entry: WeightEntrySnapshot
    var formatter: WeightFormatter
    /// Change against the previous entry, when one exists.
    var change: Double?
    var changeTint: ChangeTint

    private static let dateFormat = Date.FormatStyle().day().month(.abbreviated)

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            SJPhotoThumbnail(photo: entry.photo, size: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.measuredAt, format: Self.dateFormat)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.sjPrimaryText)

                HStack(spacing: Theme.Space.xxs) {
                    Text(entry.measuredAt, style: .time)
                    if entry.hasNote {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 10))
                            .accessibilityLabel("Has a note")
                    }
                }
                .font(.sjCaption)
                .foregroundStyle(Color.sjTertiaryText)
            }

            Spacer(minLength: Theme.Space.xs)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatter.string(fromKilograms: entry.weightKilograms))
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.sjPrimaryText)

                if let change {
                    Text(formatter.signedChange(kilograms: change))
                        .font(.sjCaption)
                        .monospacedDigit()
                        .foregroundStyle(changeTint.color)
                }
            }
        }
        .padding(.vertical, Theme.Space.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
