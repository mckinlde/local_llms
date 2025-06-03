#!/usr/bin/env bash
set -euo pipefail

# use .gguf anywhere + generate git commits

# This script assumes you want to:

#     Copy the .gguf file to any folder.

#     Run a git commit message generator script that you have.

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <path-to-gguf-folder>"
  exit 1
fi

#     Copy the .gguf file to any folder.
GGUF_DIR="$1"
GGUF_FILE="$GGUF_DIR/merged_model.gguf"

if [ ! -f "$GGUF_FILE" ]; then
  echo "❌ No merged_model.gguf found in $GGUF_DIR"
  exit 1
fi

echo "✅ Found .gguf at $GGUF_FILE"

#     Run a git commit message generator script that you have.
# Example command: generate conventional commit messages from GGUF in this folder
# Replace with your actual commit generation command
python3 "$HOME/tools/generate_commit_messages.py" --model "$GGUF_FILE" --target-repo "$PWD"

echo "✅ Commit messages generated."
