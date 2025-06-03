#!/usr/bin/env bash
set -euo pipefail
# 🛠 IMPORTANT: After running merge_and_convert_to_gguf.sh, you’ll need to 
# replace "your-model-name.gguf" in quantize_converted_model.sh with the actual 
# file name (e.g. merged-model.gguf) once you know it.
MODEL_NAME="your-model-name.gguf"  # Replace with actual file name if known
MODEL_PATH="/home/dmei/experiments/local_llms/converted-gguf/${MODEL_NAME}"
OUT_PATH="/home/dmei/experiments/local_llms/converted-gguf/${MODEL_NAME%.gguf}-q4_K_M.gguf"

echo "🔁 Entering C++ shell to quantize GGUF model..."
cd /home/dmei/experiments/local_llms/llama.cpp
nix-shell /home/dmei/experiments/local_llms/nix-shells/c-nix-shell/shell.nix --run "
  ./quantize ${MODEL_PATH} ${OUT_PATH} q4_K_M
"

echo "✅ Quantized model saved to: ${OUT_PATH}"
