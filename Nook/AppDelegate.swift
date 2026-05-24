import AppKit

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityManager = AccessibilityPermissionManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        accessibilityManager.checkAndRequestIfNeeded()
    }
}
