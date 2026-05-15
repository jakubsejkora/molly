# Molly brand kit

Molly is a native macOS menu-bar app that keeps a Mac awake, including lid-close workflows where supported by your implementation and hardware setup.

## Included

- `molly_branding.html` — standalone brand page with embedded previews.
- `assets/molly_app_icon_1024.png` — master app icon PNG.
- `assets/molly_app_icon.svg` — editable vector source.
- `assets/molly_logo.svg` and PNG lockups.
- `assets/molly_menubar_template_18.png`, `36.png`, `54.png` — menu-bar template PNGs.
- `assets/molly_menubar_template.svg` — vector menu-bar source.
- `xcode-assets/MollyAppIcon.appiconset` — macOS app icon set for Xcode.
- `xcode-assets/MollyMenuBarTemplate.imageset` — template menu-bar imageset for Xcode.

## Suggested AppKit usage

```swift
let image = NSImage(named: "MollyMenuBarTemplate")
image?.isTemplate = true
statusItem.button?.image = image
```

## Brand notes

- Product name: `molly` in lowercase for wordmark; `Molly` in prose.
- Tone: modern, fresh, alert, slightly mischievous, never reckless.
- Safety copy: closed-lid awake sessions can generate heat; use on a ventilated surface.
