# Private CGS APIs for Space tracking

Nook uses private CoreGraphics Services APIs (`CGSCopyManagedDisplaySpaces`, `CGSGetActiveSpace`) to enumerate Spaces and track the Active Space per display. macOS exposes no public API for this — there is no `NSWorkspace` method, no entitlement, no documented interface for querying virtual desktop state per display.

The alternative (Accessibility API heuristics on the Dock process) was rejected: it requires observing the Dock's internal window tree, which is structurally unstable across macOS releases and breaks silently rather than loudly. The CGS APIs have been stable since macOS Big Sur and are used by shipping utilities including HiDock and TotalSpaces. They are isolated behind the `SpaceTracker` protocol so the app can adapt if Apple changes or removes them.

This decision also prevents Mac App Store distribution — see ADR-0003.
