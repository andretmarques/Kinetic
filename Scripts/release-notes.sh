#!/bin/zsh
# Writes a release's title or description from ReleaseNotes/<version>.md and the commit history.
#
#   Scripts/release-notes.sh title alpha-1.0
#   NOTARIZED=1 Scripts/release-notes.sh body alpha-1.0
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="$1"
TAG="$2"
VERSION="${TAG#v}"
NOTES="ReleaseNotes/$VERSION.md"
REPOSITORY="https://github.com/andretmarques/Kinetic"

[[ -f "$NOTES" ]] || { echo "✗ $NOTES not found." >&2; exit 1; }
CODENAME="$(head -1 "$NOTES" | sed -E 's/^#[[:space:]]*//')"

print_commits() {
    local previous
    previous="$(git describe --tags --abbrev=0 "$TAG^" 2>/dev/null)" || return 0
    local commits
    commits="$(git log "$previous..$TAG" --no-merges --invert-grep --grep='^Release ' --format='- %s')"
    [[ -n "$commits" ]] || return 0
    echo
    echo "## What's changed"
    echo
    echo "$commits"
    echo
    echo "[Compare with $previous]($REPOSITORY/compare/$previous...$TAG)"
}

print_install() {
    echo
    echo "## Install"
    echo
    echo "1. [Download \`Kinetic.dmg\`]($REPOSITORY/releases/download/$TAG/Kinetic.dmg), open it and drag **Kinetic** to **Applications**."
    if [[ -z "${NOTARIZED:-}" ]]; then
        echo '2. This build isn'"'"'t notarized, so clear the download flag in Terminal: `xattr -dr com.apple.quarantine /Applications/Kinetic.app`'
        echo "3. Open Kinetic, then turn on **Kinetic Agent** under **Accessibility** and **Input Monitoring**."
    else
        echo "2. Open Kinetic, then turn on **Kinetic Agent** under **Accessibility** and **Input Monitoring**."
    fi
    echo
    echo "Requires macOS 26 or later. Runs on Apple silicon and Intel."
}

case "$MODE" in
    title)
        echo "Kinetic $VERSION · $CODENAME"
        ;;
    body)
        tail -n +2 "$NOTES" | sed '/./,$!d'
        print_commits
        print_install
        ;;
    *)
        echo "Usage: Scripts/release-notes.sh title|body <tag>" >&2
        exit 1
        ;;
esac
