import AppKit
import Combine
import NookKit

final class NookBarController {
    private let store: SpaceStore
    private let tracker: any SpaceTrackerProtocol
    private let renameController: RenameController
    private var bars: [NSScreen: NSWindowController] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init(store: SpaceStore, tracker: any SpaceTrackerProtocol, renameController: RenameController) {
        self.store = store
        self.tracker = tracker
        self.renameController = renameController

        syncBars(to: NSScreen.screens)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.syncBars(to: NSScreen.screens) }
            .store(in: &cancellables)
    }

    private func syncBars(to screens: [NSScreen]) {
        let current = Set(bars.keys)
        let incoming = Set(screens)

        for removed in current.subtracting(incoming) {
            bars[removed]?.close()
            bars.removeValue(forKey: removed)
        }
        for added in incoming.subtracting(current) {
            let wc = makeBar(for: added)
            bars[added] = wc
            wc.showWindow(nil)
        }
    }

    private func makeBar(for screen: NSScreen) -> NSWindowController {
        let isNotch = screen.safeAreaInsets.top > 0
        if isNotch {
            return NotchBar(screen: screen, store: store, tracker: tracker, renameController: renameController)
        } else {
            return PillBar(screen: screen, store: store, tracker: tracker, renameController: renameController)
        }
    }
}
