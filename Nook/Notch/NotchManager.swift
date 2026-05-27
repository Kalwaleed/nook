// SPDX-License-Identifier: GPL-3.0-or-later
//
// Nook — Per-screen lifecycle for the notch overlay
//
// Adapted from mew-notch (https://github.com/monuk7735/mew-notch),
// MewNotch/Utils/NotchManager.swift, Copyright (C) Monu Kumar, GPL-3.0.
// Stripped: MacroVisionKit/FullScreenMonitor (no fullscreen-aware hiding in
// Phase 1), NotchSpaceManager and WindowManager.moveToLockScreen (no private
// CGS layering in Phase 1), NotchDefaults-driven per-display visibility
// filter. Made non-singleton to mirror Nook's controller pattern.

import AppKit
import NookKit
import SwiftUI

final class NotchManager {

    private let store: SpaceStore
    private let tracker: any SpaceTrackerProtocol

    private var windows: [NSScreen: NSPanel] = [:]

    init(store: SpaceStore, tracker: any SpaceTrackerProtocol) {
        self.store = store
        self.tracker = tracker

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshNotches),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        refreshNotches()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func refreshNotches() {
        // Drop windows whose screen disappeared or that no longer have a notch.
        for (screen, window) in windows {
            if !NSScreen.screens.contains(screen) || !NotchGeometry.hasNotch(screen: screen) {
                window.close()
                windows.removeValue(forKey: screen)
            }
        }

        // Create a panel for every notched screen we don't already cover.
        for screen in NSScreen.screens where NotchGeometry.hasNotch(screen: screen) {
            if let existing = windows[screen] {
                existing.setFrame(screen.frame, display: true)
                existing.orderFrontRegardless()
                continue
            }

            let panel = NookNotchPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
                backing: .buffered,
                defer: true
            )
            panel.contentView = NSHostingView(
                rootView: NotchRootView(screen: screen, store: store, tracker: tracker)
            )
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            windows[screen] = panel
        }
    }
}
