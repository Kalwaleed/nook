import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var isLaunchAtLoginEnabled: Bool

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        _isLaunchAtLoginEnabled = State(initialValue: viewModel.loginItemManager.isEnabled)
    }

    var body: some View {
        Form {
            Section("Spaces") {
                if viewModel.spaceNames.isEmpty {
                    Text("No Spaces found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.spaceNames, id: \.uuid) { item in
                        SpaceNameRow(uuid: item.uuid, name: item.name) { newName in
                            viewModel.setName(newName, for: item.uuid)
                        }
                    }
                }
            }

            Section("General") {
                Toggle("Launch at Login", isOn: $isLaunchAtLoginEnabled)
                    .onChange(of: isLaunchAtLoginEnabled) { enabled in
                        do {
                            if enabled {
                                try viewModel.loginItemManager.enable()
                            } else {
                                try viewModel.loginItemManager.disable()
                            }
                        } catch {
                            isLaunchAtLoginEnabled = !enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 360, minHeight: 260)
    }
}

private struct SpaceNameRow: View {
    let uuid: String
    @State private var editedName: String
    let onCommit: (String) -> Void

    init(uuid: String, name: String, onCommit: @escaping (String) -> Void) {
        self.uuid = uuid
        _editedName = State(initialValue: name)
        self.onCommit = onCommit
    }

    var body: some View {
        TextField("Unnamed", text: $editedName)
            .onSubmit { onCommit(editedName) }
    }
}
