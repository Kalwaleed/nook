import AppKit

public final class RenameController {
    private let store: any SpaceStoreProtocol

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

    public func cancel() {
    }

    public func present(for uuid: String, over frame: NSRect, in window: NSWindow) {
        let textField = NSTextField(frame: frame)
        textField.stringValue = ""
        textField.bezelStyle = .roundedBezel
        window.contentView?.addSubview(textField)
        textField.becomeFirstResponder()
    }
}
