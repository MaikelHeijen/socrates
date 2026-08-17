#!/bin/bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not found on PATH. Install it (e.g. brew install jq)." >&2
  exit 2
fi

TARGET_DIR="${1:-$PWD}"

# Candidates in precedence order: a config in the target directory wins over
# the global one. A config that exists but has no "vault" key is incomplete;
# it falls through to the next candidate instead of shadowing it. Its
# notesRoot is ignored too: notesRoot only has meaning inside a vault, and
# the no-vault fallback always uses ./socrates-notes/.
for CONFIG_FILE in "$TARGET_DIR/socrates.config.json" "$HOME/socrates.config.json"; do
  [ -f "$CONFIG_FILE" ] || continue
  if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "Error: socrates.config.json is not valid JSON: $CONFIG_FILE" >&2
    exit 3
  fi
  VAULT=$(jq -r '.vault // empty' "$CONFIG_FILE")
  [ -n "$VAULT" ] || continue
  NOTES_ROOT=$(jq -r '.notesRoot // empty' "$CONFIG_FILE")
  if [ -z "$NOTES_ROOT" ]; then
    NOTES_ROOT="Resources"
  fi
  jq -n --arg vault "$VAULT" --arg notesRoot "$NOTES_ROOT" \
    '{vault: $vault, notesRoot: $notesRoot, source: "config"}'
  exit 0
done

echo '{"vault": null, "notesRoot": "socrates-notes", "source": "none"}'
