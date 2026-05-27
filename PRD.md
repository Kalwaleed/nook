# PRD: Nook — Custom Space Names for macOS

## Problem Statement

macOS Mission Control labels every virtual desktop as "Desktop 1", "Desktop 2", etc. When a user maintains six or more Spaces for different purposes — coding, shopping, email, research — there is no way to tell them apart at a glance. The user must open Mission Control, scan the thumbnails, and mentally match window contents to a purpose. This friction compounds every time they switch context.

Additionally, when Mission Control is closed, there is no ambient indicator of which Space the user is currently in, requiring a context-rebuilding step each time they surface from focus.

## Solution

Nook is a lightweight macOS utility that lets users assign custom Names to each virtual desktop (Space). Named Spaces display their custom Label in Mission Control instead of "Desktop N". A persistent Nook Bar anchored to the display notch (or floating at the top-center of non-notch displays) always shows the Active Space's Name, giving users instant orientation without opening Mission Control.

Names are tied to a Space's internal UUID so they survive reordering, rebooting, and adding/removing other Spaces.

## User Stories

1. As a power user with many Spaces, I want to name each Space after its purpose, so that I can identify them at a glance in Mission Control.
2. As a user, I want my custom Space Names to appear inside Mission Control replacing "Desktop N", so that the native macOS UI reflects my organization.
3. As a user, I want unnamed Spaces to continue showing "Desktop N", so that I don't need to name every Space and can adopt the tool gradually.
4. As a user, I want to see the Active Space's Name in the notch area at all times, so that I always know which context I'm working in without opening Mission Control.
5. As a user on a non-notch display (external monitor, iMac, Mac mini), I want a floating Nook Bar at the top-center of my screen, so that I get the same ambient context indicator regardless of hardware.
6. As a multi-monitor user, I want each display to show its own Active Space Name independently, so that I can track context across all my screens simultaneously.
7. As a user, I want to rename a Space by double-clicking its Label in Mission Control, so that renaming feels native and discoverable without learning a separate UI.
8. As a user, I want to rename the Active Space by clicking the Nook Bar, so that I can rename quickly without leaving my current workflow.
9. As a user, I want to press Escape to cancel a rename in progress, so that I can abort accidental edits without consequences.
10. As a user, I want to press Return/Enter to commit a rename, so that the interaction is keyboard-native.
11. As a user, I want my Space Names to persist across reboots, so that I don't need to re-enter Names after restarting my Mac.
12. As a user, I want my Space Names to follow their Space when I reorder Spaces in Mission Control, so that dragging Spaces to reorganize doesn't scramble my Names.
13. As a user with two Spaces both named "Coding", I want the Nook Bar to show "Coding 1" and "Coding 2", so that I can distinguish between them even without opening Mission Control.
14. As a user, I want name Collision disambiguation to be automatic with no configuration, so that I don't need to pre-plan for duplicate Names.
15. As a user, I want the app to start automatically at login, so that my Space Names are always present without manually launching Nook each session.
16. As a user, I want a preferences window showing all my current Spaces and their Names, so that I can review and edit all Names in one place.
17. As a user, I want to toggle the login item from the preferences window, so that I can control startup behavior without leaving the app.
18. As a user, when I delete a named Space in Mission Control, I want its Name to be silently removed, so that my Name list stays clean without manual cleanup.
19. As a user opening Nook for the first time, I want to be guided through granting Accessibility permissions via a single welcome screen, so that the app works correctly without me needing to know where the setting lives.
20. As a developer or power user, I want the app distributed as a direct download on GitHub, so that I can inspect the source, contribute, or audit what the app does before trusting it with system-level access.
21. As a user on macOS Ventura or later, I want full compatibility, so that I don't need to upgrade my OS to use Nook.
22. As a user switching Spaces rapidly, I want the Nook Bar to update instantly with no perceptible lag, so that the Name always reflects my actual Active Space.
23. As a user, I want the Labels in Mission Control to be positioned directly over the native "Desktop N" text, so that the custom Names feel integrated rather than tacked on.
24. As a user, I want the app to have a minimal footprint with no Dock icon, so that it stays out of the way when I'm not interacting with it.
25. As a user, I want to quit Nook or open Settings from a menu bar status item, so that there is always a clear exit path and access to preferences.
26. As a user with an unnamed Active Space, I want the Nook Bar to show the macOS default label (e.g. "Desktop 3"), so that it always displays something useful rather than going blank.
27. As a user on a Mac with a full-screen app Space active, I want the Nook Bar to show the app's name, so that I always have context even in full-screen mode.
28. As a user who plugs in or unplugs an external monitor, I want the Nook Bar to appear or disappear on that display automatically, so that my setup is always reflected without restarting the app.

