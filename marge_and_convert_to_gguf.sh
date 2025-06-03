#!/usr/bin/env bash
set -euo pipefail
# Great example of using nix-shells in scripts
echo "🔁 Entering Python shell to merge base + LoRA model..."
cd /home/dmei/experiments/local_llms
nix-shell /home/dmei/experiments/local_llms/nix-shells/python-nix-shell/shell.nix --run "python /home/dmei/experiments/local_llms/merge_adapter_and_save.py"

echo "✅ Merge complete. Output model in /home/dmei/experiments/local_llms/merged-model"

echo "🔁 Entering C++ shell to convert merged model to GGUF..."
cd /home/dmei/experiments/local_llms/llama.cpp
nix-shell /home/dmei/experiments/local_llms/nix-shells/c-nix-shell/shell.nix --run "
  make -j && \
  python3 /home/dmei/experiments/local_llms/llama.cpp/convert.py \
    --outfile-dir /home/dmei/experiments/local_llms/converted-gguf \
    --model-dir /home/dmei/experiments/local_llms/merged-model \
    --vocab-type sentencepiece
"

echo "✅ GGUF model written to /home/dmei/experiments/local_llms/converted-gguf/"
