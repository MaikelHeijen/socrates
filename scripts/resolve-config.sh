#!/bin/bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not found on PATH. Install it (e.g. brew install jq)." >&2
  exit 2
fi

TARGET_DIR="${1:-$PWD}"
CONFIG_FILE="$TARGET_DIR/socrates.config.json"

if [ -f "$CONFIG_FILE" ]; then
  if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "Error: socrates.config.json is not valid JSON: $CONFIG_FILE" >&2
    exit 3
  fi
  VAULT=$(jq -r '.vault // empty' "$CONFIG_FILE")
  NOTES_ROOT=$(jq -r '.notesRoot // "Resources"' "$CONFIG_FILE")
  if [ -z "$VAULT" ]; then
    echo '{"vault": null, "notesRoot": "socrates-notes", "source": "none"}'
    exit 0
  fi
  jq -n --arg vault "$VAULT" --arg notesRoot "$NOTES_ROOT" \
    '{vault: $vault, notesRoot: $notesRoot, source: "config"}'
else
  echo '{"vault": null, "notesRoot": "socrates-notes", "source": "none"}'
fi
