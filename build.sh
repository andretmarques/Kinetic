#!/bin/zsh
# Builds Kinetic.app (settings app) with KineticAgent.app nested as a login item.
#
#   ./build.sh                 # debug, this Mac's architecture, ad-hoc signed → build/Kinetic.app
#   ./build.sh release         # release, universal (Apple Silicon + Intel), ad-hoc signed
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./build.sh release
#
# Use a real Developer ID even for day-to-day builds: with ad-hoc signing macOS forgets the
# Accessibility / Input Monitoring grants on every rebuild.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-debug}"
SIGN_ID="${SIGN_ID:--}"
OUT="build"
APP="$OUT/Kinetic.app"
AGENT="$APP/Contents/Library/LoginItems/KineticAgent.app"

# Command Line Tools have no SwiftUI macro plugin, and newer SDKs make @State a macro.
# Without Xcode, build against the macOS 26 SDK, which is what Kinetic targets anyway.
if [[ -z "${SDKROOT:-}" && "$(xcode-select -p)" == *CommandLineTools* ]]; then
    SDK26=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
    if [[ ! -d "$SDK26" ]]; then
        echo "✗ Needs Xcode, or Command Line Tools with the macOS 26 SDK." >&2
        exit 1
    fi
    export SDKROOT="$SDK26"
    echo "▶ no Xcode: building against $SDK26"
fi

BINS="$OUT/bin"
rm -rf "$BINS"
mkdir -p "$BINS"
if [[ "$CONFIG" == release ]]; then
    for arch in arm64 x86_64; do
        echo "▶ swift build (release, $arch)"
        swift build -c release --arch "$arch" --product Kinetic
        swift build -c release --arch "$arch" --product KineticAgent
        swift build -c release --arch "$arch" --product KineticMenuBar
        BIN="$(swift build -c release --arch "$arch" --show-bin-path)"
        mkdir -p "$BINS/$arch"
        cp "$BIN/Kinetic" "$BIN/KineticAgent" "$BIN/libKineticMenuBar.dylib" "$BINS/$arch/"
    done
    for product in Kinetic KineticAgent libKineticMenuBar.dylib; do
        lipo -create "$BINS/arm64/$product" "$BINS/x86_64/$product" -output "$BINS/$product"
    done
else
    echo "▶ swift build ($CONFIG)"
    swift build -c "$CONFIG" --product Kinetic
    swift build -c "$CONFIG" --product KineticAgent
    swift build -c "$CONFIG" --product KineticMenuBar
    BIN="$(swift build -c "$CONFIG" --show-bin-path)"
    cp "$BIN/Kinetic" "$BIN/KineticAgent" "$BIN/libKineticMenuBar.dylib" "$BINS/"
fi

echo "▶ assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchAgents"
mkdir -p "$AGENT/Contents/MacOS" "$AGENT/Contents/Resources" "$AGENT/Contents/Frameworks"

cp "$BINS/Kinetic" "$APP/Contents/MacOS/Kinetic"
cp "$BINS/KineticAgent" "$AGENT/Contents/MacOS/KineticAgent"
cp "$BINS/libKineticMenuBar.dylib" "$AGENT/Contents/Frameworks/"
cp Packaging/Kinetic-Info.plist "$APP/Contents/Info.plist"
cp Packaging/KineticAgent-Info.plist "$AGENT/Contents/Info.plist"
cp Packaging/com.andremarques.kinetic.agent.plist "$APP/Contents/Library/LaunchAgents/"
cp Packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
echo -n "APPL????" > "$APP/Contents/PkgInfo"
echo -n "APPL????" > "$AGENT/Contents/PkgInfo"

echo "▶ codesign ($SIGN_ID)"
OPTS=(--force --timestamp=none)
[[ "$SIGN_ID" != "-" ]] && OPTS=(--force --timestamp --options runtime)
codesign "${OPTS[@]}" --sign "$SIGN_ID" "$AGENT/Contents/Frameworks/libKineticMenuBar.dylib"
codesign "${OPTS[@]}" --sign "$SIGN_ID" --identifier com.andremarques.kinetic.agent "$AGENT"
codesign "${OPTS[@]}" --sign "$SIGN_ID" --identifier com.andremarques.kinetic "$APP"
codesign --verify --deep --strict "$APP" && echo "✓ signature OK"

echo
echo "Built $APP"
echo "Run:   open $APP"
echo "Logs:  log stream --predicate 'process == \"KineticAgent\"' --style compact"
