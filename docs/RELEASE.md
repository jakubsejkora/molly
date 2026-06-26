# Release engineering

How to cut a Molly release. Pre-1.0 the only supported flow is **Apple Silicon, Developer ID + notarized** (when signing is set up) or **ad-hoc signed** for previews.

## Ad-hoc preview build (current 0.4 default)

```bash
brew install xcodegen
xcodegen generate
./Scripts/package-dmg-arm64.sh
# → dist/Molly-<version>-arm64.dmg
```

`package-dmg-arm64.sh` defaults `CODE_SIGN_IDENTITY=-` (ad-hoc). Users have to right-click → Open the first time because Gatekeeper does not trust ad-hoc signatures. The README's _First run on macOS_ section documents this.

## Developer ID signed + notarized build

Use this flow once you have a Developer ID Application certificate installed in your keychain and a notarization profile.

```bash
chmod +x Scripts/build-direct-arm64.sh   # once
./Scripts/build-direct-arm64.sh
```

This runs `xcodegen generate`, creates a Release archive targeting `arm64`, exports a signed `dist/export/Molly.app` using [`Supporting/ExportOptions-direct-developer-id.plist`](../Supporting/ExportOptions-direct-developer-id.plist), and zips `dist/Molly-<version>-arm64-direct.zip` ready for `notarytool submit`.

If automatic export fails because you have multiple teams, open the plist (or Xcode Organizer) and set the **Developer ID Application** signing team explicitly, or duplicate the plist and point the script at your variant.

### Notarize before wide distribution

```bash
xcrun notarytool submit "dist/Molly-<version>-arm64-direct.zip" \
    --wait --keychain-profile AC_NOTARY
xcrun stapler staple "dist/export/Molly.app"
```

Then re-package the stapled `.app` into a DMG:

```bash
MOLLY_APP=dist/export/Molly.app ./Scripts/package-dmg-arm64.sh
```

## CI

`.github/workflows/verify-macos-build.yml` smoke-builds Release `arm64` with ad-hoc signing on `macos-15` and uploads `Molly.app` as an artifact. Treat the CI artifact as a sanity check only, **not** as a substitute for Developer ID signing + notarization.

`.github/workflows/release-arm64.yml` builds `dist/Molly-<version>-arm64.dmg` and attaches it to a GitHub Release when you push a `v*` tag (or run the workflow manually against an existing tag). CI releases are ad-hoc signed; run the Developer ID flow below before calling a build “wide distribution ready.”

## Mac App Store (future)

Remove `-D MOLLY_SKU_DIRECT` from [`project.yml`](../project.yml), switch entitlements/signing for App Store distribution, and drop the Release `ARCHS` override (App Store builds typically follow Xcode defaults / universal).
