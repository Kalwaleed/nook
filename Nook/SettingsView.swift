import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var pendingNames: [String: String] = [:]
    @State private var isLaunchAtLoginEnabled: Bool

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
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
                Spacer()
                Button("Cancel") { pendingNames.removeAll() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(!hasPendingChanges)
                Button("OK") {
                    for (uuid, name) in pendingNames {
                        viewModel.setName(name, for: uuid)
                    }
                    pendingNames.removeAll()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!hasPendingChanges)
            }
            .padding(12)
        }
        .frame(minWidth: 400, minHeight: 320)
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

    private var hasPendingChanges: Bool { !pendingNames.isEmpty }
}
