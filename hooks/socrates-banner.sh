#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  exit 0
fi

CONFIG_INFO=$("$PLUGIN_ROOT/scripts/resolve-config.sh" "$CWD")
SOURCE=$(echo "$CONFIG_INFO" | jq -r '.source')

HAS_NOTES_FOLDER=false
if [ -d "$CWD/socrates-notes" ]; then
  HAS_NOTES_FOLDER=true
fi

if [ "$SOURCE" != "config" ] && [ "$HAS_NOTES_FOLDER" != "true" ]; then
  exit 0
fi

VERSION=$(jq -r '.version // "0.0.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json")

cat <<BANNER

   ██████████████████
 ██████████████████████
   ██  ██  ██  ██  ██
   ██  ██  ██  ██  ██
   ██  ██  ██  ██  ██
 ██████████████████████
   ██████████████████

socrates v$VERSION

[Skills]
  teach

Linked: $CWD
BANNER
