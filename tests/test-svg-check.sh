#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVG_CHECK="$SCRIPT_DIR/../scripts/svg-check.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/sample.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
  <rect width="10" height="10" fill="black"/>
</svg>
EOF

OUTPUT_PATH=$("$SVG_CHECK" "$TMP/sample.svg" "$TMP/sample.png")
if [ "$OUTPUT_PATH" != "$TMP/sample.png" ]; then
  echo "FAIL: expected output path $TMP/sample.png, got $OUTPUT_PATH"
  exit 1
fi
if [ ! -s "$TMP/sample.png" ]; then
  echo "FAIL: PNG was not created or is empty"
  exit 1
fi
echo "PASS: valid SVG converts to non-empty PNG"

set +e
"$SVG_CHECK" "$TMP/does-not-exist.svg" "$TMP/out2.png" 2>"$TMP/err.log"
STATUS=$?
set -e
if [ "$STATUS" -eq 0 ]; then
  echo "FAIL: expected non-zero exit for missing input"
  exit 1
fi
if ! grep -q "not found" "$TMP/err.log"; then
  echo "FAIL: expected 'not found' error message, got: $(cat "$TMP/err.log")"
  exit 1
fi
echo "PASS: missing input fails with clear error"

echo "ALL TESTS PASSED"
