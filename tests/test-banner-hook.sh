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
if ! echo "$OUTPUT" | jq empty 2>/dev/null; then
  echo "FAIL: expected valid JSON, got: $OUTPUT"
  exit 1
fi
if ! echo "$OUTPUT" | jq -r '.systemMessage' | grep -q "socrates v"; then
  echo "FAIL: expected banner with version in systemMessage, got: $OUTPUT"
  exit 1
fi
echo "PASS: banner shown when socrates.config.json present (valid JSON with systemMessage)"

# Case 3: fallback socrates-notes/ folder present -> banner shown
mkdir -p "$TMP/withnotes/socrates-notes"
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP/withnotes" | "$BANNER")
if ! echo "$OUTPUT" | jq empty 2>/dev/null; then
  echo "FAIL: expected valid JSON, got: $OUTPUT"
  exit 1
fi
if ! echo "$OUTPUT" | jq -r '.systemMessage' | grep -q "socrates v"; then
  echo "FAIL: expected banner with version in systemMessage, got: $OUTPUT"
  exit 1
fi
echo "PASS: banner shown when socrates-notes/ already exists (valid JSON with systemMessage)"

# Case 4: jq missing -> silent, no crash
FAKE_BIN="$TMP/fakebin"
mkdir -p "$FAKE_BIN"
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP/withconfig" | env PATH="$FAKE_BIN" "$BANNER" 2>/dev/null || true)
if [ -n "$OUTPUT" ]; then
  echo "FAIL: expected silent output when jq is missing, got: $OUTPUT"
  exit 1
fi
echo "PASS: silent when jq is missing"

# Case 5: malformed config -> silent, no crash (not the caller's problem to see a jq stack trace)
mkdir -p "$TMP/malformed"
printf '{"vault": broken' > "$TMP/malformed/socrates.config.json"
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP/malformed" | "$BANNER" 2>/dev/null || true)
if [ -n "$OUTPUT" ]; then
  echo "FAIL: expected silent output for malformed config, got: $OUTPUT"
  exit 1
fi
echo "PASS: silent (not crashing) when config is malformed"

# Case 6: config present without a vault key -> still recognized as an active workspace
mkdir -p "$TMP/novault"
cat > "$TMP/novault/socrates.config.json" <<'EOF'
{"notesRoot": "Resources"}
EOF
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP/novault" | "$BANNER")
if ! echo "$OUTPUT" | jq -r '.systemMessage' | grep -q "socrates v"; then
  echo "FAIL: expected banner when config file exists even without a vault key, got: $OUTPUT"
  exit 1
fi
echo "PASS: banner shown when config file exists even without a vault key"

echo "ALL TESTS PASSED"
