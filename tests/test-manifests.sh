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

HOOKS_JSON="$ROOT/hooks/hooks.json"
if ! jq -e '.hooks.SessionStart' "$HOOKS_JSON" >/dev/null 2>&1; then
  echo "FAIL: hooks.json must wrap event names in a top-level 'hooks' key"
  exit 1
fi
echo "PASS: hooks.json has the required top-level 'hooks' wrapper"

if jq -e 'has("hooks")' "$PLUGIN_JSON" >/dev/null 2>&1; then
  echo "FAIL: plugin.json must NOT declare a 'hooks' field (it collides with hooks/hooks.json auto-discovery and breaks hook loading)"
  exit 1
fi
echo "PASS: plugin.json does not redeclare the hooks field"

HOOK_SCRIPT="$ROOT/hooks/socrates-banner.sh"
if [ ! -x "$HOOK_SCRIPT" ]; then
  echo "FAIL: hooks/socrates-banner.sh must exist and be executable"
  exit 1
fi
echo "PASS: hook script exists and is executable"

SKILL_FILE="$ROOT/skills/teach/SKILL.md"
if ! grep -q "^name: teach$" "$SKILL_FILE"; then
  echo "FAIL: skills/teach/SKILL.md must declare 'name: teach' in its frontmatter"
  exit 1
fi
echo "PASS: teach skill frontmatter declares its name"

echo "ALL TESTS PASSED"
