import SwiftUI

extension Font {
    /// The hero weight readout on Home. Large, confident, and monospaced in
    /// the digits so the number does not jitter as it changes.
    static let sjHeroNumber = Font.system(size: 64, weight: .semibold).monospacedDigit()

    /// Section-level number, e.g. inside a stat tile.
    static let sjStatNumber = Font.system(size: 22, weight: .semibold).monospacedDigit()

    /// The unit shown beside a hero number.
    static let sjHeroUnit = Font.system(size: 24, weight: .medium)

    static let sjScreenTitle = Font.system(size: 32, weight: .bold)
    static let sjSectionTitle = Font.system(size: 20, weight: .semibold)

    /// Small uppercase label above a value.
    static let sjLabel = Font.system(size: 12, weight: .semibold)

    static let sjBody = Font.system(size: 16, weight: .regular)
    static let sjCaption = Font.system(size: 13, weight: .regular)
    static let sjCaptionEmphasis = Font.system(size: 13, weight: .medium)
}

extension View {
    /// Small, tracked-out, uppercase label styling used above values.
    func sjLabelStyle() -> some View {
        self
            .font(.sjLabel)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Color.sjSecondaryText)
    }
}
