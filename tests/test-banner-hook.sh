#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BANNER="$SCRIPT_DIR/../hooks/socrates-banner.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Isolate HOME for every case below so a real ~/socrates.config.json on the
# machine running these tests (a legitimate, expected file once someone
# actually uses the global-config feature) can never leak into a test's
# expected result.
ISOLATED_HOME="$TMP/isolated-home"
mkdir -p "$ISOLATED_HOME"

# Case 1: unrelated directory, no config anywhere -> silent
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP" | env HOME="$ISOLATED_HOME" "$BANNER")
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
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP/withconfig" | env HOME="$ISOLATED_HOME" "$BANNER")
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
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP/withnotes" | env HOME="$ISOLATED_HOME" "$BANNER")
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
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP/withconfig" | env HOME="$ISOLATED_HOME" PATH="$FAKE_BIN" "$BANNER" 2>/dev/null || true)
if [ -n "$OUTPUT" ]; then
  echo "FAIL: expected silent output when jq is missing, got: $OUTPUT"
  exit 1
fi
echo "PASS: silent when jq is missing"

# Case 5: malformed config -> silent, no crash (not the caller's problem to see a jq stack trace)
mkdir -p "$TMP/malformed"
printf '{"vault": broken' > "$TMP/malformed/socrates.config.json"
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP/malformed" | env HOME="$ISOLATED_HOME" "$BANNER" 2>/dev/null || true)
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
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP/novault" | env HOME="$ISOLATED_HOME" "$BANNER")
if ! echo "$OUTPUT" | jq -r '.systemMessage' | grep -q "socrates v"; then
  echo "FAIL: expected banner when config file exists even without a vault key, got: $OUTPUT"
  exit 1
fi
echo "PASS: banner shown when config file exists even without a vault key"

# Case 7: no local config anywhere, but a global ~/socrates.config.json is
# set up -> banner still shows, since the global config makes every
# directory an active workspace for note-saving purposes.
FAKE_HOME="$TMP/fakehome"
mkdir -p "$FAKE_HOME"
cat > "$FAKE_HOME/socrates.config.json" <<'EOF'
{"vault": "/tmp/global-vault", "notesRoot": "Resources"}
EOF
ANYWHERE="$TMP/anywhere-unrelated"
mkdir -p "$ANYWHERE"
OUTPUT=$(printf '{"cwd": "%s"}' "$ANYWHERE" | env HOME="$FAKE_HOME" "$BANNER")
if ! echo "$OUTPUT" | jq -r '.systemMessage' | grep -q "socrates v"; then
  echo "FAIL: expected banner in an unrelated dir when a global config is set up, got: $OUTPUT"
  exit 1
fi
echo "PASS: banner shown anywhere once a global ~/socrates.config.json is configured"

echo "ALL TESTS PASSED"
