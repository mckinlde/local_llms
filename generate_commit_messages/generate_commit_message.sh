#!/usr/bin/env bash

# Exit on error
set -e

# Create a temp directory for the script
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Ensure Python dependencies are installed (use pip or nix-shell separately if needed)
# echo "Ensure Python 3.10, transformers, and torch are installed."

# Handle input (from file or stdin)
if [ -n "$1" ]; then
    INPUT_TEXT=$(<"$1")
else
    echo "Paste your git diff or error message (Ctrl+D to finish):"
    INPUT_TEXT=$(cat)
fi

# Generate Python script dynamically
PYTHON_SCRIPT="$TMP_DIR/run_model.py"
cat > "$PYTHON_SCRIPT" <<EOF
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

tokenizer = AutoTokenizer.from_pretrained("JosineyJr/generate-conventional-commit-messages")
model = AutoModelForSeq2SeqLM.from_pretrained("JosineyJr/generate-conventional-commit-messages")

input_text = """$INPUT_TEXT"""
inputs = tokenizer.encode(input_text, return_tensors="pt", truncation=True)
outputs = model.generate(inputs, max_length=32)

print(tokenizer.decode(outputs[0], skip_special_tokens=True))
EOF

# Run the script
python "$PYTHON_SCRIPT"
