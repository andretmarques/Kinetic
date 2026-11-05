#!/bin/zsh
# Publishes a new version: Scripts/release.sh alpha-1.1, or 1.0.0 (tagged v1.0.0)
# First write ReleaseNotes/<version>.md: a "# Codename" line, then the highlights.
# Sets the version, commits it, tags it and pushes. GitHub Actions then tests, builds and
# publishes the DMG, which becomes the direct download in the README.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
TAG="$VERSION"
[[ "$VERSION" == [0-9]* ]] && TAG="v$VERSION"
PLISTS=(Packaging/Kinetic-Info.plist Packaging/KineticAgent-Info.plist)

fail() {
    echo "✗ $1" >&2
    exit 1
}

[[ "$VERSION" =~ '^((alpha|beta)-[0-9]+(\.[0-9]+)*|[0-9]+\.[0-9]+\.[0-9]+)$' ]] \
    || fail "Usage: Scripts/release.sh alpha-1.0, or 1.2.3"
[[ "$(git branch --show-current)" == main ]] || fail "Releases are made from main."
[[ -f "ReleaseNotes/$VERSION.md" ]] || fail "Write ReleaseNotes/$VERSION.md first: a \"# Codename\" line, then the highlights."
[[ -z "$(git status --porcelain)" ]] || fail "Commit or stash your changes first."

git fetch --quiet --tags origin
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail "main isn't in sync with origin/main."
git rev-parse --quiet --verify "refs/tags/$TAG" >/dev/null && fail "$TAG already exists."

CURRENT=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "${PLISTS[1]}")
if [[ "$VERSION" != "$CURRENT" ]]; then
    BUILD=$(( $(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "${PLISTS[1]}") + 1 ))
    for plist in $PLISTS; do
        sed -i '' -E \
            -e "s#(<key>CFBundleShortVersionString</key><string>)[^<]*#\1$VERSION#" \
            -e "s#(<key>CFBundleVersion</key><string>)[^<]*#\1$BUILD#" \
            "$plist"
    done
    git add $PLISTS
    git commit --quiet -m "Release $VERSION"
fi

git tag -a "$TAG" -m "Kinetic $VERSION"
git push --quiet --atomic origin main "$TAG"

echo "✓ Pushed $TAG. Follow the build with: gh run watch"
