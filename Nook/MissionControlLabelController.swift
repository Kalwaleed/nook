import ApplicationServices
import AppKit
import Combine
import NookKit

final class MissionControlLabelController {
    private let detector: MissionControlDetector
    private let store: SpaceStore
    private let tracker: any SpaceTrackerProtocol
    private let renameController: RenameController

    // One overlay window per CGDirectDisplayID
    private var overlays: [UInt32: MCOverlayWindowController] = [:]
    private var cancellables: Set<AnyCancellable> = []
    // Cached on each MC open so per-snapshot updates stay synchronous (10 Hz).
    private var mappings: [String: String] = [:]

    init(store: SpaceStore, tracker: any SpaceTrackerProtocol, renameController: RenameController) {
        self.store = store
        self.tracker = tracker
        self.renameController = renameController
        self.detector = MissionControlDetector(tracker: tracker)

        refreshMappings()  // warm cache so labels show custom names on first frame

        detector.snapshots
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                if let snapshot {
                    if self.overlays.isEmpty { self.refreshMappings() }
                    self.apply(snapshot: snapshot)
                } else {
                    self.hideLabels()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Snapshot handling

    private func refreshMappings() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.mappings = await self.store.allMappings()
            // Redraw with fresh names if MC is open and stuck on a deduped snapshot.
            if let current = self.detector.currentSnapshot, !self.overlays.isEmpty {
                self.apply(snapshot: current)
            }
        }
    }

    private func apply(snapshot: MCSnapshot) {
        for (idx, entry) in snapshot.displays.enumerated() {
            guard let scr = screen(forDisplayID: entry.displayID, fallbackIndex: idx) else { continue }
            let specs = labelSpecs(for: entry, displayIndex: idx)

            if let existing = overlays[entry.displayID] {
                existing.update(labels: specs, screen: scr, stage: entry.stage)
            } else {
                let wc = MCOverlayWindowController(screen: scr, labels: specs, stage: entry.stage) { [weak self] uuid, rect, window in
                    self?.renameController.present(for: uuid, over: rect, in: window)
                }
                overlays[entry.displayID] = wc
                wc.showWindow(nil)
            }
        }
    }

    private func labelSpecs(for entry: MCSnapshot.DisplayEntry, displayIndex: Int) -> [LabelSpec] {
        let displaySpaces = tracker.spaces(for: UInt32(displayIndex))
        return entry.thumbnails.enumerated().map { i, thumb in
            let uuid = i < displaySpaces.count ? displaySpaces[i].uuid : nil
            let text = uuid.flatMap { mappings[$0] } ?? thumb.axTitle
            return LabelSpec(uuid: uuid, text: text, axFrame: thumb.frame, axLabelFrame: thumb.labelFrame)
        }
    }

    private func hideLabels() {
        overlays.values.forEach { $0.close() }
        overlays.removeAll()
        mappings = [:]
    }
}

// MARK: - LabelSpec

fileprivate struct LabelSpec {
    let uuid: String?
    let text: String
    let axFrame: CGRect  // Quartz/AX coords: y=0 at top of display, increases down
    let axLabelFrame: CGRect?  // exact frame of macOS's native text label, when AX exposes it
}

// MARK: - MCOverlayWindowController

// One borderless, transparent, full-screen window per display.
// Labels appear over each Space thumbnail; the rest of the window is click-through.
// Reused across snapshots: `update(labels:screen:)` repositions/retitles existing views
// rather than tearing down NSVisualEffectView instances 10× a second.
fileprivate final class MCOverlayWindowController: NSWindowController {
    typealias RenameCallback = (_ uuid: String, _ labelRect: NSRect, _ window: NSWindow) -> Void

    private let contentLayer: MCOverlayContentView
    private var labelViews: [SpaceLabelView] = []
    private let onRename: RenameCallback

    init(screen: NSScreen, labels: [LabelSpec], stage: MCSnapshot.Stage, onRename: @escaping RenameCallback) {
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        win.level            = .screenSaver
        win.isOpaque         = false
        win.backgroundColor  = .clear
        win.ignoresMouseEvents = false  // custom hitTest in content view gates this
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        self.contentLayer = MCOverlayContentView(frame: screen.frame)
        win.contentView = contentLayer
        self.onRename = onRename
        super.init(window: win)

        update(labels: labels, screen: screen, stage: stage)
    }

    required init?(coder: NSCoder) { nil }

    func update(labels: [LabelSpec], screen: NSScreen, stage: MCSnapshot.Stage) {
        contentLayer.hitTestRects.removeAll(keepingCapacity: true)

        // Reuse views when count matches (the common case for stage 1 ↔ stage 2 transitions).
        if labelViews.count != labels.count {
            labelViews.forEach { $0.removeFromSuperview() }
            labelViews = labels.map { _ in
                let v = SpaceLabelView()
                contentLayer.addSubview(v)
                return v
            }
        }

        for (i, spec) in labels.enumerated() {
            let view = labelViews[i]
            let frame: NSRect
            if let labelAX = spec.axLabelFrame {
                // Overlay sits exactly where macOS draws its native label. Pad a couple of
                // points to fully cover the rendered text and its descender/baseline.
                let r = axToWindow(labelAX, screenHeight: screen.frame.height)
                frame = r.insetBy(dx: -4, dy: -2)
            } else {
                let localRect = axToWindow(spec.axFrame, screenHeight: screen.frame.height)
                frame = labelRect(for: localRect, stage: stage, screen: screen)
            }
            view.frame = frame
            view.setText(spec.text)
            view.onContextClick = { [weak self, weak view] in
                guard let self, let view, let uuid = spec.uuid, let win = self.window else { return }
                self.onRename(uuid, view.frame, win)
            }
            contentLayer.hitTestRects.append(frame)
        }
    }
}

