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

# The [Skills] list must mention both shipped skills, not just teach.
SKILLS_MSG=$(echo "$OUTPUT" | jq -r '.systemMessage')
if ! echo "$SKILLS_MSG" | grep -q "teach"; then
  echo "FAIL: expected banner skills list to mention 'teach', got: $OUTPUT"
  exit 1
fi
if ! echo "$SKILLS_MSG" | grep -q "goal"; then
  echo "FAIL: expected banner skills list to mention 'goal', got: $OUTPUT"
  exit 1
fi
echo "PASS: banner skills list mentions both teach and goal"

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

# Case 5: malformed config -> banner still shows, no crash. The banner only
# checks the config file's *presence* (a plain `[ -f ... ]` test, no jq call
# on its content), so a syntax error inside the file can't crash it — that
# risk lives in resolve-config.sh, exercised separately when the skill
# actually reads the config, not in this cosmetic presence check.
mkdir -p "$TMP/malformed"
printf '{"vault": broken' > "$TMP/malformed/socrates.config.json"
OUTPUT=$(printf '{"cwd": "%s"}' "$TMP/malformed" | env HOME="$ISOLATED_HOME" "$BANNER" 2>/dev/null || true)
if ! echo "$OUTPUT" | jq -r '.systemMessage' | grep -q "socrates v" 2>/dev/null; then
  echo "FAIL: expected banner to still show (and not crash) for a malformed-but-present config, got: $OUTPUT"
  exit 1
fi
echo "PASS: shows (without crashing) when the local config file is malformed, since presence alone is checked"

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

# Case 7: no local config/notes folder, but a global ~/socrates.config.json
# is set up -> still SILENT. The banner is deliberately local-only: a
# SessionStart hook fires before the user types anything, so it can't know
# whether /socrates:teach will be used this session, and a global config
# making every directory "active" would mean this banner fires in every
# Claude Code session on the machine, not just Socrates ones. Note-saving
# via resolve-config.sh's own global fallback is unaffected by this.
FAKE_HOME="$TMP/fakehome"
mkdir -p "$FAKE_HOME"
cat > "$FAKE_HOME/socrates.config.json" <<'EOF'
{"vault": "/tmp/global-vault", "notesRoot": "Resources"}
EOF
ANYWHERE="$TMP/anywhere-unrelated"
mkdir -p "$ANYWHERE"
OUTPUT=$(printf '{"cwd": "%s"}' "$ANYWHERE" | env HOME="$FAKE_HOME" "$BANNER")
if [ -n "$OUTPUT" ]; then
  echo "FAIL: expected silence in an unrelated dir even with a global config configured, got: $OUTPUT"
  exit 1
fi
echo "PASS: still silent in an unrelated dir when only a global config exists (no local trace)"

echo "ALL TESTS PASSED"
