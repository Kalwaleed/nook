import Combine
import Foundation
import NookKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var spaceNames: [(uuid: String, name: String)] = []

    private let store: SpaceStore
    let loginItemManager: LoginItemManager
    private var cancellables: Set<AnyCancellable> = []

    init(store: SpaceStore, tracker: any SpaceTrackerProtocol, loginItemManager: LoginItemManager) {
        self.store = store
        self.loginItemManager = loginItemManager

        Task { @MainActor in await self.refresh(spaces: tracker.allSpaces()) }

        tracker.spaceChanges
            .sink { [weak self] spaces in
                Task { @MainActor [weak self] in await self?.refresh(spaces: spaces) }
            }
            .store(in: &cancellables)
    }

    func refresh(spaces: [SpaceInfo]) async {
        var result: [(uuid: String, name: String)] = []
        for space in spaces {
            let name = await store.name(for: space.uuid) ?? ""
            result.append((uuid: space.uuid, name: name))
        }
        spaceNames = result
    }

    func setName(_ name: String, for uuid: String) {
        if let idx = spaceNames.firstIndex(where: { $0.uuid == uuid }) {
            spaceNames[idx] = (uuid: uuid, name: name)
        }
        Task {
            if name.isEmpty {
                await store.deleteName(for: uuid)
            } else {
                await store.setName(name, for: uuid)
            }
        }
    }
}
