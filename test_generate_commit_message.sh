#!/usr/bin/env bash
set -e

ROOT_DIR=~/experiments/local_llms
GEN_SCRIPT="$ROOT_DIR/generate_commit_messages/generate_commit_message.sh"

# Check llama.cpp binary
if [ -f "$ROOT_DIR/llama.cpp/build/bin/llama-cli" ]; then
    echo "✅ Found llama-cli"
    LLM_BINARY="$ROOT_DIR/llama.cpp/build/bin/llama-cli"
elif [ -f "$ROOT_DIR/llama.cpp/build/bin/main" ]; then
    echo "✅ Found main"
    LLM_BINARY="$ROOT_DIR/llama.cpp/build/bin/main"
else
    echo "❌ llama.cpp binary not found. Please run manual_make.sh first."
    exit 1
fi

# Check model file
MODEL_FILE="$ROOT_DIR/models/commit-message-7b-v1.0-q4.gguf"
if [ ! -f "$MODEL_FILE" ]; then
  echo "❌ Model file not found at $MODEL_FILE. Please run download_commit_model.sh first."
  exit 1
fi

# Minimal sample git diff input
read -r -d '' SAMPLE_DIFF <<'EOF'
diff --git a/example.txt b/example.txt
index e69de29..d95f3ad 100644
--- a/example.txt
+++ b/example.txt
@@ -0,0 +1,3 @@
+Initial commit of example.txt
+Added sample text content.
+Fixed typo in README.
EOF

echo "🧪 Running minimal commit message generation test..."

# Pass sample diff to generate_commit_message.sh via stdin
echo "$SAMPLE_DIFF" | bash "$GEN_SCRIPT"

echo "✅ Test completed."
