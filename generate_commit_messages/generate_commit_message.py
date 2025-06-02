#!/usr/bin/env python3
import sys
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

def main():
    # Load the model and tokenizer once
    tokenizer = AutoTokenizer.from_pretrained("JosineyJr/generate-conventional-commit-messages")
    model = AutoModelForSeq2SeqLM.from_pretrained("JosineyJr/generate-conventional-commit-messages")

    # Read input from stdin (your git diff or description)
    input_text = sys.stdin.read().strip()
    if not input_text:
        print("❌ No input detected. Please pipe a git diff or message into this script.", file=sys.stderr)
        sys.exit(1)

    # Tokenize and generate
    inputs = tokenizer(input_text, return_tensors="pt")
    outputs = model.generate(**inputs, max_new_tokens=64, temperature=0.7, repetition_penalty=1.2)
    
    # Decode output tokens to string
    commit_message = tokenizer.decode(outputs[0], skip_special_tokens=True)
    
    print(commit_message)

if __name__ == "__main__":
    main()
