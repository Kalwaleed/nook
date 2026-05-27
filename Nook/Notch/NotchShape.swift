// SPDX-License-Identifier: GPL-3.0-or-later
//
// Nook — Notch outline used to mask the overlay surface
//
// Copied verbatim from mew-notch (https://github.com/monuk7735/mew-notch),
// MewNotch/View/Common/Shapes/NotchShape.swift, Copyright (C) Monu Kumar,
// GPL-3.0.

import SwiftUI

struct NotchShape: Shape {

    var topRadius: CGFloat
    var bottomRadius: CGFloat

    init(topRadius: CGFloat = 8, bottomRadius: CGFloat = 13) {
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
    }

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius),
            control: CGPoint(x: rect.minX + topRadius, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.minX + topRadius, y: rect.maxY - bottomRadius))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topRadius + bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topRadius, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - topRadius - bottomRadius, y: rect.maxY))

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topRadius, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.maxX - topRadius, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY + bottomRadius))

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topRadius, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return path
    }
}
