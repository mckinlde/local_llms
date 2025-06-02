from transformers import AutoTokenizer, AutoModelForCausalLM
import torch
import sys
import os
import subprocess

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
    token_path = os.path.expanduser('~/experiments/local_llms/read_token.txt')
    try:
        with open(token_path, 'r') as f:
            hf_token = f.read().strip()
    except FileNotFoundError:
        print(f"Token file not found at {token_path}. Please check the path.")
        exit(1)

    base_model_name = "tiiuae/falcon-7b-instruct"

    tokenizer = AutoTokenizer.from_pretrained(base_model_name, token=hf_token)
    model = AutoModelForCausalLM.from_pretrained(
        base_model_name,
        torch_dtype=torch.float16,
        device_map="auto",
        token=hf_token,
    )
    model.eval()

    print("Reading git diff...")
    diff_text = get_git_diff()
    if not diff_text:
        print("Please provide input manually:")
        diff_text = input("Paste your git diff or message: ")

    # Prompt engineering
    prompt = (
        "Generate a Conventional Commit message summarizing this git diff:\n"
        + diff_text +
        "\nCommit message:"
    )

    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
    outputs = model.generate(**inputs, max_new_tokens=64, temperature=0.7)
    commit_message = tokenizer.decode(outputs[0], skip_special_tokens=True)

    print("\nGenerated Commit Message:\n", commit_message)

if __name__ == "__main__":
    main()
