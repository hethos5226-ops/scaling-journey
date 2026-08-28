import SwiftUI

/// Design tokens.
///
/// The visual language is deliberately restrained: system backgrounds, one
/// accent colour, generous space, and typography doing most of the work. The
/// user's photo should be the most colourful thing on screen.
enum Theme {
    // MARK: Spacing

    /// A 4pt scale. Using named steps rather than raw numbers keeps rhythm
    /// consistent across screens built at different times.
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 44

        /// Standard horizontal inset for full-width screen content.
        static let screenHorizontal: CGFloat = 20
    }

    // MARK: Shape

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 22
        static let photo: CGFloat = 24
    }

    // MARK: Motion

    /// One spring for everything that moves, so transitions feel like a single
    /// piece of software rather than a collection of screens.
    enum Motion {
        static let standard: Animation = .spring(response: 0.38, dampingFraction: 0.86)
        static let quick: Animation = .spring(response: 0.26, dampingFraction: 0.9)
    }
}

// MARK: - Colours

extension Color {
    /// Page background. Grouped so cards read as raised surfaces.
    static let sjBackground = Color(uiColor: .systemGroupedBackground)

    /// Card and row surface.
    static let sjSurface = Color(uiColor: .secondarySystemGroupedBackground)

    /// Surface for controls sitting on top of a card.
    static let sjSurfaceElevated = Color(uiColor: .tertiarySystemGroupedBackground)

    static let sjPrimaryText = Color(uiColor: .label)
    static let sjSecondaryText = Color(uiColor: .secondaryLabel)
    static let sjTertiaryText = Color(uiColor: .tertiaryLabel)
    static let sjSeparator = Color(uiColor: .separator)

    /// The single accent. Defined in the asset catalog so it also drives the
    /// system tint for controls we do not style by hand.
    static let sjAccent = Color.accentColor

    /// Placeholder fill shown while a photo decodes.
    static let sjPhotoPlaceholder = Color(uiColor: .tertiarySystemFill)
}

/// How a weight change should be tinted.
///
/// Deliberately **not** "green for loss, red for gain". Users arrive here with
/// different goals — some are gaining on purpose — and colouring a direction as
/// good or bad makes the app judgmental. Instead the accent marks movement
/// *toward* the user's goal and everything else stays neutral.
enum ChangeTint {
    case towardGoal
    case awayFromGoal
    case neutral

    var color: Color {
        switch self {
        case .towardGoal: .sjAccent
        case .awayFromGoal: .sjSecondaryText
        case .neutral: .sjSecondaryText
        }
    }

    /// Chooses a tint from a change and the direction the user is aiming in.
    /// Falls back to neutral when no goal is set, so a user without a goal is
    /// never told their week went the wrong way.
    static func forChange(_ change: Double, goalKilograms: Double?, currentKilograms: Double?) -> ChangeTint {
        guard
            let goal = goalKilograms,
            let current = currentKilograms,
            abs(change) > 0.001
        else { return .neutral }

        // Distance to goal before and after the change.
        let before = abs((current - change) - goal)
        let after = abs(current - goal)
        return after < before ? .towardGoal : .awayFromGoal
    }
}
