import XCTest
import Combine
@testable import NookKit

final class SpaceTrackerTests: XCTestCase {
    private var tracker: MockSpaceTracker!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        tracker = MockSpaceTracker()
        cancellables = []
    }

    func testActiveSpaceReturnsActiveSpaceForDisplay() {
        let spaces: [SpaceInfo] = [
            SpaceInfo(uuid: "A", displayID: 1, isActive: false),
            SpaceInfo(uuid: "B", displayID: 1, isActive: true),
        ]
        tracker.stubbedSpaces[1] = spaces
        let active = tracker.activeSpace(for: 1)
        XCTAssertEqual(active, SpaceInfo(uuid: "B", displayID: 1, isActive: true))
    }

    func testActiveSpaceReturnsNilForUnknownDisplayID() {
        XCTAssertNil(tracker.activeSpace(for: 99))
    }

    func testSpaceChangesEmitsWhenSimulateSpaceChangeCalled() {
        let newSpaces: [SpaceInfo] = [
            SpaceInfo(uuid: "C", displayID: 1, isActive: true),
        ]
        var received: [[SpaceInfo]] = []
        tracker.spaceChanges
            .sink { received.append($0) }
            .store(in: &cancellables)
        tracker.simulateSpaceChange(spaces: newSpaces)
        XCTAssertEqual(received, [newSpaces])
    }

    func testSpaceChangesEmitsWhenSpaceAdded() {
        let initial: [SpaceInfo] = [SpaceInfo(uuid: "A", displayID: 1, isActive: true)]
        let updated: [SpaceInfo] = [
            SpaceInfo(uuid: "A", displayID: 1, isActive: true),
            SpaceInfo(uuid: "B", displayID: 1, isActive: false),
        ]
        var received: [[SpaceInfo]] = []
        tracker.spaceChanges
            .sink { received.append($0) }
            .store(in: &cancellables)
        tracker.simulateSpaceChange(spaces: initial)
        tracker.simulateSpaceChange(spaces: updated)
        XCTAssertEqual(received.last, updated)
        XCTAssertEqual(received.count, 2)
    }

    func testSpaceChangesEmitsWhenSpaceRemoved() {
        let initial: [SpaceInfo] = [
            SpaceInfo(uuid: "A", displayID: 1, isActive: true),
            SpaceInfo(uuid: "B", displayID: 1, isActive: false),
        ]
        let afterRemoval: [SpaceInfo] = [SpaceInfo(uuid: "A", displayID: 1, isActive: true)]
        var received: [[SpaceInfo]] = []
        tracker.spaceChanges
            .sink { received.append($0) }
            .store(in: &cancellables)
        tracker.simulateSpaceChange(spaces: initial)
        tracker.simulateSpaceChange(spaces: afterRemoval)
        XCTAssertEqual(received.last, afterRemoval)
        XCTAssertEqual(received.count, 2)
    }

    func testCGSSpaceTrackerConformsToProtocol() {
        let cgsTracker: SpaceTrackerProtocol = CGSSpaceTracker()
        XCTAssertNotNil(cgsTracker)
    }

    func testSpacesForDisplayReturnsSeededSpaces() {
        let spaces: [SpaceInfo] = [
            SpaceInfo(uuid: "A", displayID: 1, isActive: true),
            SpaceInfo(uuid: "B", displayID: 1, isActive: false),
        ]
        tracker.stubbedSpaces[1] = spaces
        XCTAssertEqual(tracker.spaces(for: 1), spaces)
    }
}
