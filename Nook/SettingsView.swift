import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let onDismiss: () -> Void
    @State private var pendingNames: [String: String] = [:]
    @State private var isLaunchAtLoginEnabled: Bool
    @State private var showResetConfirmation = false

    init(viewModel: SettingsViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        _isLaunchAtLoginEnabled = State(initialValue: viewModel.loginItemManager.isEnabled)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Spaces") {
                    if viewModel.spaceNames.isEmpty {
                        Text("No Spaces found.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(viewModel.spaceNames.enumerated()), id: \.element.uuid) { index, item in
                            HStack {
                                Text("Desktop \(index + 1)")
                                Spacer()
                                TextField("Custom name", text: bindingForName(uuid: item.uuid, saved: item.name))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 180)
                                    .multilineTextAlignment(.trailing)
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

            Divider()

            HStack {
                Button("Reset Names") {
                    showResetConfirmation = true
                }
                Spacer()
                Button("Cancel") {
                    pendingNames.removeAll()
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("OK") {
                    for (uuid, name) in pendingNames {
                        viewModel.setName(name, for: uuid)
                    }
                    pendingNames.removeAll()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 400, minHeight: 320)
        .confirmationDialog("Reset all space names?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                viewModel.resetAllNames()
                pendingNames.removeAll()
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func bindingForName(uuid: String, saved: String) -> Binding<String> {
        Binding(
            get: { pendingNames[uuid] ?? saved },
            set: { newValue in
                if newValue == saved {
                    pendingNames.removeValue(forKey: uuid)
                } else {
                    pendingNames[uuid] = newValue
                }
            }
        )
    }
}
