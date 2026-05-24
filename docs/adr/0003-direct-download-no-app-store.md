# Direct download only; no Mac App Store

Nook is distributed as a notarized `.dmg` via GitHub Releases, not through the Mac App Store. The App Store sandbox prohibits the private CGS APIs that Nook requires for reliable Space tracking (see ADR-0002). A sandboxed build would need to fall back to Accessibility API heuristics, producing a meaningfully worse and less stable product.

Direct download is the standard distribution path for Mac power-user utilities in this category (Rectangle, HiDock, TotalSpaces). Notarization provides Gatekeeper trust without App Store review. The project is open source, so users who want to audit the binary can build from source.
