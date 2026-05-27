// SPDX-License-Identifier: GPL-3.0-or-later
//
// Nook — SwiftUI root view rendered into NookNotchPanel
//
// Adapted from mew-notch (https://github.com/monuk7735/mew-notch),
// MewNotch/View/Notch/NotchView.swift, Copyright (C) Monu Kumar, GPL-3.0.
// Stripped: glassEffect, dropDestination, Expanded/Collapsed/OptionsView
// (pull in shelf/HUD/settings), context menu.

import AppKit
import NookKit
import SwiftUI

struct NotchRootView: View {

    @StateObject private var vm: NotchViewModel
    private let store: SpaceStore
    private let tracker: any SpaceTrackerProtocol

    init(screen: NSScreen, store: SpaceStore, tracker: any SpaceTrackerProtocol) {
        _vm = StateObject(wrappedValue: NotchViewModel(screen: screen))
        self.store = store
        self.tracker = tracker
    }

    // Phase 1 expanded dimensions. Width grows enough to hold a short Space
    // name + padding; height drops below the notch to give room.
    private var width: CGFloat {
        vm.isExpanded ? max(vm.notchSize.width + 240, 280) : vm.notchSize.width
    }
    private var height: CGFloat {
        vm.isExpanded ? 90 : vm.notchSize.height
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                ZStack {
                    // The masked black surface IS the visible notch. The
                    // surrounding panel is transparent, so .onHover only fires
                    // when the cursor enters this masked region — no global
                    // event tap needed.
                    Color.black

                    if vm.isExpanded {
                        NotchContentView(store: store, tracker: tracker)
                            .transition(.opacity)
                    }
                }
                .frame(width: width, height: height)
                .mask(
                    NotchShape(
                        topRadius: vm.cornerRadius.top,
                        bottomRadius: vm.cornerRadius.bottom
                    )
                )
                .scaleEffect(vm.isHovered ? 1.05 : 1.0, anchor: .top)
                .shadow(radius: vm.isHovered ? 5 : 0)
                .onHover { vm.onHover($0) }
                .onTapGesture { vm.expand() }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.isExpanded)

                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .preferredColorScheme(.dark)
    }
}
