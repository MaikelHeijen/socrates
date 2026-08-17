#!/bin/bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not found on PATH. Install it (e.g. brew install jq)." >&2
  exit 2
fi

TARGET_DIR="${1:-$PWD}"
CONFIG_FILE="$TARGET_DIR/socrates.config.json"
GLOBAL_CONFIG_FILE="$HOME/socrates.config.json"

# A config in the current directory always overrides the global default,
# so a per-project setup still works even with a global one in place.
if [ ! -f "$CONFIG_FILE" ] && [ -f "$GLOBAL_CONFIG_FILE" ]; then
  CONFIG_FILE="$GLOBAL_CONFIG_FILE"
fi

if [ -f "$CONFIG_FILE" ]; then
  if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "Error: socrates.config.json is not valid JSON: $CONFIG_FILE" >&2
    exit 3
  fi
  VAULT=$(jq -r '.vault // empty' "$CONFIG_FILE")
  NOTES_ROOT=$(jq -r '.notesRoot // empty' "$CONFIG_FILE")
  if [ -z "$NOTES_ROOT" ]; then
    NOTES_ROOT="Resources"
  fi
  if [ -z "$VAULT" ]; then
    echo '{"vault": null, "notesRoot": "socrates-notes", "source": "none"}'
    exit 0
  fi
  jq -n --arg vault "$VAULT" --arg notesRoot "$NOTES_ROOT" \
    '{vault: $vault, notesRoot: $notesRoot, source: "config"}'
else
  echo '{"vault": null, "notesRoot": "socrates-notes", "source": "none"}'
fi
