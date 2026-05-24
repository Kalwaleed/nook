import AppKit
import NookKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var spaceStore = SpaceStore(defaults: UserDefaults(suiteName: "com.kalwaleed.nook") ?? .standard)
    private lazy var spaceTracker = CGSSpaceTracker()
    private lazy var loginItemManager = LoginItemManager()
    private lazy var accessibilityManager = AccessibilityPermissionManager()
    private var statusBarController: StatusBarController?
    private var missionControlLabelController: MissionControlLabelController?
    private var notchManager: NotchManager?
    private var settingsWindowController: SettingsWindowController?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        accessibilityManager.checkAndRequestIfNeeded()
        statusBarController = StatusBarController(
            store: spaceStore,
            tracker: spaceTracker,
            onShowSettings: { [weak self] in self?.showSettings() }
        )
        missionControlLabelController = MissionControlLabelController(
            store: spaceStore,
            tracker: spaceTracker,
            renameController: RenameController(store: spaceStore)
        )
        notchManager = NotchManager(store: spaceStore, tracker: spaceTracker)
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
