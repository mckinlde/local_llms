#!/usr/bin/env bash
set -euo pipefail

echo "🔁 Entering C++ nix-shell to convert merged model to GGUF..."

/run/current-system/sw/bin/nix-shell /home/dmei/experiments/local_llms/nix-shells/c-nix-shell/shell.nix --run "
  cd /home/dmei/experiments/local_llms/llama.cpp && \
  mkdir -p build && \
  cd build && \
  cmake .. && \
  cmake --build . -j && \
  cd .. && \
  python3 /home/dmei/experiments/local_llms/llama.cpp/convert.py \
    --outfile-dir /home/dmei/experiments/local_llms/converted-gguf \
    --model-dir /home/dmei/experiments/local_llms/merged-model \
    --vocab-type sentencepiece
"

echo "✅ GGUF model written to /home/dmei/experiments/local_llms/converted-gguf/"
