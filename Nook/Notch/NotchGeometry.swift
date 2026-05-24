// SPDX-License-Identifier: GPL-3.0-or-later
//
// Nook — Notch geometry helpers
//
// Adapted from mew-notch (https://github.com/monuk7735/mew-notch),
// MewNotch/Utils/NotchUtils.swift, Copyright (C) Monu Kumar, GPL-3.0.
// Stripped to real-notch detection only.

import AppKit
import SwiftUI

enum NotchGeometry {

    static let collapsedCornerRadius: (top: CGFloat, bottom: CGFloat) = (top: 8, bottom: 13)
    static let expandedCornerRadius: (top: CGFloat, bottom: CGFloat) = (top: 8, bottom: 24)

    static func hasNotch(screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 0
    }

    // Width: the horizontal gap between the two auxiliary areas the OS reports
    // around the notch. Height: the safe-area inset itself.
    static func realNotchSize(screen: NSScreen) -> CGSize {
        guard hasNotch(screen: screen) else { return .zero }
        let left = screen.auxiliaryTopLeftArea?.width ?? 0
        let right = screen.auxiliaryTopRightArea?.width ?? 0
        let width = max(0, screen.frame.width - left - right)
        return CGSize(width: width, height: screen.safeAreaInsets.top)
    }
}
