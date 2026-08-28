import Foundation

/// The units a person can choose to *see* their weight in.
///
/// Weight is always **stored** in kilograms (see `WeightEntry.weightKilograms`).
/// This type only ever describes presentation and text entry. Keeping storage
/// canonical means changing the display unit never rewrites a single record and
/// never accumulates rounding drift.
enum MassUnit: String, CaseIterable, Codable, Sendable, Identifiable {
    case kilograms
    case pounds
    case stones

    var id: String { rawValue }

    /// Short symbol shown next to a number, e.g. `81.2 kg`.
    var symbol: String {
        switch self {
        case .kilograms: "kg"
        case .pounds: "lb"
        case .stones: "st"
        }
    }

    var displayName: String {
        switch self {
        case .kilograms: "Kilograms"
        case .pounds: "Pounds"
        case .stones: "Stones"
        }
    }

    /// How many decimal places to show. Stones are displayed as `12 st 4.2 lb`,
    /// so the fractional part lives in the pounds component instead.
    var fractionDigits: Int {
        switch self {
        case .kilograms, .pounds: 1
        case .stones: 1
        }
    }

    /// The smallest sensible step for a stepper or slider, in this unit.
    var step: Double {
        switch self {
        case .kilograms: 0.1
        case .pounds: 0.2
        case .stones: 0.2
        }
    }
}

// MARK: - Conversion

extension MassUnit {
    static let poundsPerKilogram = 2.204_622_621_848_775_8
    static let poundsPerStone = 14.0

    /// Converts a canonical kilogram value into this unit.
    ///
    /// For `.stones` this returns the *total* number of stones as a decimal
    /// (e.g. `12.3 st`). Use `StoneComponents` when you need `12 st 4.2 lb`.
    func value(fromKilograms kilograms: Double) -> Double {
        switch self {
        case .kilograms: kilograms
        case .pounds: kilograms * Self.poundsPerKilogram
        case .stones: kilograms * Self.poundsPerKilogram / Self.poundsPerStone
        }
    }

    /// Converts a value expressed in this unit back to canonical kilograms.
    func kilograms(fromValue value: Double) -> Double {
        switch self {
        case .kilograms: value
        case .pounds: value / Self.poundsPerKilogram
        case .stones: value * Self.poundsPerStone / Self.poundsPerKilogram
        }
    }
}

/// A stones-and-pounds breakdown, e.g. 78.0 kg is 12 st 3.9 lb.
struct StoneComponents: Equatable, Sendable {
    var stones: Int
    var pounds: Double

    init(kilograms: Double) {
        let totalPounds = kilograms * MassUnit.poundsPerKilogram
        var whole = Int((totalPounds / MassUnit.poundsPerStone).rounded(.down))
        var remainder = totalPounds - Double(whole) * MassUnit.poundsPerStone

        // Guard the boundary: 13.98 lb rounds to 14.0 lb for display, which
        // should read as the next stone rather than "12 st 14.0 lb".
        if (remainder * 10).rounded() / 10 >= MassUnit.poundsPerStone {
            whole += 1
            remainder = 0
        }

        self.stones = whole
        self.pounds = remainder
    }
}
