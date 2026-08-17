#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVE="$SCRIPT_DIR/../scripts/resolve-config.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Isolate HOME for every case below so a real ~/socrates.config.json on the
# machine running these tests (a legitimate, expected file once this
# feature is in use) can never leak into a test's expected result.
ISOLATED_HOME="$TMP/isolated-home"
mkdir -p "$ISOLATED_HOME"

# Case 1: no config file present -> fallback
OUTPUT=$(env HOME="$ISOLATED_HOME" "$RESOLVE" "$TMP")
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
OUTPUT=$(env HOME="$ISOLATED_HOME" "$RESOLVE" "$TMP")
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
OUTPUT=$(env HOME="$ISOLATED_HOME" "$RESOLVE" "$TMP")
NOTES_ROOT=$(echo "$OUTPUT" | jq -r '.notesRoot')
if [ "$NOTES_ROOT" != "Resources" ]; then
  echo "FAIL: expected default notesRoot 'Resources', got '$NOTES_ROOT'"
  exit 1
fi
echo "PASS: defaults notesRoot to Resources"

# Case 3b: notesRoot present but an empty string -> also defaults to "Resources"
cat > "$TMP/socrates.config.json" <<'EOF'
{"vault": "/Users/test/vault", "notesRoot": ""}
EOF
OUTPUT=$(env HOME="$ISOLATED_HOME" "$RESOLVE" "$TMP")
NOTES_ROOT=$(echo "$OUTPUT" | jq -r '.notesRoot')
if [ "$NOTES_ROOT" != "Resources" ]; then
  echo "FAIL: expected empty notesRoot to default to 'Resources', got '$NOTES_ROOT'"
  exit 1
fi
echo "PASS: defaults notesRoot to Resources when explicitly empty"
rm -f "$TMP/socrates.config.json"

# Case 4: jq missing -> distinct non-zero exit, no stdout, no silent success
FAKE_BIN="$TMP/fakebin"
mkdir -p "$FAKE_BIN"
set +e
OUTPUT=$(env HOME="$ISOLATED_HOME" PATH="$FAKE_BIN" "$RESOLVE" "$TMP" 2>"$TMP/resolve-nojq-err")
STATUS=$?
set -e
ERR=$(cat "$TMP/resolve-nojq-err")
if [ "$STATUS" -eq 0 ]; then
  echo "FAIL: expected non-zero exit when jq is missing, got 0"
  exit 1
fi
if [ -n "$OUTPUT" ]; then
  echo "FAIL: expected no stdout when jq is missing, got: $OUTPUT"
  exit 1
fi
if ! echo "$ERR" | grep -qi "jq is required"; then
  echo "FAIL: expected a clear 'jq is required' error, got: $ERR"
  exit 1
fi
echo "PASS: fails clearly (not silently) when jq is missing"

# Case 5: malformed config.json -> distinct non-zero exit with a clear message
mkdir -p "$TMP/malformed"
printf '{"vault": broken' > "$TMP/malformed/socrates.config.json"
set +e
OUTPUT=$(env HOME="$ISOLATED_HOME" "$RESOLVE" "$TMP/malformed" 2>"$TMP/resolve-malformed-err")
STATUS=$?
set -e
ERR=$(cat "$TMP/resolve-malformed-err")
if [ "$STATUS" -eq 0 ]; then
  echo "FAIL: expected non-zero exit for malformed config, got 0"
  exit 1
fi
if ! echo "$ERR" | grep -qi "not valid JSON"; then
  echo "FAIL: expected a clear 'not valid JSON' error, got: $ERR"
  exit 1
fi
echo "PASS: malformed config fails clearly instead of crashing silently"

# Case 6: no local config, but a global ~/socrates.config.json exists -> used
FAKE_HOME="$TMP/fakehome"
mkdir -p "$FAKE_HOME"
cat > "$FAKE_HOME/socrates.config.json" <<'EOF'
{"vault": "/Users/test/global-vault", "notesRoot": "GlobalNotes"}
EOF
NOLOCAL="$TMP/nolocal"
mkdir -p "$NOLOCAL"
OUTPUT=$(env HOME="$FAKE_HOME" "$RESOLVE" "$NOLOCAL")
EXPECTED='{"vault": "/Users/test/global-vault", "notesRoot": "GlobalNotes", "source": "config"}'
if [ "$(echo "$OUTPUT" | jq -c -S .)" != "$(echo "$EXPECTED" | jq -c -S .)" ]; then
  echo "FAIL: expected global config output, got: $OUTPUT"
  exit 1
fi
echo "PASS: falls back to global ~/socrates.config.json when no local config exists"

# Case 7: local config present AND global config present -> local wins
LOCALOVERRIDE="$TMP/localoverride"
mkdir -p "$LOCALOVERRIDE"
cat > "$LOCALOVERRIDE/socrates.config.json" <<'EOF'
{"vault": "/Users/test/local-vault", "notesRoot": "LocalNotes"}
EOF
OUTPUT=$(env HOME="$FAKE_HOME" "$RESOLVE" "$LOCALOVERRIDE")
EXPECTED='{"vault": "/Users/test/local-vault", "notesRoot": "LocalNotes", "source": "config"}'
if [ "$(echo "$OUTPUT" | jq -c -S .)" != "$(echo "$EXPECTED" | jq -c -S .)" ]; then
  echo "FAIL: expected local config to win over global, got: $OUTPUT"
  exit 1
fi
echo "PASS: local config takes precedence over global"

# Case 8: local config WITHOUT a vault + global config with one -> the
# incomplete local config must not shadow the working global one
NOVAULT="$TMP/novault"
mkdir -p "$NOVAULT"
cat > "$NOVAULT/socrates.config.json" <<'EOF'
{"notesRoot": "LocalNotes"}
EOF
OUTPUT=$(env HOME="$FAKE_HOME" "$RESOLVE" "$NOVAULT")
EXPECTED='{"vault": "/Users/test/global-vault", "notesRoot": "GlobalNotes", "source": "config"}'
if [ "$(echo "$OUTPUT" | jq -c -S .)" != "$(echo "$EXPECTED" | jq -c -S .)" ]; then
  echo "FAIL: expected vault-less local config to fall through to global, got: $OUTPUT"
  exit 1
fi
echo "PASS: vault-less local config falls through to global instead of shadowing it"

# Case 9: local config without a vault and no global -> plain fallback
OUTPUT=$(env HOME="$ISOLATED_HOME" "$RESOLVE" "$NOVAULT")
EXPECTED='{"vault": null, "notesRoot": "socrates-notes", "source": "none"}'
if [ "$(echo "$OUTPUT" | jq -c -S .)" != "$(echo "$EXPECTED" | jq -c -S .)" ]; then
  echo "FAIL: expected fallback for vault-less config with no global, got: $OUTPUT"
  exit 1
fi
echo "PASS: vault-less config with no global falls back to socrates-notes"

echo "ALL TESTS PASSED"