// Converts an AX display-local Quartz rect (y=0 top) to an AppKit window-local rect (y=0 bottom).
// The overlay window frame equals screen.frame, so x needs no offset for the primary screen;
// for secondary screens the AX coordinates are also display-local so x starts at 0.
private func axToWindow(_ axRect: CGRect, screenHeight: CGFloat) -> CGRect {
    CGRect(x: axRect.minX, y: screenHeight - axRect.maxY, width: axRect.width, height: axRect.height)
}

// In stage 2 (expanded thumbnails) the AX button frame is in display-local screen
// coords and we can position the label flush under it. In stage 1 (the trackpad-swipe
// strip) AX reports button frames in a coord space that's offset above the visible
// display — converting via screenHeight puts the label off-screen. Pin those to the
// menubar-relative position macOS actually renders the native "Desktop N" labels at.
private func labelRect(for thumbnailWindow: CGRect, stage: MCSnapshot.Stage, screen: NSScreen) -> CGRect {
    let h: CGFloat = 22
    if stage == .strip {
        let menubarH = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
        let w: CGFloat = max(thumbnailWindow.width, 60)
        let x = thumbnailWindow.midX - w / 2
        let y = screen.frame.height - menubarH - h - 8
        return CGRect(x: x, y: y, width: w, height: h)
    }
    let w: CGFloat = thumbnailWindow.width
    let x = thumbnailWindow.midX - w / 2
    let y = thumbnailWindow.minY - h - 6
    return CGRect(x: x, y: y, width: w, height: h)
}

// MARK: - MCOverlayContentView

// Transparent full-screen view. Only regions listed in hitTestRects receive mouse events;
// all other areas pass clicks through to Mission Control beneath.
fileprivate final class MCOverlayContentView: NSView {
    var hitTestRects: [CGRect] = []

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard hitTestRects.contains(where: { $0.contains(point) }) else { return nil }
        return super.hitTest(point)
    }

    override var mouseDownCanMoveWindow: Bool { false }
}

// MARK: - SpaceLabelView

fileprivate final class SpaceLabelView: NSView {
    var onContextClick: (() -> Void)?
    private let textField = NSTextField(labelWithString: "")
    private let backdrop = NSVisualEffectView()

    init() {
        super.init(frame: .zero)

        // Blurred backdrop hides the native macOS "Desktop N" label underneath
        // (which is part of the Mission Control window, behind our overlay).
        backdrop.material = .hudWindow
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = 6
        backdrop.layer?.masksToBounds = true
        backdrop.autoresizingMask = [.width, .height]
        addSubview(backdrop)

        textField.font          = .systemFont(ofSize: 12, weight: .medium)
        textField.textColor     = .white
        textField.drawsBackground = false
        textField.isBezeled     = false
        textField.isEditable    = false
        textField.isSelectable  = false
        textField.alignment     = .center
        textField.lineBreakMode = .byTruncatingTail
        textField.autoresizingMask = [.width, .height]
        addSubview(textField)
    }

    required init?(coder: NSCoder) { nil }

    override var frame: NSRect {
        didSet {
            backdrop.frame = bounds
            textField.frame = bounds
        }
    }

    func setText(_ s: String) { textField.stringValue = s }

    override func rightMouseDown(with event: NSEvent) { onContextClick?() }

    override func mouseDown(with event: NSEvent) {
        // Ctrl-click is the macOS-standard equivalent of a right-click.
        if event.modifierFlags.contains(.control) { onContextClick?() }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
