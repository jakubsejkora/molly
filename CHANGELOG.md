# Changelog

All notable changes to Molly are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Molly
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). While the project
is pre-1.0, minor releases may contain breaking changes; patch releases will not.

## [Unreleased]

## [0.5.0] — 2026-06-26

### Added
- **Agent Activity Monitor** — new **Agents** dashboard pane and menu-bar summary that
  track running AI coding sessions on this Mac (Claude Code, Cursor, Codex).
- Process-level detection works out of the box; optional security-scoped folder access
  unlocks session names, project folders, status badges, and Claude Code sub-agents.
- Session start/end/status transitions are logged to the local JSONL store.
- GitHub Actions **Release (Apple Silicon)** workflow builds and publishes
  `Molly-<version>-arm64.dmg` on version tags.

### Changed
- `MARKETING_VERSION` bumped to `0.5.0`.
- Frozen spec updated: Agents monitor is now an in-scope pillar.

## [0.4.2] — 2026-05-15

### Added
- **Developer ID signing + Apple notarization.** The DMG is now signed with
  `Developer ID Application: JAKUB SEJKORA (T6C4HUSL99)` and Apple has issued
  a notarization ticket stapled into the bundle. macOS Sequoia (15+) and
  earlier open it without any Gatekeeper warning — no right-click → Open or
  System Settings detour required.

### Fixed
- README `<picture>` block was serving the wrong logo per theme — dark-mode
  viewers got dark text on a dark background, light-mode viewers got white
  text on a white background. The brand kit's `_light` suffix means "light
  text" (for dark backgrounds) and `_dark` means "dark text" (for light
  backgrounds), the opposite of the `prefers-color-scheme` mapping I had.

### Removed
- "Right-click → Open → Open" first-run instructions from README — no longer
  needed now that the DMG is notarized. macOS Sequoia hardened that workflow
  anyway; the bypass dialog now only offers "Move to Trash" / "Done".

## [0.4.1] — 2026-05-15

### Added
- README screenshots gallery: dashboard Overview hero, menu-bar dropdown,
  session-timer preset picker (under `docs/screenshots/`).

### Changed
- CI: bumped the verify-macos-build runner to `macos-15` with explicit Xcode 16+
  selection, since XcodeGen 2.44 emits an Xcode-16-only project format
  (`objectVersion = 77`) that the previous `macos-14` runner (Xcode 15.4) could not read.
- `MARKETING_VERSION` bumped to `0.4.1` so the binary version stamp matches the tag.

### Notes
- The menu-bar screenshot was captured from a pre-0.4.0 local build and still
  shows the legacy "Sparkle-eligible" SKU footer. The 0.4.0+ binary now displays
  "Developer ID (direct download)" — screenshot to be refreshed in a later release.
- No functional code changes vs 0.4.0; the DMG is a re-stamp.

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

[Unreleased]: https://github.com/jakubsejkora/molly/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/jakubsejkora/molly/releases/tag/v0.5.0
[0.4.2]: https://github.com/jakubsejkora/molly/releases/tag/v0.4.2
[0.4.1]: https://github.com/jakubsejkora/molly/releases/tag/v0.4.1
[0.4.0]: https://github.com/jakubsejkora/molly/releases/tag/v0.4.0
