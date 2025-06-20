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
# Best Practice: Use a Here Document (Heredoc) with quoted delimiter
# This is the most durable and safe way to pass raw code (like diffs or logs) into a variable or file in Bash:
PROMPT=$(cat <<'EOF'
You are writing a commit message. Your task is to analyze the Git diff and output only a one-line JSON object.
DO NOT repeat the Git diff or prefix.
DO NOT include commentary, Markdown, or formatting.
Only return a commit message describing the change made in the diff

### BEGIN_DIFF
EOF
)

PROMPT+=$'\n'"$DIFF"$'\n### END_DIFF\nCommit type: '"$PREFIX"$'\n### RESPONSE_JSON\n'
# 🔐 Why this works:
#     <<'EOF' (note the single quotes) prevents variable expansion ($DIFF, $PREFIX, etc.) inside the heredoc body.
#     You concatenate the dynamic values ($DIFF, $PREFIX) safely after using cat <<'EOF'.
# 🚫 Avoid
# Avoid double quotes around heredocs, like <<EOF, because:
#     Bash will interpret $DIFF, $PREFIX, and any backslashes or quotes inside it.
#     This will break if your diff includes Bash code, shell metacharacters, or JSON syntax.

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
echo >&2
echo "🧠 Running model with ctx-size=${CTX_SIZE} on $THREADS threads..." >&2

OUTPUT_FILE=$(mktemp)     # 📄 Where we'll write model output (pure stdout)
LOG_FILE=$(mktemp)        # 🪵 Where we'll write internal logs and errors (stderr)

# Build CPU affinity range for taskset
CPU_RANGE=$(seq -s, 0 $(($THREADS - 1)))
echo "🧵 THREADS = $THREADS" >&2
echo "📍 CPU_RANGE = $CPU_RANGE" >&2

# 🧪 Verify llama-cli is installed and runnable
if ! command -v "$LLAMA_CLI" &>/dev/null; then
  echo "❌ llama-cli not found: $LLAMA_CLI" >&2
  exit 127
fi

# 🛠️ Debug info about the model run
if $DEBUG; then
  echo "📏 Prompt size (chars): $(echo "$PROMPT" | wc -m)" >&2
  echo "🧪 Running llama-cli (prompt omitted from this debug log)" >&2
  echo taskset -c "$CPU_RANGE" "$LLAMA_CLI" -m "$MODEL_PATH" -p "<prompt omitted>" \
    -n "$OUTPUT_BUFFER" --ctx-size "$CTX_SIZE" --threads "$THREADS" \
    --threads-batch "$THREADS" --temp 0.7 --top-k 100 --top-p 0.9 \
    --repeat-penalty 1.1 $MLOCK $MMAP >&2
fi

# ((( Note:
#       to test llama-cli manually:
# $ taskset -c 0-7 ./llama-cli -m ./merged_model.gguf -p "test prompt" -n 10 --ctx-size 2048 --threads 8 --threads-batch 8 --mlock --no-mmap
# )))

# 🚀 Run the model and collect its output
taskset -c "$CPU_RANGE" \
  "$LLAMA_CLI" \
    -m "$MODEL_PATH" \
    -p "$PROMPT" \
    -n "$OUTPUT_BUFFER" \
    --ctx-size "$CTX_SIZE" \
    --threads "$THREADS" \
    --threads-batch "$THREADS" \
    --temp 0.7 \
    --top-k 100 \
    --top-p 0.9 \
    --repeat-penalty 1.1 \
    $MLOCK $MMAP \
    > "$OUTPUT_FILE" 2> "$LOG_FILE" &

# echo PID so we know it's running, and to attach atop if we want to
LLAMA_PID=$!
echo "LLAMA_PID: ${LLAMA_PID}"
# wait for llama to finish
wait "$LLAMA_PID"
# note the exit code
LLAMA_EXIT_CODE=$?
echo "🧠 llama-cli exited with code: $LLAMA_EXIT_CODE" >&2

# 📦 Debug: show logs and output if enabled
if $DEBUG; then
  echo >&2
  echo "🧠 llama-cli exited with code: $LLAMA_EXIT_CODE" >&2
  echo "📤 --- STDOUT (model output) ---" >&2
  cat "$OUTPUT_FILE" >&2 || echo "(none)" >&2
  echo "🪵 --- STDERR (logs) ---" >&2
  cat "$LOG_FILE" >&2 || echo "(none)" >&2
  echo "💾 Saving logs to llama_output.log and llama_debug.log" >&2
fi

# 💽 Persist output and logs for later review
cp "$OUTPUT_FILE" llama_output.log
cp "$LOG_FILE" llama_debug.log


# === Extract commit message ===
# ToDo: turn this into a helper CLI script (e.g. parse_llama_output.sh), 
# or if you're planning to port it to Python for better reliability long-term.
# OUTPUT_FILE="llama_output.log"
#!/usr/bin/env bash

# Step 1: Extract line with RESPONSE_JSON and [end of text]
MODEL_OUTPUT=$(awk '
  /RESPONSE_JSON/ && /\[end of text\]/ {
    match($0, /RESPONSE_JSON[[:space:]]*(.*)\[end of text\]/, arr)
    print arr[1]
    exit
  }
' "$OUTPUT_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

echo "📥 Extracted raw model output: $MODEL_OUTPUT"

# Step 2: Try parsing as JSON if it looks like JSON
if [[ "$MODEL_OUTPUT" =~ ^\{.*\}$ ]]; then
  COMMIT_MSG=$(echo "$MODEL_OUTPUT" | jq -r '.commit_message // empty' 2>/dev/null || true)
else
  COMMIT_MSG="$MODEL_OUTPUT"
fi

# Step 3: Filter out placeholders
if [[ "$COMMIT_MSG" == "your message here" ]]; then
  COMMIT_MSG=""
fi

# Step 4: Fallback — search for likely commit message
if [[ -z "$COMMIT_MSG" ]]; then
  COMMIT_MSG=$(grep -E '^[[:alnum:]][^"]{5,}$' "$OUTPUT_FILE" | tail -n 1 || true)
  echo "🛑 Final fallback commit message: $COMMIT_MSG"
fi

# Step 5: Final output
if [[ -n "$COMMIT_MSG" ]]; then
  echo "✅ Final extracted commit message: $COMMIT_MSG"
else
  echo "❌ No valid commit message could be extracted."
fi

# Step 6: Post-processing
# Assume SELECTED_PREFIX is like "style" (no colon)
SELECTED_PREFIX=$PREFIX

# Normalize both strings for comparison (lowercase, trim)
msg_clean=$(echo "$COMMIT_MSG" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//' | tr '[:upper:]' '[:lower:]')
prefix_clean=$(echo "$SELECTED_PREFIX" | tr '[:upper:]' '[:lower:]')

# Remove model prefix if it matches selected
if [[ "$msg_clean" == "$prefix_clean:"* ]]; then
  # Strip prefix from model output
  COMMIT_MSG=$(echo "$COMMIT_MSG" | sed -E "s/^$SELECTED_PREFIX:[[:space:]]*//")
fi

# Compose final message
FINAL_COMMIT_MSG="$SELECTED_PREFIX: $COMMIT_MSG"
echo "📝 Suggested commit message: $FINAL_COMMIT_MSG"

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
