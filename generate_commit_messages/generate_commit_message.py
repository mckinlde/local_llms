import sys
import os
import subprocess
from pathlib import Path
import torch
from transformers import AutoTokenizer, LlamaForCausalLM
from peft import PeftModel

def get_git_diff():
    try:
        diff_output = subprocess.check_output(["git", "diff"], text=True)
        if not diff_output.strip():
            diff_output = subprocess.check_output(["git", "diff", "--cached"], text=True)
        if not diff_output.strip():
            print("No git diff detected (no unstaged or staged changes).")
            return None
        return diff_output
    except subprocess.CalledProcessError as e:
        print("Error running git diff:", e)
        return None

def main():
    token_path = os.path.expanduser('~/read_token.txt')
    try:
        with open(token_path, 'r') as f:
            hf_token = f.read().strip()
    except FileNotFoundError:
        print(f"Token file not found at {token_path}. Please check the path.")
        exit(1)

    base_model_name = "meta-llama/Llama-2-8b-hf"
    adapter_name = "JosineyJr/generate-conventional-commit-messages"

    print("Loading base model...")
    base_model = LlamaForCausalLM.from_pretrained(
        base_model_name,
        torch_dtype=torch.float16,
        device_map="auto",
        use_auth_token=hf_token,
    )
    tokenizer = AutoTokenizer.from_pretrained(base_model_name, use_auth_token=hf_token)

    print("Loading adapter weights...")
    model = PeftModel.from_pretrained(
        base_model,
        adapter_name,
        use_auth_token=hf_token,
    )
    model.eval()

    print("Reading input from stdin...")
    diff_text = sys.stdin.read().strip()
    if not diff_text: 
        # should be unreachable
        print("Please provide input manually:")
        diff_text = input("Paste your git diff or message: ")

    inputs = tokenizer(diff_text, return_tensors="pt").to(model.device)
    outputs = model.generate(**inputs, max_new_tokens=64, temperature=0.7)
    commit_message = tokenizer.decode(outputs[0], skip_special_tokens=True)

    print("\nGenerated Commit Message:\n", commit_message)

if __name__ == "__main__":
    main()
