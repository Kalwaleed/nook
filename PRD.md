# PRD: Nook — Custom Desktop Space Names for macOS

## Problem Statement

macOS Mission Control labels every virtual desktop as "Desktop 1", "Desktop 2", etc. When a user maintains six or more desktops for different purposes — coding, shopping, email, research — there is no way to tell them apart at a glance. The user must open Mission Control, scan the thumbnails, and mentally match window contents to a purpose. This friction compounds every time they switch context.

Additionally, when Mission Control is closed, there is no ambient indicator of which desktop the user is currently on, requiring a context-rebuilding step each time they surface from focus.

## Solution

Nook is a lightweight macOS menu bar utility that lets users assign custom names to each virtual desktop (Space). Named desktops display their custom label in Mission Control instead of "Desktop N". A persistent widget anchored to the display notch (or a floating pill on non-notch displays) always shows the current desktop's name, giving users instant orientation without opening Mission Control.

Names are tied to a Space's internal UUID so they survive reordering, rebooting, and adding/removing other spaces.

## User Stories

1. As a power user with many desktops, I want to name each desktop after its purpose, so that I can identify them at a glance in Mission Control.
2. As a user, I want my custom desktop names to appear inside Mission Control replacing "Desktop N", so that the native macOS UI reflects my organization.
3. As a user, I want unnamed desktops to continue showing "Desktop N", so that I don't need to name every desktop and can adopt the tool gradually.
4. As a user, I want to see the current desktop's name in the notch area at all times, so that I always know which context I'm working in without opening Mission Control.
5. As a user on a non-notch display (external monitor, iMac, Mac mini), I want a floating pill widget at the top-center of my screen, so that I get the same ambient context indicator regardless of hardware.
6. As a multi-monitor user, I want each display to show its own current desktop name independently, so that I can track context across all my screens simultaneously.
7. As a user, I want to rename a desktop by double-clicking its label in Mission Control, so that renaming feels native and discoverable without learning a separate UI.
8. As a user, I want to rename the current desktop by clicking the notch widget or pill, so that I can rename quickly without leaving my current workflow.
9. As a user, I want to press Escape to cancel a rename in progress, so that I can abort accidental edits without consequences.
10. As a user, I want to press Return/Enter to commit a rename, so that the interaction is keyboard-native.
11. As a user, I want my desktop names to persist across reboots, so that I don't need to re-enter names after restarting my Mac.
12. As a user, I want my desktop names to follow their space when I reorder desktops in Mission Control, so that dragging desktops to reorganize doesn't scramble my names.
13. As a user with two desktops both named "Coding", I want the notch widget to show "Coding 1/2" instead of just "Coding", so that I can distinguish between them even without opening Mission Control.
14. As a user, I want name collision disambiguation to be automatic with no configuration, so that I don't need to pre-plan for duplicate names.
15. As a user, I want the app to start automatically at login, so that my desktop names are always present without manually launching Nook each session.
16. As a user, I want a preferences window showing all my current desktops and their names, so that I can review and edit all names in one place.
17. As a user, I want to toggle the login item from the preferences window, so that I can control startup behavior without leaving the app.
18. As a user, when I delete a named desktop in Mission Control, I want its name to be silently removed, so that my name list stays clean without manual cleanup.
19. As a user opening Nook for the first time, I want to be guided through granting Accessibility permissions, so that the app works correctly without me needing to know where the setting lives.
20. As a developer or power user, I want the app distributed as a direct download on GitHub, so that I can inspect the source, contribute, or audit what the app does before trusting it with system-level access.
21. As a user on macOS Ventura or later, I want full compatibility, so that I don't need to upgrade my OS to use Nook.
22. As a user switching desktops rapidly, I want the notch widget to update instantly with no perceptible lag, so that the name always reflects my actual current context.
23. As a user, I want the overlay labels in Mission Control to be positioned directly over or replacing the native "Desktop N" text, so that the custom names feel integrated rather than tacked on.
24. As a user, I want the app to have a minimal footprint with no Dock icon, so that it stays out of the way when I'm not interacting with it.
25. As a user, I want to quit Nook from the notch widget or a right-click context menu, so that there is always a clear exit path.

## Implementation Decisions

### Modules

**SpaceStore**
The single source of truth for name data. Stores a mapping of Space UUID (String) to custom name (String). Persists to `UserDefaults` or a plist in Application Support. Exposes a simple interface: retrieve name for UUID, set name for UUID, delete name for UUID, list all stored mappings. Does not know about displays or the active space — purely a key-value store with persistence.

**SpaceTracker**
Wraps the private CoreGraphics Services APIs (`CGSCopyManagedDisplaySpaces`, `CGSGetActiveSpace`, etc.) to enumerate all current spaces per display and determine the active space for each display. Emits notifications when the space set changes (space added, deleted, or active space switched). Acts as the authoritative source for "what spaces currently exist and which is active." Decoupled from naming — consumers combine its output with SpaceStore.

**MissionControlDetector**
Detects Mission Control activation and deactivation. Uses `NSDistributedNotificationCenter` and Accessibility API observations on the Dock process to determine when the Mission Control layer is visible. Emits `didActivate` and `didDeactivate` events. Stateless aside from current activation state.

