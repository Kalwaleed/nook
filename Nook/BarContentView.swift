import AppKit
import Combine
import NookKit
import SwiftUI

// Shared SwiftUI content for both NotchBar and PillBar.
struct BarContentView: View {
    @ObservedObject var model: BarModel

    var body: some View {
        Text(model.displayName)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .onTapGesture { model.onTap() }
    }
}

@MainActor
final class BarModel: ObservableObject {
    @Published var displayName: String = ""
    var onTap: () -> Void = {}

    private let displayID: UInt32
    private let store: SpaceStore
    private let tracker: any SpaceTrackerProtocol
    private var cancellables: Set<AnyCancellable> = []

    init(displayID: UInt32, store: SpaceStore, tracker: any SpaceTrackerProtocol) {
        self.displayID = displayID
        self.store = store
        self.tracker = tracker

        Task { @MainActor in await self.refresh(spaces: tracker.allSpaces()) }

        tracker.spaceChanges
            .sink { [weak self] spaces in
                Task { @MainActor [weak self] in await self?.refresh(spaces: spaces) }
            }
            .store(in: &cancellables)
    }

    private func refresh(spaces: [SpaceInfo]) async {
        let forDisplay = spaces.filter { $0.displayID == displayID }
        guard let active = forDisplay.first(where: { $0.isActive }) else { return }

        if active.isFullScreen {
            displayName = activeAppName() ?? active.uuid
            return
        }

        let pairs: [(uuid: String, name: String?)] = await withTaskGroup(of: (String, String?).self) { group in
            for s in forDisplay {
                group.addTask { (s.uuid, await self.store.name(for: s.uuid)) }
            }
            var result: [(String, String?)] = []
            for await pair in group { result.append(pair) }
            return result.sorted { a, b in
                (forDisplay.firstIndex(where: { $0.uuid == a.0 }) ?? 0) <
                (forDisplay.firstIndex(where: { $0.uuid == b.0 }) ?? 0)
            }
        }

        displayName = indexedDisplayName(for: active.uuid, in: pairs)
    }

    private func activeAppName() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }
}
