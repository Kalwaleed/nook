import AppKit

public final class RenameController {
    private let store: any SpaceStoreProtocol
    private var coordinator: RenameCoordinator?

    public init(store: any SpaceStoreProtocol) {
        self.store = store
    }

    public func commit(name: String, for uuid: String) async {
        if name.isEmpty {
            await store.deleteName(for: uuid)
        } else {
            await store.setName(name, for: uuid)
        }
    }

    public func cancel() {}

    public func present(for uuid: String, over frame: NSRect, in window: NSWindow) {
        coordinator?.dismiss()

        let textField = NSTextField(frame: frame)
        textField.bezelStyle = .roundedBezel
        textField.alignment = .center
        textField.placeholderString = "Name"
        textField.font = .systemFont(ofSize: 12)

        let coord = RenameCoordinator(uuid: uuid, textField: textField, controller: self)
        textField.delegate = coord
        self.coordinator = coord

        Task { @MainActor [weak textField] in
            let existing = await store.name(for: uuid) ?? ""
            textField?.stringValue = existing
            textField?.selectText(nil)
        }

        window.contentView?.addSubview(textField)
        window.makeFirstResponder(textField)
    }

    fileprivate func release(_ c: RenameCoordinator) {
        if coordinator === c { coordinator = nil }
    }
}

private final class RenameCoordinator: NSObject, NSTextFieldDelegate {
    let uuid: String
    weak var textField: NSTextField?
    weak var controller: RenameController?

    init(uuid: String, textField: NSTextField, controller: RenameController) {
        self.uuid = uuid
        self.textField = textField
        self.controller = controller
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            let value = textField?.stringValue ?? ""
            dismiss()
            if let controller {
                Task { @MainActor [controller, uuid] in
                    await controller.commit(name: value, for: uuid)
                }
            }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            dismiss()
            controller?.cancel()
            return true
        default:
            return false
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        // Focus lost without an explicit Enter/Escape — treat as cancel.
        guard textField?.superview != nil else { return }
        dismiss()
        controller?.cancel()
    }

    func dismiss() {
        textField?.removeFromSuperview()
        controller?.release(self)
    }
}
