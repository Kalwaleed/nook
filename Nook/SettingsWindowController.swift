import AppKit
import NookKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init(store: SpaceStore, tracker: any SpaceTrackerProtocol, loginItemManager: LoginItemManager) {
        let viewModel = SettingsViewModel(store: store, tracker: tracker, loginItemManager: loginItemManager)
        let rootView = SettingsView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Nook Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 400, height: 320))
        window.center()
        self.init(window: window)
    }
}
