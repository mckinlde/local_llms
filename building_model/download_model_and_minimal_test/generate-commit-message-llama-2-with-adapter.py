from transformers import AutoTokenizer, LlamaForCausalLM
from peft import PeftModel
import torch
import sys
import subprocess
import os

def main():
    base_model_path = os.path.expanduser("~/git_lfs_models/Meta-Llama-Guard-2-8B")
    adapter_path = os.path.expanduser("~/git_lfs_models/generate-conventional-commit-messages")

    print("Loading base model from local path...")
    base_model = LlamaForCausalLM.from_pretrained(
        base_model_path,
        torch_dtype=torch.float16, # keep fp16 to save RAM if you want; if you get errors, switch to torch.float32
        device_map="cpu",    # <-- force all model parts onto CPU RAM
    )

    print("Loading tokenizer from local path...")
    tokenizer = AutoTokenizer.from_pretrained(base_model_path)

    print("Loading adapter weights from local path...")
    model = PeftModel.from_pretrained(
        base_model,
        adapter_path,
        device_map="cpu",    # <-- force all model parts onto CPU RAM
    )
    model.eval()

    print("Reading git diff from stdin...")
    diff_text = sys.stdin.read()

    if not diff_text.strip():
        print("No input received on stdin, please provide git diff or message manually:")
        diff_text = input("Paste your git diff or message: ")

    prompt = (
        "Generate a Conventional Commit message summarizing this git diff:\n"
        + diff_text +
        "\nCommit message:\n"
    )

    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)

    # Use correct parameters: do NOT pass 'temperature' in generate() unless using transformers>=4.30
    outputs = model.generate(
        **inputs,
        max_new_tokens=64,
        do_sample=True,
        top_p=0.95,
        temperature=0.7,
        pad_token_id=tokenizer.eos_token_id,
    )

    commit_message = tokenizer.decode(outputs[0], skip_special_tokens=True)

    print("\nGenerated Commit Message:\n", commit_message)

if __name__ == "__main__":
    main()
