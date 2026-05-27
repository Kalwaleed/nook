// SPDX-License-Identifier: GPL-3.0-or-later
//
// Nook — Content shown inside the expanded notch (Phase 1: active Space name).

import AppKit
import Combine
import NookKit
import SwiftUI

@MainActor
final class NotchContentModel: ObservableObject {

    @Published var name: String = ""

    private let store: SpaceStore
    private let tracker: any SpaceTrackerProtocol
    private var cancellables: Set<AnyCancellable> = []

    // Built-in display has CGS display index 0 (matches StatusBarController).
    private static let mainDisplayID: UInt32 = 0

    init(store: SpaceStore, tracker: any SpaceTrackerProtocol) {
        self.store = store
        self.tracker = tracker

        Task { await self.refresh(spaces: tracker.allSpaces()) }

        tracker.spaceChanges
            .sink { [weak self] spaces in
                Task { @MainActor [weak self] in await self?.refresh(spaces: spaces) }
            }
            .store(in: &cancellables)
    }

    private func refresh(spaces: [SpaceInfo]) async {
        let forDisplay = spaces.filter { $0.displayID == Self.mainDisplayID }
        guard let active = forDisplay.first(where: { $0.isActive }) else { return }

        let pairs: [(uuid: String, name: String?)] = await withTaskGroup(
            of: (String, String?).self
        ) { group in
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

        name = indexedDisplayName(for: active.uuid, in: pairs)
    }
}

struct NotchContentView: View {

    @StateObject private var model: NotchContentModel

    init(store: SpaceStore, tracker: any SpaceTrackerProtocol) {
        _model = StateObject(wrappedValue: NotchContentModel(store: store, tracker: tracker))
    }

    var body: some View {
        Text(model.name)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 16)
    }
}
