import AppKit
import ApplicationServices

final class AccessibilityPermissionManager {
    private var pollingTimer: Timer?
    private var welcomeWindow: NSWindow?

    var isGranted: Bool { AXIsProcessTrusted() }

    func checkAndRequestIfNeeded() {
        guard !isGranted else { return }
        showWelcomeWindow()
        startPolling()
    }

    private func showWelcomeWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Nook"
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))

        let label = NSTextField(wrappingLabelWithString: "Nook needs Accessibility access to display Space names in Mission Control.")
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let button = NSButton(title: "Grant Accessibility Access", target: self, action: #selector(openAccessibilitySettings))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.keyEquivalent = "\r"
        button.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(label)
        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            button.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])

        window.contentView = contentView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        welcomeWindow = window
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.isGranted {
                self.pollingTimer?.invalidate()
                self.pollingTimer = nil
                self.welcomeWindow?.close()
                self.welcomeWindow = nil
            }
        }
    }
}
