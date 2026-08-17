#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BANNER="$SCRIPT_DIR/../hooks/socrates-banner.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Case 1: unrelated directory -> silent
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP" | "$BANNER")
if [ -n "$OUTPUT" ]; then
  echo "FAIL: expected no banner output for unrelated cwd, got: $OUTPUT"
  exit 1
fi
echo "PASS: silent outside a Socrates workspace"

# Case 2: socrates.config.json present -> banner shown
mkdir -p "$TMP/withconfig"
cat > "$TMP/withconfig/socrates.config.json" <<'EOF'
{"vault": "/tmp/vault", "notesRoot": "Resources"}
EOF
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP/withconfig" | "$BANNER")
if ! echo "$OUTPUT" | grep -q "socrates v"; then
  echo "FAIL: expected banner with version, got: $OUTPUT"
  exit 1
fi
echo "PASS: banner shown when socrates.config.json present"

# Case 3: fallback socrates-notes/ folder present -> banner shown
mkdir -p "$TMP/withnotes/socrates-notes"
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP/withnotes" | "$BANNER")
if ! echo "$OUTPUT" | grep -q "socrates v"; then
  echo "FAIL: expected banner with version, got: $OUTPUT"
  exit 1
fi
echo "PASS: banner shown when socrates-notes/ already exists"

echo "ALL TESTS PASSED"
