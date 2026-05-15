#!/usr/bin/env bash
# Build (if needed) and wrap Release Molly.app in a compressed UDZO .dmg for Apple Silicon.
# Output: dist/Molly-<version>-arm64.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DIST="${ROOT}/dist"
mkdir -p "${DIST}"

if [[ -n "${MOLLY_APP:-}" ]] && [[ -d "${MOLLY_APP}" ]]; then
	APP="${MOLLY_APP}"
else
	echo "→ Locating BUILT_PRODUCTS_DIR…"
	BUILT_PRODUCTS_DIR="$(
		xcodebuild -project Molly.xcodeproj -scheme Molly -configuration Release -showBuildSettings 2>/dev/null \
			| sed -n 's/^[[:space:]]*BUILT_PRODUCTS_DIR = //p' | head -n1
	)"
	if [[ -z "${BUILT_PRODUCTS_DIR}" ]] || [[ ! -d "${BUILT_PRODUCTS_DIR}/Molly.app" ]]; then
		echo "→ Building Release (arm64)…"
		xcodebuild -project Molly.xcodeproj -scheme Molly -configuration Release \
			-destination 'platform=macOS,arch=arm64' \
			ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
			CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}" \
			CODE_SIGNING_ALLOWED=YES \
			build
		BUILT_PRODUCTS_DIR="$(
			xcodebuild -project Molly.xcodeproj -scheme Molly -configuration Release -showBuildSettings 2>/dev/null \
				| sed -n 's/^[[:space:]]*BUILT_PRODUCTS_DIR = //p' | head -n1
		)"
	fi
	APP="${BUILT_PRODUCTS_DIR}/Molly.app"
fi

if [[ ! -d "${APP}" ]]; then
	echo "Molly.app not found at: ${APP}" >&2
	echo "Set MOLLY_APP to a folder path, or run from repo after a successful Release build." >&2
	exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist" 2>/dev/null || echo "0.0.0")"
DMG_NAME="Molly-${VERSION}-arm64.dmg"
DMG_PATH="${DIST}/${DMG_NAME}"
VOLNAME="Molly ${VERSION}"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/molly-dmg-stage.XXXXXX")"
cleanup() { rm -rf "${STAGE}"; }
trap cleanup EXIT

echo "→ Staging ${APP}…"
ditto "${APP}" "${STAGE}/Molly.app"
ln -sf /Applications "${STAGE}/Applications"

rm -f "${DMG_PATH}"
echo "→ Creating ${DMG_PATH}…"
hdiutil create -volname "${VOLNAME}" -srcfolder "${STAGE}" -ov -format UDZO -imagekey zlib-level=9 "${DMG_PATH}"

echo ""
echo "DMG: ${DMG_PATH}"
ls -lh "${DMG_PATH}"
