#!/usr/bin/env bash
set -euo pipefail

# === Compatibility Checks ===
# [dmei@nixos:~/experiments/local_llms/test_portability]$ grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"'
# nixos
OS_ID=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')

#[dmei@nixos:~/experiments/local_llms/test_portability]$ uname -m
#x86_64
ARCH=$(uname -m)

if [[ "$OS_ID" != "nixos" ]]; then
  echo "❌ Incompatible OS. This script is only supported on NixOS."
  exit 1
fi

if [[ "$ARCH" != "x86_64" ]]; then
  echo "❌ Incompatible architecture. This script requires x86_64."
  exit 1
fi

# === Default Config ===

# Model Settings
MAX_CTX_SIZE=8192 # Your model supports up to 8192 tokens (`n_ctx_train = 8192`). # You can go higher than 2048 if your task benefits: It will increase memory usage but allow longer prompt + completion.
CTX_SIZE=2048 # Default to a small window size, can increase it if diff is large

# Script Settings
DEBUG=false # Toggle for prompt metrics, raw model output, ctx_size changes
VERBOSE_DEBUG=false  # Toggle for every command, full prompt
DRY_RUN=false

# === Parse Flags ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ctx)
      case "$2" in
        small)   CTX_SIZE=2048  ;;
        medium)  CTX_SIZE=4096  ;;
        large)   CTX_SIZE=${MAX_CTX_SIZE} ;;
        *) echo "Unknown ctx size preset: $2, max ctx size is 8192"; exit 1;;
      esac
      shift 2
      ;;
    --debug)
      DEBUG=true
      shift
      ;;
    --debug-verbose)
      DEBUG=true
      VERBOSE_DEBUG=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *) echo "Unknown argument: $1"; exit 1;;
  esac
done

if $VERBOSE_DEBUG; then
  set -x  # Show each command being executed
fi

# === Paths ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_PATH="$SCRIPT_DIR/merged_model.gguf"
LLAMA_CLI="$SCRIPT_DIR/llama-cli"

# === Check Files Exist ===
if [[ ! -f "$MODEL_PATH" ]]; then
  echo "❌ Model not found at: $MODEL_PATH"
  exit 1
fi

if [[ ! -x "$LLAMA_CLI" ]]; then
  echo "❌ llama-cli binary not found or not executable at: $LLAMA_CLI"
  exit 1
fi

# === Get Diff ===
# This logic ensures:

# * You prioritize committing staged content.
# * If nothing is staged, the model can still suggest a commit message based on **unstaged** changes (with a warning).
# * If *neither* is present, it exits safely.
echo "🔍 Collecting git diff..."
DIFF=$(git diff --cached)
if [[ -z "$DIFF" ]]; then
  echo "⚠️ No staged changes found. Checking for unstaged changes..."
  DIFF=$(git diff)
  if [[ -z "$DIFF" ]]; then
    echo "❌ No staged or unstaged changes found. Exiting."
    exit 1
  else
    echo "⚠️ Warning: You are committing based on unstaged changes only."
  fi
fi

# === Estimate Token Count ===
EST_TOKEN_COUNT=$(echo "$DIFF" | wc -w)
$DEBUG && echo "📏 Estimated token count: $EST_TOKEN_COUNT" >&2

# Gradually increase CTX_SIZE if diff is too large
while (( EST_TOKEN_COUNT > (CTX_SIZE - 128) )) && (( CTX_SIZE < MAX_CTX_SIZE )); do
  OLD_CTX_SIZE=$CTX_SIZE
  if (( CTX_SIZE * 2 <= MAX_CTX_SIZE )); then
    CTX_SIZE=$(( CTX_SIZE * 2 ))
  else
    CTX_SIZE=$MAX_CTX_SIZE
  fi
  $DEBUG && echo "🔧 Increasing CTX_SIZE from $OLD_CTX_SIZE to $CTX_SIZE" >&2
done

# Final token allowance
MAX_TOKENS=$(( CTX_SIZE - 128))
$DEBUG && echo "✅ Final CTX_SIZE: $CTX_SIZE | Max tokens allowed: $MAX_TOKENS" >&2

# Truncate if still too large
if (( EST_TOKEN_COUNT > MAX_TOKENS )); then
  echo "⚠️  Diff is too large. Truncating input from ~${EST_TOKEN_COUNT} to ${MAX_TOKENS} words..." >&2
  DIFF=$(echo "$DIFF" | tr ' ' '\n' | tail -n $MAX_TOKENS | tr '\n' ' ')
fi


# === Prefix Selection ===
echo
echo "📦 Choose a commit prefix (Conventional Commits):"
select PREFIX in "feat" "fix" "docs" "chore" "refactor" "test" "style" "perf" "ci" "build" "revert" "none (raw output)"; do
  case $PREFIX in
    "none (raw output)")
      PREFIX=""
      break
      ;;
    "")
      echo "❌ Invalid choice."
      ;;
    *)
      PREFIX="${PREFIX}: "
      break
      ;;
  esac
done

# === Construct Prompt ===
PROMPT="You are a commit message generator.

You will be given a git diff. Your task is to write a Conventional Commit message body (not including the type prefix) that concisely summarizes the change.

The final commit message will be: \"${PREFIX}\${COMMIT_MSG}\"
Return only the \${COMMIT_MSG} part, with no punctuation at the end unless it is required, and no quotes or additional text.

Git diff:
$DIFF"

if $DEBUG; then
  echo >&2
  echo "🔍 Prompt diagnostics:" >&2
  echo "----------------------------------------" >&2
  echo "Chars:  $(echo "$PROMPT" | wc -m)" >&2
  echo "Words:  $(echo "$PROMPT" | wc -w)" >&2
  echo "Bytes:  $(echo "$PROMPT" | wc -c)" >&2
  echo "Using context size: $CTX_SIZE" >&2
  echo "----------------------------------------" >&2
fi
if $VERBOSE_DEBUG; then
  echo "----------------------------------------" >&2
  echo "$PROMPT" >&2
  echo "----------------------------------------" >&2
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
echo
echo "🧠 Running model with ctx-size=${CTX_SIZE}..."

# Start llama-cli in background
# Try running with `--no-mmap` to force full model load into RAM
# That should push RAM usage closer to 8–9 GB and reduce disk overhead.
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
  --no-mmap \
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

# === Confirm and Commit ===
echo "📝 Suggested commit message: $PREFIX: $COMMIT_MSG"
if $DRY_RUN; then
  echo "Dry Run Mode, exiting..."
  exit 0
fi
read -rp "✅ Press ENTER to approve and commit, or q to quit: " confirm
if [[ "$confirm" == "q" ]]; then
  echo "❌ Commit canceled."
  exit 0
fi

echo "✅ Committing..."
git commit -m "$COMMIT_MSG"

# === Confirm Push ===
echo
read -rp "🚀 Press ENTER to push, or q to cancel and unstage: " push_confirm
if [[ "$push_confirm" == "q" ]]; then
  echo "🔁 Unstaging commit..."
  git reset --soft HEAD~1
  exit 0
fi

echo "📤 Pushing commit..."
git push

echo "✅ Done."