**OverlayWindowController**
Manages one borderless, transparent AppKit `NSWindow` per display, parked at a window level above the Dock. When MissionControlDetector fires `didActivate`, the controller queries SpaceTracker for the current display's space list, resolves names from SpaceStore, and renders a label view over each desktop thumbnail in the Mission Control strip. When Mission Control closes, windows are hidden. Handles thumbnail positioning by observing the Mission Control Accessibility tree to find thumbnail frame coordinates.

**NotchWidget / PillWidget**
Two AppKit window types sharing a common interface:
- `NotchWidget`: Borderless window sized and positioned to sit in the notch region (the center gap in the menu bar on notch-equipped displays). Renders the current desktop name centered within the notch bounds.
- `PillWidget`: Borderless rounded-rect window anchored to the top-center of non-notch displays. Renders identically to NotchWidget in terms of content.

Both observe SpaceTracker for active-space changes and SpaceStore for name changes, update their label on any change. Both respond to click by invoking RenameController for the current space. Both handle the collision disambiguation rule: if two or more spaces share the same name, display "Name X/N" where X is this space's position among same-named spaces.

**RenameController**
Orchestrates the rename flow. Accepts a Space UUID and a source frame (either a Mission Control thumbnail frame or the widget frame). Presents an inline `NSTextField` over the source frame. On Return, writes the new name to SpaceStore and dismisses. On Escape, dismisses without writing. Does not know about SpaceTracker or display layout — callers provide the frame.

**SettingsWindow**
SwiftUI `Settings` scene. Displays a list of all current spaces (from SpaceTracker) with their names (from SpaceStore), with each name editable inline. Includes a toggle for launch at login backed by LoginItemManager. No other settings initially.

**LoginItemManager**
Thin wrapper around `SMAppService.mainApp` (available macOS 13+). Exposes `enable()`, `disable()`, and `isEnabled` — no other surface area.

**AccessibilityPermissionManager**
Checks `AXIsProcessTrusted()` on launch. If not trusted, presents a sheet or window directing the user to System Settings > Privacy & Security > Accessibility, with a button that opens the correct pane via URL scheme. Polls until permission is granted, then dismisses automatically.

### Architectural Decisions

- App runs as an agent (`LSUIElement = YES` in Info.plist) — no Dock icon, no main window, lives purely in the menu bar/notch area.
- SpaceStore is the only stateful module; all other modules are observers or coordinators.
- Private CGS API calls are isolated to SpaceTracker behind a protocol so they can be stubbed in tests.
- AppKit owns all system-level window management. SwiftUI is used only for the Settings scene.
- Minimum deployment target: macOS 13 Ventura.
- Distribution: notarized `.dmg`, open source on GitHub, no Mac App Store.

## Testing Decisions

**What makes a good test:** Tests should exercise the external behavior of a module through its public interface only. They should not reach into private state or assert on implementation details. A good test says "given this input, the module produces this output or emits this notification" — not "the module called this private method."

**Modules to test:**

- **SpaceStore** — highest priority. Pure logic, no system dependencies. Test: set a name, retrieve it; overwrite a name; delete a name; persistence round-trip (write, re-init from disk, read back); empty/nil name handling.

- **NotchWidget / PillWidget label logic** — test the disambiguation rule in isolation: given a list of space names and a target UUID, assert the correct display string ("Coding", "Coding 1/2", etc.). Extract this pure function from the widget for testability.

- **SpaceTracker** — test against a protocol/mock of the CGS layer. Assert that the tracker correctly maps raw API output to structured Space/Display models, and emits the right notifications on simulated changes.

- **RenameController** — test commit and cancel flows against a mock SpaceStore. Assert that Return writes to the store and Escape does not.

- **LoginItemManager** — integration test only (requires real `SMAppService`); unit test the enable/disable toggle logic against a mock.

No tests for OverlayWindowController or MissionControlDetector in the initial phase — their behavior is inherently coupled to live system state and is better verified manually.

## Out of Scope

- iCloud sync of desktop names across multiple Macs.
- Automatic/AI-suggested names based on window contents.
- Per-space wallpaper or color theming.
- Keyboard shortcut to rename current desktop (can be added later).
- A switch HUD (brief centered overlay when changing desktops).
- Mac App Store distribution.
- macOS 12 Monterey support.
- Full-screen app spaces (these are managed by their respective apps and do not map cleanly to user-named desktops).
- Windows or Linux support.

## Further Notes

- The private CGS APIs (`CGSCopyManagedDisplaySpaces`, etc.) are used by many shipping Mac utilities (HiDock, TotalSpaces, etc.) and have been stable across macOS versions since at least Big Sur. They are not guaranteed by Apple but are a well-understood dependency for this class of app. The SpaceTracker protocol abstraction ensures the app can adapt if Apple changes or removes these APIs.
- Mission Control thumbnail positioning will require experimentation. The Accessibility tree of the Dock process exposes thumbnail frames, but exact attribute names and tree structure may vary slightly between macOS versions. This is the highest-risk implementation area and should be prototyped first.
- The notch region on MacBook Pro displays is approximately 200px wide on 14" models and slightly wider on 16" models. Label text must be sized to fit within this region without overflow.
- Space UUIDs are stable across reboots but are regenerated if a user restores from Time Machine or migrates to a new Mac. This is an acceptable edge case for v1 — users would simply re-enter their names.
