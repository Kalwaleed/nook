# UUID-based Space identity

Space Names are keyed by the Space's internal macOS UUID, not by its position in Mission Control. macOS assigns each Space a stable UUID (stored in `~/Library/Preferences/com.apple.spaces.plist`) that survives reboots and reordering. Position-based identity was rejected because dragging a Space to a new position in Mission Control would silently reassign all Names — a user who reorders their Spaces to reorganize would find every Name attached to the wrong Space.

The only case where UUID identity fails is migration to a new Mac or a Time Machine restore, which regenerates UUIDs. This is an accepted limitation for v1.
