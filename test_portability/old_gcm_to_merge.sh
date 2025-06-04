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
CTX_SIZE=2048 # Total model context window in tokens (prompt + output).
# If prompt + output > CTX_SIZE, llama.cpp may truncate or fail.
# Default to small model, and increase up to max based on size of Diff in script

# CIX_SIZE: the total number of tokens the model can attend to, including both:
#     the prompt (input tokens)
#     the generated output (up to -n tokens)
# It’s a logical constraint, not a physical memory limiter. If the total token count (prompt + output) exceeds CTX_SIZE, the model:
#     may truncate your prompt (often from the start),
#     or crash if not handled well.
# So you are correct that CTX_SIZE acts like a hard boundary, but it’s not a memory manager — it’s a token window limit.




MLOCK=--mlock # force system to keep model in RAM rather than swapping or compressing
              #                          (env: LLAMA_ARG_MLOCK)
MMAP=--no-mmap # The llama.cpp --help swears this isn't the flag to force RAM, but it is definetly the flag that causes me to see RAM use go up.
THREADS=8 # use `$ nproc` to see how many threads you have avaliable
# my CPU has 8 (4 cores w/2 threads per core); don't set to max to avoid oversubscription causing contention

OUTPUT_BUFFER=128 # Max number of tokens to generate in the output, May crash if prompt is too long
# You use this to set:
# -n $OUTPUT_BUFFER
# This controls the maximum number of tokens the model should generate as output.
# That output must fit within CTX_SIZE, along with the prompt.
# | Variable        | Role                                       | Used In                    |
# | --------------- | ------------------------------------------ | -------------------------- |
# | `OUTPUT_BUFFER` | How many tokens the model generates (`-n`) | llama-cli runtime argument |
# | `CTX_BUFFER`    | Prompt safety margin (tokens reserved)     | Prompt truncation logic    |
# So while both deal with "output capacity", they do it at different layers:
#     OUTPUT_BUFFER is the instruction to the model.
#     CTX_BUFFER is the input-side safety mechanism to avoid crashing the model due to overflow.

# Script Settings
DEBUG=false # Toggle for prompt metrics, raw model output, ctx_size changes
VERBOSE_DEBUG=false  # Toggle for every command, full prompt
DRY_RUN=false # True to generate a message and exit without asking to commit or push, saves tens of keystrokes in testing.  tens of keystrokes!

CTX_BUFFER=256 # How many tokens to subtract from prompt to be sure prompt+output!>CTX_SIZE; this would be better measured with a llama tokenizer, and crashes LLAMA if prompt>CTX_SIZE
# You use this to calculate:
# MAX_TOKENS=$(( CTX_SIZE - $CTX_BUFFER ))
# This is a safety margin to ensure that the prompt does not eat into space reserved for the output.
# You're effectively saying:
#     “I’ll leave $CTX_BUFFER tokens of headroom for the output when feeding in the prompt.”

# 💡 Best practice:
# Set CTX_BUFFER ≈ OUTPUT_BUFFER (with a little extra margin). You’ve got:

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

# === Estimate Diff Token Count ===
EST_TOKEN_COUNT=$(echo "$DIFF" | wc -w)
$DEBUG && echo "📏 Estimated Diff token count: $EST_TOKEN_COUNT" >&2
# If you're ever unsure of the true token count, consider using 
# llama_tokenize (if available) to get real token counts instead 
# of wc -w, which is a rough estimate.

# Gradually increase CTX_SIZE if diff is too large
while (( EST_TOKEN_COUNT > (CTX_SIZE - CTX_BUFFER) )) && (( CTX_SIZE < MAX_CTX_SIZE )); do
  OLD_CTX_SIZE=$CTX_SIZE
  if (( CTX_SIZE * 2 <= MAX_CTX_SIZE )); then
    CTX_SIZE=$(( CTX_SIZE * 2 ))
  else
    CTX_SIZE=$MAX_CTX_SIZE
  fi
  $DEBUG && echo "🔧 Increasing CTX_SIZE from $OLD_CTX_SIZE to $CTX_SIZE" >&2
done

# Final token allowance
MAX_TOKENS=$(( CTX_SIZE - $CTX_BUFFER ))
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
PROMPT="You are writing a commit message. You will be shown a Git diff and a Commit type.  
Generate a commit message corresponding to the Commit type that describes the changes made in the Git diff.
Only output JSON structured like this:
{
  \"commit_message\": \"your concise message here\"
}

