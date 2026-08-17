#!/bin/bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null) || exit 0

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  exit 0
fi

CONFIG_INFO=$("$PLUGIN_ROOT/scripts/resolve-config.sh" "$CWD" 2>/dev/null) || exit 0
SOURCE=$(echo "$CONFIG_INFO" | jq -r '.source' 2>/dev/null) || exit 0

HAS_NOTES_FOLDER=false
if [ -d "$CWD/socrates-notes" ]; then
  HAS_NOTES_FOLDER=true
fi

HAS_CONFIG_FILE=false
if [ -f "$CWD/socrates.config.json" ]; then
  HAS_CONFIG_FILE=true
fi

if [ "$SOURCE" != "config" ] && [ "$HAS_NOTES_FOLDER" != "true" ] && [ "$HAS_CONFIG_FILE" != "true" ]; then
  exit 0
fi

VERSION=$(jq -r '.version // "0.0.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null) || VERSION="0.0.0"

# Build banner text with ANSI styling (bold cyan)
BOLD_CYAN=$(printf '\033[1m\033[36m')
RESET=$(printf '\033[0m')

# Build banner as simple string concatenation to avoid here-doc indentation issues
BANNER_TEXT="${BOLD_CYAN}"$'\n'
BANNER_TEXT+="   ██████████████████"$'\n'
BANNER_TEXT+=" ██████████████████████"$'\n'
BANNER_TEXT+="   ██  ██  ██  ██  ██"$'\n'
BANNER_TEXT+="   ██  ██  ██  ██  ██"$'\n'
BANNER_TEXT+="   ██  ██  ██  ██  ██"$'\n'
BANNER_TEXT+=" ██████████████████████"$'\n'
BANNER_TEXT+="   ██████████████████"$'\n'
BANNER_TEXT+=$'\n'"socrates v$VERSION${RESET}"$'\n'
BANNER_TEXT+=$'\n'"[Skills]"$'\n'
BANNER_TEXT+="  teach"$'\n'
BANNER_TEXT+=$'\n'"Linked: $CWD"

# Output as compact JSON with systemMessage
jq -nc --arg msg "$BANNER_TEXT" '{systemMessage: $msg}'
