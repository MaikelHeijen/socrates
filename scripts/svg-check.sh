#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: svg-check.sh <input.svg> <output.png>" >&2
  exit 1
fi

INPUT="$1"
OUTPUT="$2"

if [ ! -f "$INPUT" ]; then
  echo "Error: input SVG not found: $INPUT" >&2
  exit 1
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "Error: rsvg-convert not found. Install it with: brew install librsvg" >&2
  exit 1
fi

ERR_LOG=$(mktemp)
if ! rsvg-convert "$INPUT" -o "$OUTPUT" 2>"$ERR_LOG"; then
  echo "Error: rsvg-convert failed: $(cat "$ERR_LOG")" >&2
  rm -f "$ERR_LOG"
  exit 1
fi
rm -f "$ERR_LOG"

if [ ! -s "$OUTPUT" ]; then
  echo "Error: output PNG is empty or missing: $OUTPUT" >&2
  exit 1
fi

echo "$OUTPUT"
