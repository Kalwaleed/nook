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

    init(store: SpaceStore, tracker: any SpaceTrackerProtocol, renameController: RenameController) {
        self.store = store
        self.tracker = tracker
        self.renameController = renameController
        self.detector = MissionControlDetector()

        detector.activations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                if active { self?.showLabels() } else { self?.hideLabels() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Show / hide

    private func showLabels() {
        hideLabels()
        let displayData = detector.displaysWithThumbnails()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let mappings = await self.store.allMappings()
            // MC may have closed while we awaited; bail out if so.
            guard self.detector.isActive else { return }

            for (idx, (axDisplayID, thumbnails)) in displayData.enumerated() {
                guard let screen = screen(forDisplayID: axDisplayID, fallbackIndex: idx) else { continue }

                let specs = thumbnails.enumerated().map { i, thumb -> LabelSpec in
                    let uuid = i < self.tracker.spaces(for: UInt32(idx)).count
                        ? self.tracker.spaces(for: UInt32(idx))[i].uuid : nil
                    let text = uuid.flatMap { mappings[$0] } ?? thumb.axTitle
                    return LabelSpec(uuid: uuid, text: text, axFrame: thumb.frame)
                }

                let wc = MCOverlayWindowController(screen: screen, labels: specs) { [weak self] uuid, rect, window in
                    self?.renameController.present(for: uuid, over: rect, in: window)
                }
                self.overlays[axDisplayID] = wc
                wc.showWindow(nil)
            }
        }
    }

    private func hideLabels() {
        overlays.values.forEach { $0.close() }
        overlays.removeAll()
    }
}

// MARK: - Screen lookup

// AXDisplayID may not equal CGDirectDisplayID, so fall back to positional match.
private func screen(forDisplayID id: UInt32, fallbackIndex idx: Int) -> NSScreen? {
    if let match = NSScreen.screens.first(where: {
        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) == id
    }) { return match }
    return idx < NSScreen.screens.count ? NSScreen.screens[idx] : nil
}

// MARK: - LabelSpec

private struct LabelSpec {
    let uuid: String?
    let text: String
    let axFrame: CGRect  // Quartz/AX coords: y=0 at top of display, increases down
}

// MARK: - MCOverlayWindowController

// One borderless, transparent, full-screen window per display.
// Labels appear over each Space thumbnail; the rest of the window is click-through.
private final class MCOverlayWindowController: NSWindowController {
    typealias RenameCallback = (_ uuid: String, _ labelRect: NSRect, _ window: NSWindow) -> Void

    init(screen: NSScreen, labels: [LabelSpec], onRename: @escaping RenameCallback) {
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

        let contentView = MCOverlayContentView(frame: screen.frame)
        win.contentView = contentView

        super.init(window: win)

        for (_, spec) in labels.enumerated() {
            let localRect = axToWindow(spec.axFrame, screenHeight: screen.frame.height)
            let labelView = SpaceLabelView(text: spec.text, frame: labelRect(for: localRect))

            labelView.onDoubleClick = { [weak win] in
                guard let win, let uuid = spec.uuid else { return }
                onRename(uuid, labelView.frame, win)
            }
            contentView.addSubview(labelView)
            contentView.hitTestRects.append(labelView.frame)
        }
    }

    required init?(coder: NSCoder) { nil }
}

// Converts an AX display-local Quartz rect (y=0 top) to an AppKit window-local rect (y=0 bottom).
// The overlay window frame equals screen.frame, so x needs no offset for the primary screen;
// for secondary screens the AX coordinates are also display-local so x starts at 0.
private func axToWindow(_ axRect: CGRect, screenHeight: CGFloat) -> CGRect {
    CGRect(x: axRect.minX, y: screenHeight - axRect.maxY, width: axRect.width, height: axRect.height)
}

// Label is 120 × 18 pt, centered horizontally on the thumbnail, 6 pt from the top edge.
private func labelRect(for thumbnailWindow: CGRect) -> CGRect {
    let w: CGFloat = min(120, thumbnailWindow.width)
    let h: CGFloat = 18
    let x = thumbnailWindow.midX - w / 2
    let y = thumbnailWindow.maxY - h - 6   // 6 pt from the top edge of the thumbnail (AppKit: maxY = top)
    return CGRect(x: x, y: y, width: w, height: h)
}

// MARK: - MCOverlayContentView

// Transparent full-screen view. Only regions listed in hitTestRects receive mouse events;
// all other areas pass clicks through to Mission Control beneath.
private final class MCOverlayContentView: NSView {
    var hitTestRects: [CGRect] = []

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard hitTestRects.contains(where: { $0.contains(point) }) else { return nil }
        return super.hitTest(point)
    }

    override var mouseDownCanMoveWindow: Bool { false }
}

// MARK: - SpaceLabelView

private final class SpaceLabelView: NSView {
    var onDoubleClick: (() -> Void)?

    init(text: String, frame: CGRect) {
        super.init(frame: frame)

        let tf = NSTextField(labelWithString: text)
        tf.font          = .systemFont(ofSize: 12, weight: .medium)
        tf.textColor     = .white
        tf.drawsBackground = false
        tf.isBezeled     = false
        tf.isEditable    = false
        tf.isSelectable  = false
        tf.alignment     = .center
        tf.lineBreakMode = .byTruncatingTail
        tf.frame         = bounds

        let shadow = NSShadow()
        shadow.shadowColor      = NSColor.black.withAlphaComponent(0.75)
        shadow.shadowOffset     = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 2
        tf.shadow = shadow

        addSubview(tf)
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onDoubleClick?() }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
