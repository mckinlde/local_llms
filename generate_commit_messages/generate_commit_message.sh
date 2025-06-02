#!/usr/bin/env bash
set -e

ROOT_DIR=~/experiments/local_llms

PY_SCRIPT="$ROOT_DIR/generate_commit_messages/generate_commit_message.py"

if [ ! -f "$PY_SCRIPT" ]; then
  echo "❌ Python commit message generation script not found at $PY_SCRIPT"
  exit 1
fi

if [ -n "$1" ]; then
  cat "$1" | python3 "$PY_SCRIPT"
else
  echo "Paste your git diff or error message (Ctrl+D to finish):"
  cat | python3 "$PY_SCRIPT"
fi
