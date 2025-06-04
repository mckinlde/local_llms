#!/usr/bin/env bash
set -euo pipefail

# === Usage ===
# ./render-template.sh template.json output.json
# or:
# VAR1=value VAR2=value ./render-template.sh template.json

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <template.json> [output.json]"
  exit 1
fi

TEMPLATE_FILE="$1"
OUTPUT_FILE="${2:-/dev/stdout}"

if ! command -v envsubst >/dev/null; then
  echo "Error: 'envsubst' is not installed. Try 'sudo apt install gettext' or 'nix-shell -p gettext'."
  exit 2
fi

# Render the file
envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"