#!/usr/bin/env bash
set -e

# Path setup
LLAMA_BIN=~/experiments/local_llms/llama.cpp/build/bin/llama-cli

MODEL=~/experiments/local_llms/models/commit-message-7b-v1.0-q4.gguf

if [ ! -f "$LLAMA_BIN" ]; then
  echo "❌ llama.cpp binary not found at $LLAMA_BIN. Run manual_make.sh first."
  exit 1
fi

if [ ! -f "$MODEL" ]; then
  echo "❌ Model file not found at $MODEL. Run download_commit_model.sh first."
  exit 1
fi

# Get input (file or stdin)
if [ -n "$1" ]; then
  INPUT_TEXT=$(<"$1")
else
  echo "Paste your git diff or error message (Ctrl+D to finish):"
  INPUT_TEXT=$(cat)
fi

# Prompt template
PROMPT="<commit_message>\n$INPUT_TEXT\n"

# Call llama.cpp
echo "🧠 Generating commit message..."
"$LLAMA_BIN" \
  --model "$MODEL" \
  --n-predict 64 \
  --prompt "$PROMPT" \
  --color \
  --temp 0.7 \
  --repeat_penalty 1.2