import AppKit
import NookKit
import SwiftUI

final class PillBar: NSWindowController {
    private let model: BarModel

    init(screen: NSScreen, store: SpaceStore, tracker: any SpaceTrackerProtocol, renameController: RenameController) {
        let model = BarModel(displayID: UInt32(NSScreen.screens.firstIndex(of: screen) ?? 0),
                             store: store, tracker: tracker)
        self.model = model

        let size = CGSize(width: 160, height: 28)
        let origin = CGPoint(x: screen.frame.midX - size.width / 2,
                             y: screen.frame.maxY - size.height - 8)

        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true

        let hosting = NSHostingController(rootView: BarContentView(model: model))
        hosting.view.frame = NSRect(origin: .zero, size: size)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = .clear

        effect.addSubview(hosting.view)
        window.contentView = effect
        window.addChildWindow(hosting.view.window ?? window, ordered: .above)

        super.init(window: window)

        model.onTap = { [weak self] in self?.handleTap(renameController: renameController) }
    }

    required init?(coder: NSCoder) { nil }

    private func handleTap(renameController: RenameController) {
        guard let window else { return }
        renameController.present(for: currentActiveUUID(), over: window.frame, in: window)
    }

    private func currentActiveUUID() -> String {
        model.displayName
    }
}