## Implementation Decisions

### Modules

**SpaceStore**
The single source of truth for Name data. Stores a mapping of Space UUID (String) to Name (String). Persists to `UserDefaults`. Exposes a simple interface: retrieve Name for UUID, set Name for UUID, delete Name for UUID, list all stored mappings. Does not know about displays or the Active Space — purely a key-value store with persistence.

**SpaceTracker**
Wraps the private CoreGraphics Services APIs (`CGSCopyManagedDisplaySpaces`, `CGSGetActiveSpace`, etc.) to enumerate all current Spaces per display and determine the Active Space for each display. Emits notifications when the Space set changes (Space added, deleted, or Active Space switched). Acts as the authoritative source for "what Spaces currently exist and which is active." Decoupled from naming — consumers combine its output with SpaceStore. Isolated behind a protocol so the CGS layer can be stubbed in tests.

**MissionControlDetector**
Detects Mission Control activation and deactivation. Uses `NSDistributedNotificationCenter` and Accessibility API observations on the Dock process to determine when the Mission Control layer is visible. Emits `didActivate` and `didDeactivate` events. Stateless aside from current activation state.

**MissionControlLabelController**
Manages one borderless, transparent AppKit `NSWindow` per display, parked at a window level above the Dock. When MissionControlDetector fires `didActivate`, the controller queries SpaceTracker for the current display's Space list, resolves Names from SpaceStore, and renders a Label view over each Space thumbnail in the Mission Control strip. Labels match Apple's native font, size, and color to feel integrated. When Mission Control closes, windows are hidden. Handles thumbnail positioning by observing the Mission Control Accessibility tree to find thumbnail frame coordinates.

**NookBar**
The persistent on-screen display of the Active Space Name. Two internal variants share a common interface:
- `NotchBar`: Borderless AppKit window sized and positioned to sit in the notch region (center gap in the menu bar on notch-equipped displays, detected via `NSScreen.safeAreaInsets.top > 0`). Renders the Active Space Name centered within the notch bounds.
- `PillBar`: Borderless rounded-rect AppKit window anchored to the top-center of non-notch displays. Renders identically to NotchBar in terms of content with a subtle vibrancy background.

Both observe SpaceTracker for Active Space changes and SpaceStore for Name changes, and update their display on any change. Both respond to click by invoking RenameController for the Active Space. Both apply Collision disambiguation: if two or more Spaces share the same Name, the Nook Bar shows an Indexed Name ("Coding 1", "Coding 2"). If the Active Space has no Name, shows the macOS default ("Desktop N"). If the Active Space is a full-screen app Space, shows the app's name with no rename affordance. Listens for `NSApplication.didChangeScreenParametersNotification` to add/remove instances when displays are connected or disconnected.

**RenameController**
Orchestrates the rename flow. Accepts a Space UUID and a source frame (either a Mission Control thumbnail frame or the Nook Bar frame). Presents an inline `NSTextField` over the source frame. On Return, writes the new Name to SpaceStore and dismisses. On Escape, dismisses without writing. Does not know about SpaceTracker or display layout — callers provide the frame.

**StatusBarController**
Manages a menu bar `NSStatusItem` providing: the Active Space Name (informational), a "Settings…" item that opens SettingsWindow, and a "Quit Nook" item. The status item is distinct from the Nook Bar — it is the primary home for Settings and Quit.

**SettingsWindow**
SwiftUI `Settings` scene. Displays a list of all current Spaces (from SpaceTracker) with their Names (from SpaceStore), with each Name editable inline. Includes a toggle for launch at login backed by LoginItemManager.

