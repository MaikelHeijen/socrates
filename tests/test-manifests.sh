#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."

PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
MARKETPLACE_JSON="$ROOT/.claude-plugin/marketplace.json"

jq empty "$PLUGIN_JSON"
echo "PASS: plugin.json is valid JSON"

NAME=$(jq -r '.name' "$PLUGIN_JSON")
if [ "$NAME" != "socrates" ]; then
  echo "FAIL: expected plugin name 'socrates', got '$NAME'"
  exit 1
fi
echo "PASS: plugin.json has correct name"

VERSION=$(jq -r '.version' "$PLUGIN_JSON")
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
  echo "FAIL: plugin.json is missing a version field"
  exit 1
fi
echo "PASS: plugin.json has a version"

jq empty "$MARKETPLACE_JSON"
echo "PASS: marketplace.json is valid JSON"

PLUGIN_SOURCE=$(jq -r '.plugins[0].source' "$MARKETPLACE_JSON")
if [ "$PLUGIN_SOURCE" != "./" ]; then
  echo "FAIL: expected plugin source './', got '$PLUGIN_SOURCE'"
  exit 1
fi
echo "PASS: marketplace.json points to plugin root"

echo "ALL TESTS PASSED"
