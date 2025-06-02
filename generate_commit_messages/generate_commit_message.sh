#!/usr/bin/env bash
set -e

ROOT_DIR=~/experiments/local_llms

PY_SCRIPT="$ROOT_DIR/generate_commit_messages/generate_commit_message.py"

if [ ! -f "$PY_SCRIPT" ]; then
  echo "❌ Python commit message generation script not found at $PY_SCRIPT"
  exit 1
fi

# Get git diff (unstaged or staged)
diff_output=$(git diff)
if [[ -z "$diff_output" ]]; then
  diff_output=$(git diff --cached)
fi

if [[ -z "$diff_output" ]]; then
  echo "No changes detected in git diff (unstaged or staged). Please provide input manually:"
  echo "Press Ctrl+D when done."
  diff_output=$(cat)  # read from stdin
fi
# Pass the diff or input to the python script via stdin
echo "$diff_output" | python3 "$PY_SCRIPT"
