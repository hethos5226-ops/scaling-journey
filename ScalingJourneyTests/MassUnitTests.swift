import XCTest
@testable import ScalingJourney

final class MassUnitTests: XCTestCase {
    func testKilogramsAreIdentity() {
        XCTAssertEqual(MassUnit.kilograms.value(fromKilograms: 81.2), 81.2, accuracy: 0.0001)
        XCTAssertEqual(MassUnit.kilograms.kilograms(fromValue: 81.2), 81.2, accuracy: 0.0001)
    }

    func testPoundsConversionMatchesKnownValue() {
        XCTAssertEqual(MassUnit.pounds.value(fromKilograms: 100), 220.4622, accuracy: 0.001)
        XCTAssertEqual(MassUnit.pounds.kilograms(fromValue: 220.4622), 100, accuracy: 0.001)
    }

    func testStonesConversionMatchesKnownValue() {
        // 100 kg is 220.46 lb, which is 15.747 st.
        XCTAssertEqual(MassUnit.stones.value(fromKilograms: 100), 15.747, accuracy: 0.001)
    }

    /// Every unit must survive a round trip, because the app converts on every
    /// display and every text entry.
    func testRoundTripIsLossless() {
        for unit in MassUnit.allCases {
            for kilograms in [2.0, 45.5, 81.2, 137.9, 499.0] {
                let converted = unit.value(fromKilograms: kilograms)
                XCTAssertEqual(
                    unit.kilograms(fromValue: converted),
                    kilograms,
                    accuracy: 0.0001,
                    "\(unit) round trip failed for \(kilograms)"
                )
            }
        }
    }

    func testStoneComponentsSplitStonesAndPounds() {
        // 78 kg = 171.96 lb = 12 st 3.96 lb
        let parts = StoneComponents(kilograms: 78)
        XCTAssertEqual(parts.stones, 12)
        XCTAssertEqual(parts.pounds, 3.96, accuracy: 0.01)
    }

    /// A remainder that rounds up to a full stone must roll over rather than
    /// display as "12 st 14.0 lb".
    func testStoneComponentsRollOverAtFourteenPounds() {
        // 13.99 lb of remainder: choose a mass just under the next stone.
        let justUnder = MassUnit.stones.kilograms(fromValue: 13.0) - 0.001
        let parts = StoneComponents(kilograms: justUnder)
        XCTAssertEqual(parts.stones, 13)
        XCTAssertEqual(parts.pounds, 0, accuracy: 0.0001)
    }
}
