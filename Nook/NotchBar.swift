import AppKit
import NookKit
import SwiftUI

final class NotchBar: NSWindowController {
    private let model: BarModel

    init(screen: NSScreen, store: SpaceStore, tracker: any SpaceTrackerProtocol, renameController: RenameController) {
        let model = BarModel(displayID: UInt32(NSScreen.screens.firstIndex(of: screen) ?? 0),
                             store: store, tracker: tracker)
        self.model = model

        let width: CGFloat = 200
        let height: CGFloat = screen.safeAreaInsets.top
        let origin = CGPoint(x: screen.frame.midX - width / 2,
                             y: screen.frame.maxY - height)

        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: CGSize(width: width, height: height)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let hosting = NSHostingController(rootView: BarContentView(model: model))
        window.contentViewController = hosting

        super.init(window: window)

        model.onTap = { [weak self] in self?.handleTap(renameController: renameController) }
    }

    required init?(coder: NSCoder) { nil }

    private func handleTap(renameController: RenameController) {
        guard let window, let active = window.screen else { return }
        let frame = window.frame
        renameController.present(for: currentActiveUUID(), over: frame, in: window)
        _ = active
    }

    private func currentActiveUUID() -> String {
        model.displayName
    }
}
