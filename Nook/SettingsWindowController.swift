import AppKit
import NookKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init(store: SpaceStore, tracker: any SpaceTrackerProtocol, loginItemManager: LoginItemManager) {
        let viewModel = SettingsViewModel(store: store, tracker: tracker, loginItemManager: loginItemManager)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let rootView = SettingsView(viewModel: viewModel) { [weak window] in window?.close() }
        window.contentViewController = NSHostingController(rootView: rootView)
        window.title = "Nook Settings"
        window.center()
        self.init(window: window)
    }
}
