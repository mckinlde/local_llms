#!/usr/bin/env bash
set -euo pipefail

echo "🔁 Entering C++ nix-shell to build llama.cpp..."

# Here is an example wrapper script that:

# Runs the cmake build inside nix-shell but writes the ./llama-cli to a persistent absolute path.

# Copies the ./llama-cli to a destination folder you choose.
nix-shell "$HOME/experiments/local_llms/nix-shells/c-nix-shell/shell.nix" --run '
  set -euo pipefail
   # /merged-model contains .gguf that was persisted by build_and_persist.gguf.sh
  MODEL_PATH=$HOME/experiments/local_llms/test_portability/merged_model.gguf 
   # llama.cpp repo 
  LLAMA_DIR="$HOME/experiments/local_llms/llama.cpp"
   # I honestly think this is temporary, but it may need to be persisted
  BUILD_DIR="$LLAMA_DIR/build"
   # destination for binary
  PERSISTENT_DESTINATION="$HOME/experiments/local_llms/test_portability/"


  echo "🧱 Configuring and building llama.cpp with CMake..."

  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR"
  cmake -DLLAMA_NATIVE=ON ..
  cmake --build . --config Release

  echo "✅ Build complete."

  echo "📁 Contents of bin/:"
  ls -lh

  echo "✅ Conversion done, verifying output..."
  
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

  # Copies the binary to a destination folder you choose.
  echo "📂 Copying binary to persistent location..."
  cp -v "$BINARY" "$PERSISTENT_DESTINATION"
  echo "✅ binary persisted at: $PERSISTENT_DESTINATION"
'