**LoginItemManager**
Thin wrapper around `SMAppService.mainApp` (available macOS 13+). Exposes `enable()`, `disable()`, and `isEnabled` — no other surface area.

**AccessibilityPermissionManager**
Checks `AXIsProcessTrusted()` on launch. If not trusted, presents a single welcome window: a brief explainer and a "Grant Accessibility Access" button that opens System Settings > Privacy & Security > Accessibility. Polls until permission is granted, then dismisses automatically.

### Architectural Decisions

- App runs as an agent (`LSUIElement = YES` in Info.plist) — no Dock icon, no main window, lives purely in the notch/top-of-screen area with a menu bar status item.
- Bundle identifier: `com.kalwaleed.nook`.
- SpaceStore is the only stateful module; all other modules are observers or coordinators.
- Private CGS API calls are isolated to SpaceTracker behind a protocol so they can be stubbed in tests.
- AppKit owns all system-level window management. SwiftUI is used only for the Settings scene.
- Names persist to `UserDefaults` — sufficient data volume, atomic writes, free migration.
- UI copy uses "Space" throughout — consistent with macOS System Settings terminology.
- Notch detection: `NSScreen.safeAreaInsets.top > 0` — no hard-coded model list.
- Minimum deployment target: macOS 13 Ventura.
- Distribution: notarized `.dmg`, open source on GitHub, no Mac App Store.

## Testing Decisions

**What makes a good test:** Tests should exercise the external behavior of a module through its public interface only. They should not reach into private state or assert on implementation details. A good test says "given this input, the module produces this output or emits this notification" — not "the module called this private method."

**Modules to test:**

- **SpaceStore** — highest priority. Pure logic, no system dependencies. Test: set a Name, retrieve it; overwrite a Name; delete a Name; persistence round-trip (write, re-init from disk, read back); empty/nil Name handling.

- **NookBar Indexed Name logic** — test the Collision disambiguation rule in isolation: given a list of Space Names and a target UUID, assert the correct display string ("Coding", "Coding 1", "Coding 2", etc.). Extract this pure function from NookBar for testability.

- **SpaceTracker** — test against a protocol/mock of the CGS layer. Assert that the tracker correctly maps raw API output to structured Space/Display models, and emits the right notifications on simulated changes.

- **RenameController** — test commit and cancel flows against a mock SpaceStore. Assert that Return writes to the store and Escape does not.

- **LoginItemManager** — integration test only (requires real `SMAppService`); unit test the enable/disable toggle logic against a mock.

No tests for MissionControlLabelController or MissionControlDetector in the initial phase — their behavior is inherently coupled to live system state and is better verified manually.

## Out of Scope

- iCloud sync of Space Names across multiple Macs.
- Automatic/AI-suggested Names based on window contents.
- Per-Space wallpaper or color theming.
- Keyboard shortcut to rename the Active Space (can be added later).
- A switch HUD (brief centered overlay when changing Spaces).
- Mac App Store distribution.
- macOS 12 Monterey support.
- Auto-update via Sparkle (planned for a later phase, not v1).
- Full-screen app Space renaming (Nook Bar shows the app name; no rename affordance).
- Windows or Linux support.

## Further Notes

- The private CGS APIs (`CGSCopyManagedDisplaySpaces`, etc.) are used by many shipping Mac utilities (HiDock, TotalSpaces, etc.) and have been stable across macOS versions since at least Big Sur. They are not guaranteed by Apple but are a well-understood dependency for this class of app. The SpaceTracker protocol abstraction ensures the app can adapt if Apple changes or removes these APIs.
- Mission Control thumbnail positioning will require experimentation. The Accessibility tree of the Dock process exposes thumbnail frames, but exact attribute names and tree structure may vary slightly between macOS versions. This is the highest-risk implementation area and should be prototyped first.
- The notch region on MacBook Pro displays is approximately 200px wide on 14" models and slightly wider on 16" models. Label text must be sized to fit within this region without overflow.
- Space UUIDs are stable across reboots but are regenerated if a user restores from Time Machine or migrates to a new Mac. This is an accepted limitation for v1 — users would simply re-enter their Names.
- Nook Bar visual styling (exact font size, vibrancy material, dark/light mode treatment) is deferred to the first prototype iteration.
