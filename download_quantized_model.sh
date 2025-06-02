#!/usr/bin/env bash

# Create a models directory if it doesn't exist
mkdir -p ~/experiments/local_llms/models
cd ~/experiments/local_llms/
[ -d models ] || mkdir models
cd models

# Download a small GGUF model (e.g., TinyLlama 1.1B)
# Read the token from read_token.txt (make sure read_token.txt contains only the token)
HUGGINGFACE_TOKEN=$(<~/experiments/local_llms/read_token.txt)
echo "HUGGINGFACE_TOKEN: '$HUGGINGFACE_TOKEN'"


MODEL_URL="https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-GGUF/resolve/main/tinyllama-1.1b-chat.q4_K_M.gguf"

wget --header="Authorization: Bearer $HUGGINGFACE_TOKEN" "$MODEL_URL"
