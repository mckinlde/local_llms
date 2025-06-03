import os
import torch
from peft import PeftModel
import transformers
from transformers import AutoModelForCausalLM, AutoTokenizer

base_model_path = os.path.expanduser("~/git_lfs_models/Meta-Llama-Guard-2-8B")
adapter_path = os.path.expanduser("~/git_lfs_models/generate-conventional-commit-messages")

def main():

    print("\n========================================")
    print("Environment Info")
    print("========================================")
    print(f"Transformers version: {transformers.__version__}")

    print("\n========================================")
    print("Loading Base Model")
    print("========================================")
    base_model = AutoModelForCausalLM.from_pretrained(
        base_model_path,
        device_map="auto",
        torch_dtype=torch.float32
    )
    tokenizer = AutoTokenizer.from_pretrained(base_model_path)

    print("Original base model keys sample:\n")
    for k in list(base_model.state_dict().keys())[:10]:
        print(f"   {k}")

    print("\n========================================")
    print("Loading Adapter")
    print("========================================")

    # Load adapter by passing the directory path, no manual torch.load
    adapter_model = PeftModel.from_pretrained(
        base_model,
        adapter_path,
        strict=False
    )

    print("\nAdapter loaded successfully. Sample of adapter keys:")
    for k in list(adapter_model.state_dict().keys())[:10]:
        print(f"   {k}")

    print("\nCompatibility check complete!")

if __name__ == "__main__":
    main()
