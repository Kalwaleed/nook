import AppKit
import NookKit

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let spaceStore = SpaceStore(defaults: UserDefaults(suiteName: "com.kalwaleed.nook")!)
    private let spaceTracker = CGSSpaceTracker()
    private let loginItemManager = LoginItemManager()
    private let accessibilityManager = AccessibilityPermissionManager()
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        accessibilityManager.checkAndRequestIfNeeded()
    }

    @objc func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                store: spaceStore,
                tracker: spaceTracker,
                loginItemManager: loginItemManager
            )
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
