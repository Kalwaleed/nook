import XCTest
@testable import NookKit

final class MockSpaceStore: SpaceStoreProtocol {
    var names: [String: String] = [:]
    func setName(_ name: String, for uuid: String) async { names[uuid] = name }
    func name(for uuid: String) async -> String? { names[uuid] }
    func deleteName(for uuid: String) async { names.removeValue(forKey: uuid) }
}

final class RenameControllerTests: XCTestCase {
    func testCancelDoesNotWriteToStore() async {
        let store = MockSpaceStore()
        let controller = RenameController(store: store)
        controller.cancel()
        XCTAssertTrue(store.names.isEmpty)
    }

    func testCommitNonEmptyNameWritesToStore() async {
        let store = MockSpaceStore()
        let controller = RenameController(store: store)
        await controller.commit(name: "Coding", for: "uuid-1")
        XCTAssertEqual(store.names["uuid-1"], "Coding")
    }

    func testCommitEmptyNameDeletesExistingName() async {
        let store = MockSpaceStore()
        store.names["uuid-1"] = "Coding"
        let controller = RenameController(store: store)
        await controller.commit(name: "", for: "uuid-1")
        XCTAssertNil(store.names["uuid-1"])
    }
}
