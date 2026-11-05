#!/bin/zsh
# Uploads the signing and notarization values in release-secrets.env to GitHub Actions secrets.
# Values are piped to gh, so they never appear in the command line or the output.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="andretmarques/Kinetic"
FILE="release-secrets.env"

fail() {
    echo "✗ $1" >&2
    exit 1
}

[[ -f "$FILE" ]] || fail "$FILE not found."

typeset -A values
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    values[${line%%=*}]="${line#*=}"
done < "$FILE"

for name in MAC_CERT_P12_PATH MAC_CERT_PASSWORD NOTARY_APPLE_ID NOTARY_TEAM_ID NOTARY_PASSWORD; do
    value="${values[$name]:-}"
    [[ -n "$value" && "$value" != PLACEHOLDER* ]] || fail "$name isn't filled in."
done

certificate="${values[MAC_CERT_P12_PATH]/#\~/$HOME}"
[[ -f "$certificate" ]] || fail "No certificate at MAC_CERT_P12_PATH. Check the path."
[[ "${values[NOTARY_TEAM_ID]}" =~ '^[A-Z0-9]{10}$' ]] || fail "NOTARY_TEAM_ID should be 10 capital letters and digits."
[[ "${values[NOTARY_APPLE_ID]}" == *@* ]] || fail "NOTARY_APPLE_ID should be an email address."

base64 -i "$certificate" | gh secret set MAC_CERT_P12 -R "$REPO"
for name in MAC_CERT_PASSWORD NOTARY_APPLE_ID NOTARY_TEAM_ID NOTARY_PASSWORD; do
    printf '%s' "${values[$name]}" | gh secret set "$name" -R "$REPO"
done

echo
gh secret list -R "$REPO"
echo
echo "✓ Uploaded. Now delete $FILE and the .p12 file."
