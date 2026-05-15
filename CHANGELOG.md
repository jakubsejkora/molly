# Changelog

All notable changes to Molly are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Molly
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). While the project
is pre-1.0, minor releases may contain breaking changes; patch releases will not.

## [Unreleased]

### Changed
- CI: bumped the verify-macos-build runner to `macos-15` with explicit Xcode 16+
  selection, since XcodeGen 2.44 emits an Xcode-16-only project format
  (`objectVersion = 77`) that the previous `macos-14` runner (Xcode 15.4) could not read.

## [0.4.0] — 2026-05-15

First public preview.

### Added
- **Awake lane** — holds `IOPowerAssertion` (`PreventUserIdleSystemSleep`) plus
  `ProcessInfo.performExpiringActivity` so long agent/CI jobs survive idle-class
  sleep with the display still allowed to sleep.
- **Connectivity lane** — jittered TCP / HTTPS `HEAD` probes on a ~120 s cycle
  (±25 % jitter), with a captive-neutral fallback host list and iOS Personal
  Hotspot gateway detection (`172.20.10.0/24`).
- **Timer presets** — 30 m / 2 h / 4 h / custom auto-off, with an optional
  mirror toggle that stops both lanes together.
- **Dashboard** — `NavigationSplitView` with Session, Connectivity, Insights,
  Logs, Settings, and About panes.
- **Logs** — local rolling JSONL log store with 7-day retention and a save-panel
  export.
- **Notifications** — timer-expiry summary plus a connectivity-failure alert
  (≥ 5 misses within ≥ 3 min, at most once per 60 min).
- **Menu bar** — `NSStatusItem` with toggles for Awake, Connectivity, the timer
  submenu, a Show Dashboard shortcut (⌘⇧O), and Quit (⌘Q).
- **Launch at login** toggle via `SMAppService` (macOS 13+).
- **Light / Dark / System** appearance token (no hard-coded palette).
- **Brand kit** — full `AppIcon` set, `MollyMenuBarTemplate` imageset with
  proper template rendering intent, light/dark logo lockups, wordmarks.
- **MIT license**, README with first-run / Gatekeeper note, AGENTS.md,
  `docs/RELEASE.md` documenting Developer-ID + notarization.
- **CI** — `verify-macos-build.yml` smoke-builds Release `arm64` on every push.

### Distribution
- Apple Silicon only (arm64), macOS 14 Sonoma+.
- Ad-hoc signed preview DMG (`Molly-0.4.0-arm64.dmg`, ~3.7 MB). Gatekeeper
  refuses the first launch — README documents the right-click → Open workflow.

### Known limitations
- No Sparkle auto-updates yet (the SKU label has been softened from
  "Sparkle-eligible" to "direct download" to reflect this).
- No universal binary — Intel Macs (x86_64) are not supported.
- No automated CI release pipeline; Developer ID + notarization still happens
  on a maintainer Mac per `docs/RELEASE.md`.
- No log-export ZIP (plaintext JSONL via save panel only).

[Unreleased]: https://github.com/jakubsejkora/molly/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/jakubsejkora/molly/releases/tag/v0.4.0
