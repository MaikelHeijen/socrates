#!/bin/bash
set -euo pipefail

TARGET_DIR="${1:-$PWD}"
CONFIG_FILE="$TARGET_DIR/socrates.config.json"

if [ -f "$CONFIG_FILE" ]; then
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
