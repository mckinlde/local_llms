#!/usr/bin/env bash
set -e
# ToDo:
# @Param: MODEL_DIR
# @Param: HUGGINGFACE_TOKEN
# @Param: MODEL_URL

# Create a models directory if it doesn't exist
mkdir -p ~/experiments/local_llms/models
cd ~/experiments/local_llms/
[ -d models ] || mkdir models
cd models
MODEL_DIR=~/experiments/local_llms/models

# Download a small GGUF model (e.g., TinyLlama 1.1B)
# Read the token from read_token.txt (make sure read_token.txt contains only the token)
HUGGINGFACE_TOKEN=$(<~/experiments/local_llms/read_token.txt)
echo "HUGGINGFACE_TOKEN: '$HUGGINGFACE_TOKEN'"

MODEL_URL="https://huggingface.co/JosineyJr/commit-message-7b-GGUF/resolve/main/commit-message-7b-v1.0-q4.gguf"

echo "⬇️ Downloading model..."
wget --header="Authorization: Bearer $HUGGINGFACE_TOKEN" -O "$MODEL_DIR/commit-message-7b-v1.0-q4.gguf" "$MODEL_URL"
echo "✅ Model downloaded to $MODEL_DIR"