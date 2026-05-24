# Nook

[![CI](https://github.com/Kalwaleed/nook/actions/workflows/ci.yml/badge.svg)](https://github.com/Kalwaleed/nook/actions/workflows/ci.yml)

Custom names for your macOS Spaces, shown in Mission Control and in your display's notch.

macOS labels every virtual desktop "Desktop 1", "Desktop 2", etc. Nook lets you name them — "Coding", "Shopping", "Email" — and shows the name wherever you need it.

## Features

- **Labels in Mission Control** — named Spaces show their Name instead of "Desktop N"; unnamed Spaces keep the default.
- **Hover-activated Notch** — on notched MacBooks, hovering the notch expands a small surface showing your Active Space's Name.
- **Per-display** — each screen tracks its own Active Space independently.
- **Rename inline** — double-click a Label in Mission Control.
- **Collision-safe** — two Spaces named "Coding" become "Coding 1" and "Coding 2" automatically.
- **UUID-tracked** — Names follow their Space through reorders and reboots.

## Requirements

- macOS 13 Ventura or later
- Accessibility permission (granted on first launch)

## Install

Download the latest `.dmg` from [Releases](https://github.com/Kalwaleed/nook/releases), open it, and drag Nook to Applications.

Nook is open source and notarized. You can also build from source — see [Contributing](#contributing).

## Contributing

Read [`CONTEXT.md`](CONTEXT.md) for the domain vocabulary and [`PRD.md`](PRD.md) for the full product spec before opening a PR. Architecture decisions are in [`docs/adr/`](docs/adr/).

## License

GPL-3.0 — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

The notch-activation surface in `Nook/Notch/` is derived from
[mew-notch](https://github.com/monuk7735/mew-notch) (GPL-3.0) by Monu Kumar.
Per GPL copyleft, the combined work is now distributed under GPL-3.0; the
pre-GPL MIT history is preserved in `NOTICE`.
