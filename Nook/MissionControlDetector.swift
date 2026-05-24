import ApplicationServices
import AppKit
import Combine

struct SpaceThumbnail {
    let axTitle: String  // "Desktop N" from AX
    let frame: CGRect    // display-local Quartz coords: origin top-left, y increases down
}

// Polls the Dock AX tree at 100 ms intervals to detect when Mission Control opens/closes.
// Publishes true on open, false on close. Also provides thumbnail geometry for overlays.
final class MissionControlDetector {
    private let activationSubject = PassthroughSubject<Bool, Never>()
    var activations: AnyPublisher<Bool, Never> { activationSubject.eraseToAnyPublisher() }
    private(set) var isActive = false

    private var pollTimer: DispatchSourceTimer?
    private let dockApp: AXUIElement

    init() {
        if let dock = NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == "com.apple.dock" }) {
            dockApp = AXUIElementCreateApplication(dock.processIdentifier)
            startPolling()
        } else {
            dockApp = AXUIElementCreateApplication(0)
        }
    }

    deinit { pollTimer?.cancel() }

    // MARK: - Polling

    private func startPolling() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(200), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in self?.poll() }
        timer.resume()
        pollTimer = timer
    }

    private func poll() {
        let active = mcGroupElement() != nil
        guard active != isActive else { return }
        isActive = active
        activationSubject.send(active)
    }

    // MARK: - AX queries

    // Returns (CGDirectDisplayID, thumbnails) for each display in the Mission Control tree.
    // Order matches CGSCopyManagedDisplaySpaces order so callers can index into SpaceTracker.
    func displaysWithThumbnails() -> [(displayID: UInt32, thumbnails: [SpaceThumbnail])] {
        guard let mc = mcGroupElement() else { return [] }
        return axChildren(mc)
            .filter { axString($0, "AXIdentifier") == "mc.display" }
            .compactMap { node -> (UInt32, [SpaceThumbnail])? in
                let id = (axRawValue(node, "AXDisplayID") as? NSNumber)?.uint32Value ?? 0
                let thumbs = thumbnails(underDisplayNode: node)
                return (id, thumbs)
            }
    }

    // MARK: - Private

    private func mcGroupElement() -> AXUIElement? {
        axChildren(dockApp).first { axString($0, "AXIdentifier") == "mc" }
    }

    private func thumbnails(underDisplayNode display: AXUIElement) -> [SpaceThumbnail] {
        guard
            let spacesGroup = axChildren(display).first(where: { axString($0, "AXIdentifier") == "mc.spaces" }),
            let spacesList  = axChildren(spacesGroup).first(where: { axString($0, "AXIdentifier") == "mc.spaces.list" })
        else { return [] }

        return axChildren(spacesList).compactMap { button -> SpaceThumbnail? in
            guard axString(button, "AXRole") == "AXButton",
                  axString(button, "AXIdentifier") == nil,  // excludes mc.spaces.add
                  let title = axString(button, "AXTitle"),
                  let frame = axFrameValue(button) else { return nil }
            return SpaceThumbnail(axTitle: title, frame: frame)
        }
    }
}

// MARK: - AX helpers (file-private)

private func axChildren(_ element: AXUIElement) -> [AXUIElement] {
    var v: AnyObject?
    guard AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &v) == .success,
          let kids = v as? [AXUIElement] else { return [] }
    return kids
}

private func axString(_ element: AXUIElement, _ attr: String) -> String? {
    var v: AnyObject?
    guard AXUIElementCopyAttributeValue(element, attr as CFString, &v) == .success else { return nil }
    return v as? String
}

private func axRawValue(_ element: AXUIElement, _ attr: String) -> AnyObject? {
    var v: AnyObject?
    guard AXUIElementCopyAttributeValue(element, attr as CFString, &v) == .success else { return nil }
    return v
}

private func axFrameValue(_ element: AXUIElement) -> CGRect? {
    guard let v = axRawValue(element, "AXFrame"),
          CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
    var rect = CGRect.zero
    AXValueGetValue(v as! AXValue, .cgRect, &rect)
    return rect
}
