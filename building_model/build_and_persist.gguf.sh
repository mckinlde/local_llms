#!/usr/bin/env bash
set -euo pipefail

# Here is an example wrapper script that:

# Runs the conversion inside nix-shell but writes the .gguf to a persistent absolute path.

# Copies the .gguf to a destination folder you choose.

MODEL_DIR="$HOME/experiments/local_llms/merged-model" # /merged-model contains safetensors files and .json files
PERSISTENT_GGUF="$HOME/experiments/local_llms/test_portability/merged_model.gguf" # destination for .gguf

mkdir -p "$MODEL_DIR"
mkdir -p "$(dirname "$PERSISTENT_GGUF")"

# Runs the conversion inside nix-shell but writes the .gguf to a persistent absolute path.
echo "🔁 Running GGUF conversion inside nix-shell..."
nix-shell "$HOME/experiments/local_llms/nix-shells/python-nix-shell/shell.nix" --run "
  . .venv/bin/activate
  python3 $HOME/experiments/local_llms/llama.cpp/convert_hf_to_gguf.py \
    --outfile $MODEL_DIR/merged_model.gguf \
    --outtype q8_0 \
    $MODEL_DIR
"

echo "✅ Conversion done, verifying output..."
ls -lh "$MODEL_DIR/merged_model.gguf"

# Copies the .gguf to a destination folder you choose.
echo "📂 Copying .gguf to persistent location..."
cp -v "$MODEL_DIR/merged_model.gguf" "$PERSISTENT_GGUF"

echo "✅ .gguf persisted at: $PERSISTENT_GGUF"
