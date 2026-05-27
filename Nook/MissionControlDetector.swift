import ApplicationServices
import AppKit
import Combine
import NookKit

struct SpaceThumbnail {
    let axTitle: String  // "Desktop N" from AX
    let frame: CGRect    // display-local Quartz coords: origin top-left, y increases down
    let labelFrame: CGRect?  // if AX exposes the on-screen text label as a sub-element
}

struct MCSnapshot {
    enum Stage { case strip, expanded, unknown }
    struct DisplayEntry {
        let displayID: UInt32
        let thumbnails: [SpaceThumbnail]
        let stage: Stage
        let synthesized: Bool  // true when frames came from strip-layout fallback, not AX
    }
    let displays: [DisplayEntry]
}

// Polls the Dock AX tree at 100 ms intervals to track Mission Control's layout.
// Publishes a continuous stream of snapshots while MC is open (nil when closed) so the
// overlay can follow the stage-1 strip → stage-2 expanded transition of the three-finger gesture.
final class MissionControlDetector {
    private let snapshotSubject = CurrentValueSubject<MCSnapshot?, Never>(nil)
    var snapshots: AnyPublisher<MCSnapshot?, Never> { snapshotSubject.eraseToAnyPublisher() }
    var currentSnapshot: MCSnapshot? { snapshotSubject.value }
    var isActive: Bool { snapshotSubject.value != nil }

    private var pollTimer: DispatchSourceTimer?
    private let dockApp: AXUIElement
    private let tracker: any SpaceTrackerProtocol
    private var lastEmittedHash: Int = 0

    init(tracker: any SpaceTrackerProtocol) {
        self.tracker = tracker
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
        guard let mc = mcGroupElement() else {
            if snapshotSubject.value != nil {
                snapshotSubject.send(nil)
                lastEmittedHash = 0
            }
            return
        }

        let snapshot = buildSnapshot(mc: mc)
        let h = hash(of: snapshot)
        guard h != lastEmittedHash else { return }
        lastEmittedHash = h

        if ProcessInfo.processInfo.environment["NOOK_AX_DUMP"] != nil {
            let stages = snapshot.displays.map { "\($0.stage)" }.joined(separator: ",")
            dumpAXTree(mc, depth: 0, label: "[NOOK_AX_DUMP stage=\(stages)]")
        }

        snapshotSubject.send(snapshot)
    }

    // MARK: - Snapshot building

    private func buildSnapshot(mc: AXUIElement) -> MCSnapshot {
        let displayNodes = axChildren(mc).filter { axString($0, "AXIdentifier") == "mc.display" }
        let entries: [MCSnapshot.DisplayEntry] = displayNodes.enumerated().map { idx, node in
            let displayID = (axRawValue(node, "AXDisplayID") as? NSNumber)?.uint32Value ?? 0
            let thumbs = thumbnails(underDisplayNode: node)
            if !thumbs.isEmpty {
                let stage = classifyStage(thumbs: thumbs, screen: screen(forDisplayID: displayID, fallbackIndex: idx))
                return .init(displayID: displayID, thumbnails: thumbs, stage: stage, synthesized: false)
            }
            // Stage 1 fallback: AX tree has no usable thumbnails yet — synthesize a top strip.
            let synth = synthesizeStrip(displayIndex: UInt32(idx),
                                        screen: screen(forDisplayID: displayID, fallbackIndex: idx))
            return .init(displayID: displayID, thumbnails: synth, stage: .strip, synthesized: true)
        }
        return MCSnapshot(displays: entries)
    }

    private func classifyStage(thumbs: [SpaceThumbnail], screen: NSScreen?) -> MCSnapshot.Stage {
        guard let first = thumbs.first else { return .unknown }
        // Stage 1's strip lives in the menubar coord space (negative AX y, h≈24).
        // Stage 2's expanded tiles use standard display coords (positive y, h≈90+).
        // Sign of y is the reliable discriminator; height ratios are too small to gate on.
        return first.frame.minY < 0 ? .strip : .expanded
    }

    private func synthesizeStrip(displayIndex: UInt32, screen: NSScreen?) -> [SpaceThumbnail] {
        let spaces = tracker.spaces(for: displayIndex)
        guard !spaces.isEmpty, let screen else { return [] }
        let n = CGFloat(spaces.count)
        let screenW = screen.frame.width
        let stripHeight: CGFloat = 90
        let topMargin: CGFloat = 28
        let gap: CGFloat = 8
        let totalGap = gap * (n - 1)
        let maxTileW: CGFloat = 180
        let tileW = min(maxTileW, (screenW * 0.7 - totalGap) / max(n, 1))
        let totalW = tileW * n + totalGap
        let startX = (screenW - totalW) / 2
        return (0..<spaces.count).map { i in
            let x = startX + CGFloat(i) * (tileW + gap)
            // AX/Quartz coords: y from top of display
            let rect = CGRect(x: x, y: topMargin, width: tileW, height: stripHeight)
            return SpaceThumbnail(axTitle: "Desktop \(i + 1)", frame: rect, labelFrame: nil)
        }
    }

    // Hash that ignores sub-pixel frame jitter by rounding to integral pixels.
    private func hash(of snapshot: MCSnapshot) -> Int {
        var hasher = Hasher()
        for d in snapshot.displays {
            hasher.combine(d.displayID)
            hasher.combine(d.synthesized)
            for t in d.thumbnails {
                hasher.combine(t.axTitle)
                let r = t.frame.integral
                hasher.combine(Int(r.minX))
                hasher.combine(Int(r.minY))
                hasher.combine(Int(r.width))
                hasher.combine(Int(r.height))
            }
        }
        return hasher.finalize()
    }

    // MARK: - AX queries

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
            let labelFrame = findLabelFrame(under: button, matching: title)
            return SpaceThumbnail(axTitle: title, frame: frame, labelFrame: labelFrame)
        }
    }

    // The strip and expanded layouts both expose the visible "Desktop N" text as a
    // descendant of the AXButton. Returns its frame so the overlay can sit directly on
    // top of it, regardless of the AX button frame's own boundaries.
    private func findLabelFrame(under button: AXUIElement, matching title: String) -> CGRect? {
        func walk(_ el: AXUIElement, depth: Int) -> CGRect? {
            if depth > 5 { return nil }
            for child in axChildren(el) {
                let role = axString(child, "AXRole")
                if role == "AXStaticText" || role == "AXText" {
                    if let frame = axFrameValue(child) {
                        return frame
                    }
                }
                if let hit = walk(child, depth: depth + 1) { return hit }
            }
            return nil
        }
        return walk(button, depth: 0)
    }

    // MARK: - Diagnostic

    private func dumpAXTree(_ element: AXUIElement, depth: Int, label: String) {
        let indent = String(repeating: "  ", count: depth)
        let role = axString(element, "AXRole") ?? "-"
        let id = axString(element, "AXIdentifier") ?? "-"
        let title = axString(element, "AXTitle") ?? "-"
        let frame = axFrameValue(element).map { "\($0)" } ?? "-"
        NSLog("%@%@ %@ | id=%@ | title=%@ | frame=%@", label, indent, role, id, title, frame)
        for child in axChildren(element) {
            dumpAXTree(child, depth: depth + 1, label: label)
        }
    }
}

// MARK: - Screen lookup (shared with controller)

func screen(forDisplayID id: UInt32, fallbackIndex idx: Int) -> NSScreen? {
    if let match = NSScreen.screens.first(where: {
        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) == id
    }) { return match }
    return idx < NSScreen.screens.count ? NSScreen.screens[idx] : nil
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
