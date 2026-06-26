#!/usr/bin/env bash
# End-to-end Apple Silicon release on your Mac:
#   XcodeGen → archive → Developer ID export → notarize → staple → DMG
#
# Usage (from repo root):
#   ./Scripts/release-all-arm64.sh
#
# Optional env:
#   NOTARY_PROFILE=AC_NOTARY   # default; your `notarytool store-credentials` profile
#   SKIP_NOTARIZE=1            # build + DMG only (ad-hoc path uses package-dmg-arm64.sh instead)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NOTARY_PROFILE="${NOTARY_PROFILE:-AC_NOTARY}"

if [[ "$(uname -s)" != "Darwin" ]]; then
	echo "This script must run on macOS with Xcode (Apple Silicon)." >&2
	exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
	echo "Xcode command-line tools not found. Install Xcode and run:" >&2
	echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
	exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
	echo "→ Installing XcodeGen…"
	if ! command -v brew >/dev/null 2>&1; then
		echo "Homebrew is required to install XcodeGen: https://brew.sh" >&2
		exit 1
	fi
	brew install xcodegen
fi

echo "════════════════════════════════════════════════════════"
echo " Molly release — Developer ID + notarize + DMG (arm64)"
echo "════════════════════════════════════════════════════════"
echo ""

chmod +x "${ROOT}/Scripts/build-direct-arm64.sh"
chmod +x "${ROOT}/Scripts/package-dmg-arm64.sh"

"${ROOT}/Scripts/build-direct-arm64.sh"

APP="${ROOT}/dist/export/Molly.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist")"
ZIP="${ROOT}/dist/Molly-${VERSION}-arm64-direct.zip"

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
	echo ""
	echo "SKIP_NOTARIZE=1 — skipping notarization."
else
	echo ""
	echo "→ Notarizing ${ZIP} (profile: ${NOTARY_PROFILE})…"
	xcrun notarytool submit "${ZIP}" --wait --keychain-profile "${NOTARY_PROFILE}"

	echo "→ Stapling notarization ticket…"
	xcrun stapler staple "${APP}"
fi

echo ""
echo "→ Packaging DMG…"
MOLLY_APP="${APP}" "${ROOT}/Scripts/package-dmg-arm64.sh"

DMG="${ROOT}/dist/Molly-${VERSION}-arm64.dmg"
SHA="$(shasum -a 256 "${DMG}" | awk '{print $1}')"

echo ""
echo "════════════════════════════════════════════════════════"
echo " Done"
echo "════════════════════════════════════════════════════════"
echo " App:  ${APP}"
echo " DMG:  ${DMG}"
echo " SHA:  ${SHA}"
echo ""
echo "Upload to GitHub Releases (optional):"
echo "  gh release upload v${VERSION} \"${DMG}\" --clobber"
