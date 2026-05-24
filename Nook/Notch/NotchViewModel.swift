// SPDX-License-Identifier: GPL-3.0-or-later
//
// Nook — Hover/expand state for the notch surface
//
// Adapted from mew-notch (https://github.com/monuk7735/mew-notch),
// MewNotch/ViewModel/Notch/NotchViewModel.swift, Copyright (C) Monu Kumar,
// GPL-3.0. Stripped: NotchDefaults, HapticsManager, drop-target, pin, custom
// timing config. Replaced .spring(.bouncy(...)) (macOS 14+) with a plain
// .spring(...) so it compiles on Nook's macOS 13 deployment target.

import AppKit
import SwiftUI

final class NotchViewModel: ObservableObject {

    let screen: NSScreen

    @Published var notchSize: CGSize = .zero
    @Published var isHovered: Bool = false
    @Published var isExpanded: Bool = false

    // The visible shape is slightly wider than the bare notch so the outline
    // hugs the bezel rather than ending mid-pixel.
    var cornerRadius: (top: CGFloat, bottom: CGFloat) = NotchGeometry.collapsedCornerRadius
    var extraNotchPadSize: CGSize = .init(width: 16, height: 0)

    // Hover-before-expand delay, hard-coded for Phase 1.
    private static let expandOnHoverDelay: TimeInterval = 0.2

    private var hoverTimer: Timer?

    init(screen: NSScreen) {
        self.screen = screen
        refreshNotchSize()
    }

    func refreshNotchSize() {
        var size = NotchGeometry.realNotchSize(screen: screen)
        size.width += extraNotchPadSize.width
        size.height += extraNotchPadSize.height
        withAnimation {
            notchSize = size
        }
    }

    func onHover(_ hovered: Bool) {
        hoverTimer?.invalidate()

        if hovered {
            hoverTimer = Timer.scheduledTimer(
                withTimeInterval: Self.expandOnHoverDelay,
                repeats: false
            ) { [weak self] _ in
                self?.expand()
            }
        } else {
            collapse()
        }

        withAnimation {
            isHovered = hovered
        }
    }

    func expand() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isExpanded = true
        }
        withAnimation {
            cornerRadius = NotchGeometry.expandedCornerRadius
            extraNotchPadSize = .init(width: cornerRadius.top * 2, height: 0)
        }
    }

    private func collapse() {
        withAnimation {
            isExpanded = false
            cornerRadius = NotchGeometry.collapsedCornerRadius
            extraNotchPadSize = .init(width: 16, height: 0)
        }
    }
}
