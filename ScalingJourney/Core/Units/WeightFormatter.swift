import Foundation

/// Formats canonical kilogram values for display in the user's chosen unit.
///
/// A single place for every weight string in the app, so `81.2 kg`, `+0.4 kg`
/// and `12 st 4.2 lb` are always spelled the same way.
struct WeightFormatter: Sendable {
    var unit: MassUnit

    init(unit: MassUnit) {
        self.unit = unit
    }

    /// e.g. `81.2` — the number alone, for large hero typography where the
    /// unit is rendered separately at a smaller size.
    func number(fromKilograms kilograms: Double) -> String {
        switch unit {
        case .kilograms, .pounds:
            return Self.decimal(unit.value(fromKilograms: kilograms), digits: unit.fractionDigits)
        case .stones:
            let parts = StoneComponents(kilograms: kilograms)
            return "\(parts.stones) st \(Self.decimal(parts.pounds, digits: 1))"
        }
    }

    /// e.g. `81.2 kg` or `12 st 4.2 lb`.
    func string(fromKilograms kilograms: Double) -> String {
        switch unit {
        case .kilograms, .pounds:
            "\(number(fromKilograms: kilograms)) \(unit.symbol)"
        case .stones:
            "\(number(fromKilograms: kilograms)) lb"
        }
    }

    /// A signed change, e.g. `+0.4 kg`, `−1.8 kg`, or `No change`.
    ///
    /// Uses a true minus sign (U+2212) rather than a hyphen so numbers align
    /// optically in a column.
    func signedChange(kilograms delta: Double, includeUnit: Bool = true) -> String {
        let converted: Double
        switch unit {
        case .kilograms, .pounds:
            converted = unit.value(fromKilograms: delta)
        case .stones:
            // A *delta* in stones reads more naturally in pounds.
            converted = MassUnit.pounds.value(fromKilograms: delta)
        }

        let digits = unit == .stones ? 1 : unit.fractionDigits

        // Anything that rounds to zero at display precision is "no change",
        // otherwise the UI shows a meaningless "+0.0 kg". Round numerically
        // rather than re-parsing the formatted string, which would be locale
        // dependent.
        let scale = pow(10.0, Double(digits))
        let rounded = (converted * scale).rounded() / scale
        guard rounded != 0 else { return "No change" }

        let magnitude = Self.decimal(abs(rounded), digits: digits)
        let sign = rounded > 0 ? "+" : "\u{2212}"
        guard includeUnit else { return sign + magnitude }
        let symbol = unit == .stones ? "lb" : unit.symbol
        return "\(sign)\(magnitude) \(symbol)"
    }

    /// The text that should prefill a numeric entry field.
    func editingValue(fromKilograms kilograms: Double) -> String {
        Self.decimal(unit.value(fromKilograms: kilograms), digits: unit.fractionDigits)
    }

    // MARK: - Private

    private static func decimal(_ value: Double, digits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.usesGroupingSeparator = false
        // `-0.0` is a real Double and formats as "-0", which looks broken.
        let normalised = value == 0 ? 0 : value
        return formatter.string(from: NSNumber(value: normalised)) ?? String(format: "%.\(digits)f", normalised)
    }
}

// MARK: - Parsing

enum WeightParser {
    /// Plausible human body weights, in kilograms. Anything outside this is
    /// almost certainly a typo (a decimal point in the wrong place) and the
    /// logging form refuses to save it.
    static let plausibleKilograms: ClosedRange<Double> = 2...500

    /// Parses free text typed into the weight field, honouring the device's
    /// decimal separator so "81,2" works on a comma-decimal locale.
    ///
    /// Returns the value in **kilograms**, or `nil` when the text is not a
    /// plausible body weight.
    static func kilograms(from text: String, unit: MassUnit) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value > 0 else { return nil }

        let kilograms = unit.kilograms(fromValue: value)
        guard plausibleKilograms.contains(kilograms) else { return nil }
        return kilograms
    }
}
