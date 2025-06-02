#!/usr/bin/env bash

set -e

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

if [ -n "$1" ]; then
    INPUT_TEXT=$(<"$1")
else
    echo "Paste your git diff or error message (Ctrl+D to finish):"
    INPUT_TEXT=$(cat)
fi

PYTHON_SCRIPT="$TMP_DIR/run_model.py"
cat > "$PYTHON_SCRIPT" <<EOF
from transformers import pipeline

generator = pipeline("text-generation", model="./models_for_commit_messages")

diff = \"\"\"$INPUT_TEXT\"\"\"

prompt = f"<commit_message>\n{diff}\n"

output = generator(prompt, max_new_tokens=64)[0]["generated_text"]
print(output)
EOF

python "$PYTHON_SCRIPT"
