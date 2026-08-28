import XCTest
@testable import ScalingJourney

final class WeightFormatterTests: XCTestCase {
    func testKilogramStringIncludesSymbol() {
        let formatter = WeightFormatter(unit: .kilograms)
        XCTAssertEqual(formatter.string(fromKilograms: 81.24), "81.2 kg")
    }

    func testStonesRenderAsStonesAndPounds() {
        let formatter = WeightFormatter(unit: .stones)
        XCTAssertEqual(formatter.string(fromKilograms: 78), "12 st 4.0 lb")
    }

    func testSignedChangeUsesTrueMinusSign() {
        let formatter = WeightFormatter(unit: .kilograms)
        XCTAssertEqual(formatter.signedChange(kilograms: -1.8), "\u{2212}1.8 kg")
        XCTAssertEqual(formatter.signedChange(kilograms: 0.4), "+0.4 kg")
    }

    /// A change too small to render must read as "No change" rather than
    /// "+0.0 kg", which looks like a bug.
    func testTinyChangeReadsAsNoChange() {
        let formatter = WeightFormatter(unit: .kilograms)
        XCTAssertEqual(formatter.signedChange(kilograms: 0.01), "No change")
        XCTAssertEqual(formatter.signedChange(kilograms: 0), "No change")
        XCTAssertEqual(formatter.signedChange(kilograms: -0.02), "No change")
    }

    /// Stones users read deltas in pounds; nobody says "I lost 0.1 stone".
    func testStoneDeltaIsExpressedInPounds() {
        let formatter = WeightFormatter(unit: .stones)
        XCTAssertEqual(formatter.signedChange(kilograms: -1), "\u{2212}2.2 lb")
    }
}

final class WeightParserTests: XCTestCase {
    func testParsesPlainDecimal() {
        XCTAssertEqual(WeightParser.kilograms(from: "81.2", unit: .kilograms)!, 81.2, accuracy: 0.001)
    }

    /// Comma-decimal locales type "81,2"; the decimal pad offers that separator.
    func testParsesCommaDecimalSeparator() {
        XCTAssertEqual(WeightParser.kilograms(from: "81,2", unit: .kilograms)!, 81.2, accuracy: 0.001)
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(WeightParser.kilograms(from: "  75.0 ", unit: .kilograms)!, 75.0, accuracy: 0.001)
    }

    func testConvertsFromEntryUnit() {
        XCTAssertEqual(WeightParser.kilograms(from: "180", unit: .pounds)!, 81.646, accuracy: 0.01)
    }

    /// A misplaced decimal point is the most likely typo, so implausible values
    /// are rejected rather than silently ruining every trend.
    func testRejectsImplausibleValues() {
        XCTAssertNil(WeightParser.kilograms(from: "0", unit: .kilograms))
        XCTAssertNil(WeightParser.kilograms(from: "1", unit: .kilograms))
        XCTAssertNil(WeightParser.kilograms(from: "812", unit: .kilograms))
        XCTAssertNil(WeightParser.kilograms(from: "-70", unit: .kilograms))
    }

    func testRejectsNonNumericInput() {
        XCTAssertNil(WeightParser.kilograms(from: "", unit: .kilograms))
        XCTAssertNil(WeightParser.kilograms(from: "abc", unit: .kilograms))
        XCTAssertNil(WeightParser.kilograms(from: "8.1.2", unit: .kilograms))
    }
}
