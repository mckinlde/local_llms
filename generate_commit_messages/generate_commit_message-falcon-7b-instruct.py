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

Output of this version:
# ```bash
# [nix-shell:~/experiments/local_llms/generate_commit_messages]$ ./generate_commit_message.sh 
# No changes detected in git diff (unstaged or staged). Please provide input manually:
# Press Ctrl+D when done.
# write a git commit as though I had swapped to a falcon model from a llama model
# tokenizer_config.json: 100%|███████████████████████████████████████████████████████████████████████████████████████████| 1.13k/1.13k [00:00<00:00, 3.22MB/s]
# tokenizer.json: 100%|██████████████████████████████████████████████████████████████████████████████████████████████████| 2.73M/2.73M [00:00<00:00, 4.46MB/s]
# special_tokens_map.json: 100%|██████████████████████████████████████████████████████████████████████████████████████████████| 281/281 [00:00<00:00, 659kB/s]
# Loading checkpoint shards: 100%|██████████████████████████████████████████████████████████████████████████████████████████████| 2/2 [00:24<00:00, 12.46s/it]
# generation_config.json: 100%|███████████████████████████████████████████████████████████████████████████████████████████████| 117/117 [00:00<00:00, 207kB/s]
# Reading git diff...
# No git diff detected (no unstaged or staged changes).
# Please provide input manually:
# Paste your git diff or message: The following generation flags are not valid and may be ignored: ['temperature']. Set `TRANSFORMERS_VERBOSITY=info` for more details.
# Setting `pad_token_id` to `eos_token_id`:11 for open-end generation.
# 
# Generated Commit Message:
#  Generate a Conventional Commit message summarizing this git diff:
# write a git commit as though I had swapped to a falcon model from a llama model
# Commit message: 'Swapped to a falcon model from a llama model'
# (.venv) 
# ```