Example:
Git diff:
- def foo(): pass
+ def foo(): print(\"bar\")

Commit type: feat
{
  \"commit_message\": \"print output in foo()\"
}

---

Now it's your turn.
Git diff:
$DIFF

Commit type: $PREFIX
"

# === Estimate Prompt Token Count ===
EST_TOKEN_COUNT_PROMPT=$(echo "$PROMPT" | wc -w)
$DEBUG && echo "📏 Estimated Prompt token count: $EST_TOKEN_COUNT_PROMPT" >&2


if $DEBUG; then
  echo >&2
  echo "🔍 Prompt diagnostics:" >&2
  echo "----------------------------------------" >&2
  echo "Chars:  $(echo "$PROMPT" | wc -m)" >&2
  echo "Words:  $(echo "$PROMPT" | wc -w)" >&2
  echo "Bytes:  $(echo "$PROMPT" | wc -c)" >&2
  echo "Prompt est. token count:  $EST_TOKEN_COUNT_PROMPT" >&2
  echo "Using context size: $CTX_SIZE" >&2
  echo "----------------------------------------" >&2
fi
if $VERBOSE_DEBUG; then
  echo "----------------------------------------" >&2
  echo "$PROMPT" >&2
  echo "----------------------------------------" >&2
fi

# === Resource Monitor moved to separate file ===

# === Run Model ===
echo
echo "🧠 Running model with ctx-size=${CTX_SIZE} on $THREADS threads..."

OUTPUT_FILE=$(mktemp)

# Build CPU affinity range for taskset
CPU_RANGE=$(seq -s, 0 $(($THREADS - 1)))
echo "THREADS = $THREADS"
echo "CPU_RANGE = $CPU_RANGE"

taskset -c "$CPU_RANGE" \
  $LLAMA_CLI \
    -m "$MODEL_PATH" \
    -p "$PROMPT" \
    -n $OUTPUT_BUFFER \
    --ctx-size "$CTX_SIZE" \
    --threads $THREADS \
    --threads-batch $THREADS \
    --temp 0.7 \
    --top-k 100 \
    --top-p 0.9 \
    --repeat-penalty 1.1 \
    --mlock \
    --no-mmap \
    # Fix 4: Use a different output file for stderr/logs vs model output
    $LLAMA_CLI ... > "$OUTPUT_FILE" 2> "$LOG_FILE"


LLAMA_PID=$!
echo "LLAMA_PID: ${LLAMA_PID}"

# Bonus: Add live progress
# As a tiny bonus, here's how to live stream the output while it's running:
tail -f "$OUTPUT_FILE" &
TAIL_PID=$!

wait "$LLAMA_PID"
kill "$TAIL_PID"

# === Optional: Monitor Resources ===
# # get script directory
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# # Launch monitor in background
# "$SCRIPT_DIR/resource_monitor.sh" "$LLAMA_PID" &
# to run resource monitor in a new terminal:
# ./resource_monitor.sh $(pgrep -f llama-cli)

wait "$LLAMA_PID"
# More graceful handling of model errors.
# Optionally, different behavior for specific exit codes.
# Avoids silent failure if llama-cli dies (e.g., OOM).
LLAMA_EXIT_CODE=$?
if [[ $LLAMA_EXIT_CODE -ne 0 ]]; then
  echo "❌ llama-cli exited with code $LLAMA_EXIT_CODE"
  cat "$OUTPUT_FILE"
  exit $LLAMA_EXIT_CODE
fi

# === Extract Message ===
if $DEBUG; then
  echo "📦 Raw model output:"
  cat "$OUTPUT_FILE"
  echo
fi


# This block is printed as part of the output, but:
#     It’s printed after some garbage text, making jq possibly fail.
#     The model’s output includes pre-text, maybe logs or context repeats.
#     You run jq . "$OUTPUT_FILE" — but "$OUTPUT_FILE" contains logs + model output, not pure JSON.

# Fix 1: Extract clean JSON block from mixed output
# Instead of passing the full output file to jq, extract just the JSON block before passing it:
JSON_BLOCK=$(awk '/^{/{flag=1} flag; /^}/{exit}' "$OUTPUT_FILE")

if [[ -n "$JSON_BLOCK" ]]; then
  # Fix 2: Show what jq is seeing, even on failure
  echo "🔍 Attempting to extract JSON from:"
  grep -A5 -B5 'commit_message' "$OUTPUT_FILE"

  COMMIT_MSG=$(jq -r '.commit_message // empty' "$OUTPUT_FILE" || true)
fi

# Fix 3: Strip logs and just print model output
JSON_BLOCK=$(awk '/^{/{flag=1} flag' "$OUTPUT_FILE")

if [[ -n "$JSON_BLOCK" ]]; then
  COMMIT_MSG=$(jq -r '.commit_message // empty' <<< "$JSON_BLOCK" 2>/dev/null || true)
fi

# Fallback in case of malformed or missing JSON
if [[ -z "$COMMIT_MSG" ]]; then
  COMMIT_MSG=$(grep -E '^[[:alnum:]].{5,}$' "$OUTPUT_FILE" | head -n 1)
fi

if $DEBUG; then
  echo
  echo "🔍 Parsed JSON:"
  jq . "$OUTPUT_FILE" || echo "⚠️ JSON parse failed"
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
