#!/usr/bin/env bash
set -euo pipefail

echo "🔁 Entering C++ nix-shell to build llama.cpp..."

nix-shell "$HOME/experiments/local_llms/nix-shells/c-nix-shell/shell.nix" --run '
  set -euo pipefail

  LLAMA_DIR="$HOME/experiments/local_llms/llama.cpp"
  MODEL_PATH="$HOME/experiments/local_llms/merged-model/merged_model.gguf"
  BUILD_DIR="$LLAMA_DIR/build"

  echo "🧱 Configuring and building llama.cpp with CMake..."

  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR"
  cmake -DLLAMA_NATIVE=ON ..
  cmake --build . --config Release

  echo "✅ Build complete."

  echo "📁 Contents of bin/:"
  ls -lh

  echo "🔍 Looking for inference binary..."
  cd "$BUILD_DIR/bin"

  if [[ -f "llama" ]]; then
    BINARY="./llama"
  elif [[ -f "main" ]]; then
    BINARY="./main"
  elif [[ -f "chat" ]]; then
    BINARY="./chat"
  elif [[ -f "llama-cli" ]]; then
    BINARY="./llama-cli"
  else
    echo "❌ No known llama.cpp binary found."
    ls -lh .
    exit 1
  fi

  echo "🤖 Running model inference with: $BINARY"
  "$BINARY" -m "$MODEL_PATH" -p "What is the capital of France?"
'
