#!/usr/bin/env swift
// mc-dump.swift — Diagnostic for Mission Control Space thumbnails.
//
// USAGE:
//   1. Run: /tmp/mc-dump
//   2. When you see "Open Mission Control NOW" — press F3 immediately.
//      Keep Mission Control open until you see "=== Done ===".
//   3. Paste the full output back.

import ApplicationServices
import AppKit
import CoreGraphics

// MARK: - AX helpers

func axValue(_ el: AXUIElement, _ attr: String) -> AnyObject? {
    var v: AnyObject?
    AXUIElementCopyAttributeValue(el, attr as CFString, &v)
    return v
}
func axNames(_ el: AXUIElement) -> [String] {
    var n: CFArray?
    guard AXUIElementCopyAttributeNames(el, &n) == .success, let a = n as? [String] else { return [] }
    return a
}
func axChildren(_ el: AXUIElement) -> [AXUIElement] { axValue(el, "AXChildren") as? [AXUIElement] ?? [] }
func axWindows (_ el: AXUIElement) -> [AXUIElement] { axValue(el, "AXWindows")  as? [AXUIElement] ?? [] }
func str(_ el: AXUIElement, _ a: String) -> String? { axValue(el, a) as? String }
func axFrame(_ el: AXUIElement) -> CGRect? {
    guard let v = axValue(el, "AXFrame"), CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
    var r = CGRect.zero; AXValueGetValue(v as! AXValue, .cgRect, &r); return r
}

func looksLikeThumbnail(_ f: CGRect) -> Bool {
    let h = NSScreen.screens.map(\.frame.height).max() ?? 1440
    return f.width > 150 && f.height > 80 && f.minY < h * 0.60
}

// MARK: - AX tree dump

let maxDepth = 12

func dumpAX(_ el: AXUIElement, depth: Int) {
    guard depth <= maxDepth else {
        print(String(repeating: "  ", count: depth) + "… (maxDepth)"); return
    }
    let pad  = String(repeating: "  ", count: depth)
    let role = str(el, "AXRole") ?? "?"
    let frame = axFrame(el)
    let frameStr = frame.map { String(format: "x=%.0f y=%.0f w=%.0f h=%.0f", $0.minX,$0.minY,$0.width,$0.height) } ?? "no-frame"
    let flag = (frame.map(looksLikeThumbnail) ?? false) ? " ◀︎ THUMBNAIL?" : ""

    var parts = ["[\(role)"]
    for attr in ["AXSubrole","AXTitle","AXDescription","AXIdentifier","AXLabel","AXHelp"] {
        if let v = str(el, attr) { parts.append("\(attr.dropFirst(2))=\"\(v.prefix(60))\"") }
    }
    parts.append(frameStr + "]")
    print(pad + parts.joined(separator: " ") + flag)

    if frame.map(looksLikeThumbnail) ?? false {
        let attrs = axNames(el)
        print("\(pad)  ALL ATTRS: \(attrs.joined(separator: ", "))")
        for a in attrs {
            if let v = axValue(el, a) { print("\(pad)    \(a): \(String("\(v)".prefix(120)))") }
        }
    }
    for child in axChildren(el) { dumpAX(child, depth: depth + 1) }
}

// MARK: - CG window list dump (no AX required)

func dumpCGWindows(forPID pid: pid_t) {
    guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
        print("  (CGWindowListCopyWindowInfo returned nil)"); return
    }
    let mine = list.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
    print("  Dock windows visible to CGWindowList: \(mine.count)")
    for (i, info) in mine.enumerated() {
        let name   = info[kCGWindowName   as String] as? String ?? "(no name)"
        let layer  = info[kCGWindowLayer  as String] as? Int    ?? -1
        let num    = info[kCGWindowNumber as String] as? Int    ?? -1
        var bounds = CGRect.zero
        if let b = info[kCGWindowBounds as String] as? [String: CGFloat] {
            bounds = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0,
                           width: b["Width"] ?? 0, height: b["Height"] ?? 0)
        }
        print(String(format: "  [%d] layer=%d num=%d name=\"%@\" x=%.0f y=%.0f w=%.0f h=%.0f",
                     i, layer, num, name,
                     bounds.minX, bounds.minY, bounds.width, bounds.height))
    }
}

// MARK: - Entry point

// Check Accessibility
let sysWide = AXUIElementCreateSystemWide()
var _: AnyObject?
var focusedResult: AnyObject?
if AXUIElementCopyAttributeValue(sysWide, "AXFocusedApplication" as CFString, &focusedResult) == .apiDisabled {
    fputs("ERROR: Accessibility not granted. System Settings → Privacy & Security → Accessibility\n", stderr)
    exit(1)
}

guard let dock = NSWorkspace.shared.runningApplications
        .first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
    fputs("ERROR: com.apple.dock not running\n", stderr); exit(1)
}

// Countdown
for i in stride(from: 5, through: 1, by: -1) {
    print(">>> Open Mission Control NOW — starting in \(i)s (press F3 or 3-finger swipe) <<<")
    fflush(stdout)
    Thread.sleep(forTimeInterval: 1)
}
print()

let dockApp = AXUIElementCreateApplication(dock.processIdentifier)

// ── Section 1: CGWindowList (works regardless of AX tree structure) ──────────
print("════════════════════════════════════════")
print("SECTION 1 — CGWindowList (Dock pid \(dock.processIdentifier))")
print("════════════════════════════════════════")
dumpCGWindows(forPID: dock.processIdentifier)
print()

// ── Section 2: All top-level AX attributes on the Dock application ───────────
print("════════════════════════════════════════")
print("SECTION 2 — AXApplication top-level attributes")
print("════════════════════════════════════════")
let topAttrs = axNames(dockApp)
print("Attributes: \(topAttrs.joined(separator: ", "))")
for attr in topAttrs {
    if let v = axValue(dockApp, attr) { print("  \(attr): \(String("\(v)".prefix(200)))") }
}
print()

// ── Section 3: AXWindows subtree ─────────────────────────────────────────────
let wins = axWindows(dockApp)
print("════════════════════════════════════════")
print("SECTION 3 — AXWindows (\(wins.count) windows)")
print("════════════════════════════════════════")
for (i, w) in wins.enumerated() {
    print("\n--- Window \(i) ---"); dumpAX(w, depth: 1)
}
print()

// ── Section 4: AXChildren subtree (regular Dock bar) ─────────────────────────
print("════════════════════════════════════════")
print("SECTION 4 — AXChildren (regular Dock bar)")
print("════════════════════════════════════════")
dumpAX(dockApp, depth: 0)

print()
print("=== Done ===")
