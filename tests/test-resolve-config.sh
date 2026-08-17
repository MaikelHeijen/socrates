#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVE="$SCRIPT_DIR/../scripts/resolve-config.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Case 1: no config file present -> fallback
OUTPUT=$("$RESOLVE" "$TMP")
EXPECTED='{"vault": null, "notesRoot": "socrates-notes", "source": "none"}'
if [ "$(echo "$OUTPUT" | jq -c -S .)" != "$(echo "$EXPECTED" | jq -c -S .)" ]; then
  echo "FAIL: expected fallback output, got: $OUTPUT"
  exit 1
fi
echo "PASS: fallback when no config"

# Case 2: config file present with vault + notesRoot
cat > "$TMP/socrates.config.json" <<'EOF'
{"vault": "/Users/test/vault", "notesRoot": "Resources"}
EOF
OUTPUT=$("$RESOLVE" "$TMP")
EXPECTED='{"vault": "/Users/test/vault", "notesRoot": "Resources", "source": "config"}'
if [ "$(echo "$OUTPUT" | jq -c -S .)" != "$(echo "$EXPECTED" | jq -c -S .)" ]; then
  echo "FAIL: expected config output, got: $OUTPUT"
  exit 1
fi
echo "PASS: reads config when present"

# Case 3: config file present without notesRoot -> default to "Resources"
cat > "$TMP/socrates.config.json" <<'EOF'
{"vault": "/Users/test/vault"}
EOF
OUTPUT=$("$RESOLVE" "$TMP")
NOTES_ROOT=$(echo "$OUTPUT" | jq -r '.notesRoot')
if [ "$NOTES_ROOT" != "Resources" ]; then
  echo "FAIL: expected default notesRoot 'Resources', got '$NOTES_ROOT'"
  exit 1
fi
echo "PASS: defaults notesRoot to Resources"

echo "ALL TESTS PASSED"
