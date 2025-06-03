#!/usr/bin/env bash

set -euo pipefail

# === Default Config ===
CTX_SIZE=2048
DEBUG=false
DRY_RUN=false
PREFIX=""

# === Parse Flags ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ctx)
      case "$2" in
        small)   CTX_SIZE=2048  ;;
        medium)  CTX_SIZE=4096  ;;
        large)   CTX_SIZE=16384 ;;
        *) echo "Unknown ctx size preset: $2"; exit 1;;
      esac
      shift 2
      ;;
    --debug)
      DEBUG=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --prefix)
      PREFIX="$2"
      shift 2
      ;;
    *) echo "Unknown argument: $1"; exit 1;;
  esac
done

# === Setup Variables ===
LLAMA_CLI="llama-cli"
MODEL_PATH="/path/to/your/model.gguf"

# === Get Diff and Estimate Token Count ===
DIFF=$(git diff --cached)
EST_TOKEN_COUNT=$(echo "$DIFF" | wc -w)
MAX_TOKENS=$((CTX_SIZE - 128))  # reserve 128 tokens for output

if (( EST_TOKEN_COUNT > MAX_TOKENS )); then
  echo "⚠️  Truncating input from ~${EST_TOKEN_COUNT} to ${MAX_TOKENS} words..." >&2
  DIFF=$(echo "$DIFF" | tr ' ' '\n' | tail -n $MAX_TOKENS | tr '\n' ' ')
fi

# === Prefix Selection ===
if [[ -z "$PREFIX" ]]; then
  echo "Select prefix type:"
  select choice in feat fix chore docs refactor test perf style revert; do
    PREFIX=$choice
    break
  done
fi

# === Construct Prompt ===
PROMPT="Generate a conventional commit message with type '$PREFIX' for the following change:\n$DIFF"

if $DEBUG; then
  echo "🔍 Debug Mode Enabled" >&2
  echo "Prefix: $PREFIX" >&2
  echo "Prompt: $PROMPT" >&2
  echo "Using context size: $CTX_SIZE" >&2
fi

# === Function to Monitor RAM ===
monitor_ram() {
  local pid=$1
  while kill -0 "$pid" 2>/dev/null; do
    mem=$(ps -o rss= -p "$pid")
    echo "🧠 RAM Usage: $((mem / 1024)) MB" >&2
    sleep 1
  done
}

# === Run Model ===
echo "🧠 Running model with ctx-size=${CTX_SIZE}..."

# Start llama-cli in background
OUTPUT_FILE=$(mktemp)
$LLAMA_CLI \
  -m "$MODEL_PATH" \
  -p "$PROMPT" \
  -n 128 \
  --temp 0.2 \
  --top-k 40 \
  --top-p 0.9 \
  --repeat-penalty 1.1 \
  --ctx-size "$CTX_SIZE" \
  > "$OUTPUT_FILE" 2>&1 &
LLAMA_PID=$!

if $DEBUG; then
  monitor_ram "$LLAMA_PID" &
fi

wait "$LLAMA_PID"
RAW_OUTPUT=$(cat "$OUTPUT_FILE")
rm "$OUTPUT_FILE"

# === Extract Message ===
COMMIT_MSG=$(echo "$RAW_OUTPUT" | head -n 1)

if $DEBUG; then
  echo "📤 Raw output: $RAW_OUTPUT" >&2
  echo "✅ Commit message: $COMMIT_MSG" >&2
fi

# === Commit or Print ===
if $DRY_RUN; then
  echo "📝 Suggested commit message: $COMMIT_MSG"
else
  git commit -m "$COMMIT_MSG"
  git push
fi
