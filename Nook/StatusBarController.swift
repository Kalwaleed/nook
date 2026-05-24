import AppKit
import Combine
import NookKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let store: SpaceStore
    private let tracker: any SpaceTrackerProtocol
    private let onShowSettings: () -> Void
    private var cancellables: Set<AnyCancellable> = []

    private var nameItem: NSMenuItem!

    init(store: SpaceStore, tracker: any SpaceTrackerProtocol, onShowSettings: @escaping () -> Void) {
        self.store = store
        self.tracker = tracker
        self.onShowSettings = onShowSettings

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Nook"

        buildMenu()

        Task { @MainActor in await self.refresh(spaces: tracker.allSpaces()) }

        tracker.spaceChanges
            .sink { [weak self] spaces in
                Task { @MainActor [weak self] in await self?.refresh(spaces: spaces) }
            }
            .store(in: &cancellables)
    }

    private func buildMenu() {
        let menu = NSMenu()

        nameItem = NSMenuItem(title: "—", action: nil, keyEquivalent: "")
        nameItem.isEnabled = false
        menu.addItem(nameItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit Nook", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @MainActor
    private func refresh(spaces: [SpaceInfo]) async {
        let mainDisplayID = UInt32(0)
        let forDisplay = spaces.filter { $0.displayID == mainDisplayID }
        guard let active = forDisplay.first(where: { $0.isActive }) else { return }

        let pairs: [(uuid: String, name: String?)] = await withTaskGroup(of: (String, String?).self) { group in
            for s in forDisplay {
                group.addTask { (s.uuid, await self.store.name(for: s.uuid)) }
            }
            var result: [(String, String?)] = []
            for await pair in group { result.append(pair) }
            return result.sorted { a, b in
                (forDisplay.firstIndex(where: { $0.uuid == a.0 }) ?? 0) <
                (forDisplay.firstIndex(where: { $0.uuid == b.0 }) ?? 0)
            }
        }

        let name = indexedDisplayName(for: active.uuid, in: pairs)
        statusItem.button?.title = name
        nameItem.title = name
    }

    @objc private func openSettings() {
        onShowSettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
