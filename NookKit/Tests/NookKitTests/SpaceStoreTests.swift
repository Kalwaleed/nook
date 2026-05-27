import XCTest
@testable import NookKit

final class SpaceStoreTests: XCTestCase {
    private let suiteName = "com.kalwaleed.nook.tests.SpaceStore"
    private var defaults: UserDefaults!
    private var store: SpaceStore!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        store = SpaceStore(defaults: defaults)
    }

    func testNameForUnknownUUIDReturnsNil() async {
        let result = await store.name(for: "unknown-uuid")
        XCTAssertNil(result)
    }

    func testSetNameThenNameReturnsStoredValue() async {
        await store.setName("Home", for: "uuid-1")
        let result = await store.name(for: "uuid-1")
        XCTAssertEqual(result, "Home")
    }

    func testSetNameOverwritesPreviousValue() async {
        await store.setName("Home", for: "uuid-1")
        await store.setName("Work", for: "uuid-1")
        let result = await store.name(for: "uuid-1")
        XCTAssertEqual(result, "Work")
    }

    func testDeleteNameRemovesEntry() async {
        await store.setName("Home", for: "uuid-1")
        await store.deleteName(for: "uuid-1")
        let result = await store.name(for: "uuid-1")
        XCTAssertNil(result)
    }

    func testAllMappingsReturnsAllStoredPairs() async {
        let empty = await store.allMappings()
        XCTAssertTrue(empty.isEmpty)

        await store.setName("Home", for: "uuid-1")
        await store.setName("Work", for: "uuid-2")
        let mappings = await store.allMappings()
        XCTAssertEqual(mappings, ["uuid-1": "Home", "uuid-2": "Work"])
    }

    func testPersistenceRoundTrip() async {
        await store.setName("Studio", for: "uuid-persist")
        let newStore = SpaceStore(defaults: defaults)
        let result = await newStore.name(for: "uuid-persist")
        XCTAssertEqual(result, "Studio")
    }

    func testEmptyStringNameStoresAndRetrievesWithoutCorruption() async {
        await store.setName("Home", for: "uuid-1")
        await store.setName("", for: "uuid-2")
        let emptyName = await store.name(for: "uuid-2")
        let otherName = await store.name(for: "uuid-1")
        let all = await store.allMappings()
        XCTAssertEqual(emptyName, "")
        XCTAssertEqual(otherName, "Home")
        XCTAssertEqual(all, ["uuid-1": "Home", "uuid-2": ""])
    }
}
