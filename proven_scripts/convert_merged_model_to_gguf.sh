#!/usr/bin/env bash

echo "🔁 Entering Python nix-shell to convert merged model to GGUF..."

nix-shell ../nix-shells/python-nix-shell/shell.nix --run "
  echo '🐍 Setting up Python virtual environment...';
  . .venv/bin/activate;
  echo '✅ Virtual environment activated.';

  SCRIPT_PATH='$HOME/experiments/local_llms/llama.cpp/scripts/convert-hf-to-gguf.py'
  if [ ! -f \"\$SCRIPT_PATH\" ]; then
    echo '❌ ERROR: convert-hf-to-gguf.py not found in llama.cpp/scripts';
    exit 1
  fi

  echo '🚀 Running GGUF conversion script...'
  python3 convert_hf_to_gguf.py /home/dmei/experiments/local_llms/merged-model \
    --outfile /home/dmei/experiments/local_llms/merged-model/merged_model.gguf \
    --outtype q8_0

  echo '👏 Done'

  echo '🕵️ verify existence'
  ls -lh /home/dmei/experiments/local_llms/merged-model/merged_model.gguf

"

