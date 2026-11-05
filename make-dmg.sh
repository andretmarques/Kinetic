#!/bin/zsh
# Builds Kinetic.app (via build.sh) and wraps it in the designed DMG window from Packaging/dmg-settings.py.
#
#   ./make-dmg.sh                                   # ad-hoc signed, for your own Mac
#   SIGN_ID="Developer ID Application: …" ./make-dmg.sh
#   SIGN_ID="…" NOTARY_PROFILE=kinetic ./make-dmg.sh  # also notarize + staple (needs a paid Apple Developer account)
#
# One-time setup for notarization:
#   xcrun notarytool store-credentials kinetic --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
set -euo pipefail
cd "$(dirname "$0")"

DMG="build/Kinetic.dmg"
TOOLS="build/dmg-tools"

./build.sh release

if [[ ! -x "$TOOLS/bin/dmgbuild" ]]; then
    echo "▶ installing dmgbuild"
    python3 -m venv "$TOOLS"
    "$TOOLS/bin/pip" install --quiet --disable-pip-version-check dmgbuild==1.6.5 ds_store==1.3.1 mac_alias==2.2.2
fi

echo "▶ creating $DMG"
rm -f "$DMG"
"$TOOLS/bin/dmgbuild" -s Packaging/dmg-settings.py Kinetic "$DMG"

if [[ -n "${SIGN_ID:-}" && "$SIGN_ID" != "-" ]]; then
    codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "▶ notarizing (this takes a few minutes)"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    echo "✓ notarized and stapled"
fi

echo
echo "Done: $DMG"
if [[ -z "${NOTARY_PROFILE:-}" ]]; then
    echo "Not notarized. macOS will refuse a downloaded copy until you run:"
    echo "  xattr -dr com.apple.quarantine /Applications/Kinetic.app"
fi
