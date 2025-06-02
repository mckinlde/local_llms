#!/usr/bin/env bash

# Make sure huggingface_hub is installed
pip install huggingface_hub || exit 1

# Download the model snapshot from HuggingFace
python3 -c "
from huggingface_hub import snapshot_download
snapshot_download(repo_id='JosineyJr/generate-conventional-commit-messages')
"
