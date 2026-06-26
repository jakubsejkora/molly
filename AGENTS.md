# AGENTS.md

Guidance for AI coding agents working on this repository.

## What this project is

Molly is a native macOS menu bar + dashboard app (Swift / SwiftUI / AppKit) that keeps a Mac awake for long agent or CI jobs, with an optional jittered network-probe lane to trim idle hotspot disconnects. macOS 14 Sonoma+, Apple Silicon. Currently at **v0.5.0** (pre-1.0 preview).

## Layout

| Path | What's there |
|---|---|
| `Sources/MollyApp/` | All Swift source. SwiftUI dashboard, `NSStatusItem` menu, `ConnectivityLaneEngine`, `AwakeLanePowerManager`, JSONL log store. |
| `Supporting/Assets.xcassets/` | App icon, menu-bar template imageset, accent color. |
| `Supporting/MollySandbox.entitlements` | Sandbox: outbound network + user-selected export. |
| `Supporting/ExportOptions-direct-developer-id.plist` | Developer-ID export config (for when signing is set up). |
| `Scripts/` | `build-direct-arm64.sh` (Developer ID archive + export + zip), `package-dmg-arm64.sh` (wrap `.app` into a UDZO `.dmg`; supports ad-hoc signing). |
| `spec/molly-v1-frozen-spec.md` | Frozen product spec — source of truth for behavior. |
| `molly_branding/` | Brand kit: app icon set, menu-bar template, wordmark lockups, HTML brand page. |
| `docs/` | README hero images, release docs. |
| `.github/workflows/verify-macos-build.yml` | CI smoke test — Release `arm64` ad-hoc build, uploads the `.app` as an artifact. |

## Build

```bash
brew install xcodegen
xcodegen generate          # generates Molly.xcodeproj from project.yml (gitignored)
open Molly.xcodeproj       # then build & run the Molly scheme
```

Release builds pin `ARCHS=arm64`. Debug follows the active arch.

## Package a DMG

```bash
./Scripts/package-dmg-arm64.sh   # → dist/Molly-<version>-arm64.dmg
```

Default ad-hoc signing (`CODE_SIGN_IDENTITY=-`). For Developer ID + notarization see `docs/RELEASE.md`.

## House rules

- Do not commit `Molly.xcodeproj/`, `DerivedData/`, `dist/`, or `.DS_Store` — see `.gitignore`. The project is generated from `project.yml`.
- The frozen spec at `spec/molly-v1-frozen-spec.md` is authoritative for product behavior. If you change behavior, update the spec.
- Sparkle auto-updates are intentionally deferred past 0.4 — do not introduce a `"Sparkle"` user-facing label without shipping Sparkle.
- This is currently a one-person, pre-1.0 project. Prefer small, focused PRs.
