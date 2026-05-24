import XCTest
@testable import NookKit

final class IndexedDisplayNameTests: XCTestCase {
    func testSingleNamedSpaceReturnsName() {
        let spaces = [(uuid: "A", name: Optional("Coding"))]
        XCTAssertEqual(indexedDisplayName(for: "A", in: spaces), "Coding")
    }

    func testDifferentNamesNoCollision() {
        let spaces = [(uuid: "A", name: Optional("Coding")), (uuid: "B", name: Optional("Work"))]
        XCTAssertEqual(indexedDisplayName(for: "A", in: spaces), "Coding")
        XCTAssertEqual(indexedDisplayName(for: "B", in: spaces), "Work")
    }

    func testCollisionAppendsSequentialIndex() {
        let spaces = [(uuid: "A", name: Optional("Coding")), (uuid: "B", name: Optional("Coding"))]
        XCTAssertEqual(indexedDisplayName(for: "A", in: spaces), "Coding 1")
        XCTAssertEqual(indexedDisplayName(for: "B", in: spaces), "Coding 2")
    }

    func testPartialCollisionLeavesUniqueNameUntouched() {
        let spaces = [(uuid: "A", name: Optional("Coding")), (uuid: "B", name: Optional("Work")), (uuid: "C", name: Optional("Coding"))]
        XCTAssertEqual(indexedDisplayName(for: "A", in: spaces), "Coding 1")
        XCTAssertEqual(indexedDisplayName(for: "B", in: spaces), "Work")
        XCTAssertEqual(indexedDisplayName(for: "C", in: spaces), "Coding 2")
    }

    func testUnnamedSpaceReturnsDesktopN() {
        let spaces: [(uuid: String, name: String?)] = [(uuid: "A", name: nil), (uuid: "B", name: "Work")]
        XCTAssertEqual(indexedDisplayName(for: "A", in: spaces), "Desktop 1")
    }

    func testUnnamedSpaceAtPositionTwoReturnsDesktopTwo() {
        let spaces: [(uuid: String, name: String?)] = [(uuid: "A", name: "Coding"), (uuid: "B", name: nil)]
        XCTAssertEqual(indexedDisplayName(for: "B", in: spaces), "Desktop 2")
    }
}
