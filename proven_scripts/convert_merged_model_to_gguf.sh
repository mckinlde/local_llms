#!/usr/bin/env bash

echo "🔁 Entering Python nix-shell to convert merged model to GGUF..."

nix-shell "$HOME/experiments/local_llms/nix-shells/python-nix-shell/shell.nix" --run '
  echo "🐍 Setting up Python virtual environment...";
  . .venv/bin/activate;
  echo "✅ Virtual environment activated.";

  SCRIPT_PATH="$HOME/experiments/local_llms/llama.cpp/convert_hf_to_gguf.py"
  if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ ERROR: convert_hf_to_gguf.py not found in llama.cpp/";
    exit 1
  fi

  echo "🚀 Running GGUF conversion script..."
  python3 "$SCRIPT_PATH" \
    --outfile /home/dmei/experiments/local_llms/merged-model/merged_model.gguf \
    --outtype q8_0 \
    /home/dmei/experiments/local_llms/merged-model

  echo "👏 Done"

  echo "🕵️ verify existence"
  ls -lh /home/dmei/experiments/local_llms/merged-model/merged_model.gguf

  echo "PWD inside nix-shell: $(pwd)"
  echo "Model output dir exists? $(ls -ld /home/dmei/experiments/local_llms/merged-model)"
'

# You could also try writing to your home directory directly as a test:

# --outfile /home/dmei/merged_model.gguf

# Then check if /home/dmei/merged_model.gguf exists after you exit nix-shell.