// SPDX-License-Identifier: GPL-3.0-or-later
//
// Nook — Borderless, click-through-friendly NSPanel that hosts the notch surface
//
// Adapted from mew-notch (https://github.com/monuk7735/mew-notch),
// MewNotch/View/Common/MewWindow.swift, Copyright (C) Monu Kumar, GPL-3.0.

import AppKit

final class NookNotchPanel: NSPanel {

    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )

        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false

        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]

        canBecomeVisibleWithoutLogin = true
        // Sit just above the menu bar so the overlay can paint the notch shape.
        level = .mainMenu + 1

        hasShadow = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
