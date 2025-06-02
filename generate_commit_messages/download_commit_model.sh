#!/usr/bin/env bash

# Create models directory if it doesn't exist
mkdir -p ~/experiments/local_llms/models
cd ~/experiments/local_llms/
[ -d models ] || mkdir models
cd models

# Read Hugging Face token
HUGGINGFACE_TOKEN=$(<~/experiments/local_llms/read_token.txt)

# Download the GGUF commit message model
MODEL_URL="https://huggingface.co/JosineyJr/generate-conventional-commit-messages/resolve/main/commit-message-7b-v1.0-q4.gguf"
wget --header="Authorization: Bearer $HUGGINGFACE_TOKEN" "$MODEL_URL" -O commit-message-7b-v1.0-q4.gguf