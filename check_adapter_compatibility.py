import os
import torch
from transformers import LlamaForCausalLM
from peft import PeftModel
import transformers
import sys

base_model_path = os.path.expanduser("~/git_lfs_models/Meta-Llama-Guard-2-8B")
adapter_path = os.path.expanduser("~/git_lfs_models/generate-conventional-commit-messages")

def print_header(title):
    print("\n" + "="*40)
    print(title)
    print("="*40)

class Wrapper(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def __getattr__(self, name):
        # Forward all missing attribute lookups to the inner model
        try:
            return super().__getattr__(name)
        except AttributeError:
            return getattr(self.model, name)


def main():

    print_header("Environment Info")
    import transformers
    print(f"Transformers version: {transformers.__version__}")

    print_header("Loading Base Model")
    base_model = LlamaForCausalLM.from_pretrained(
        base_model_path,
        torch_dtype=torch.float32,
        low_cpu_mem_usage=True,
        device_map="auto",
    )
    print("Original base model keys sample:")
    sample_keys = list(dict(base_model.named_modules()).keys())
    for key in sample_keys[:10]:
        print("  ", key)

    # Wrap model to fix adapter expected module path mismatch
    base_model = Wrapper(base_model)

    print_header("Loading Adapter")
    try:
        adapter_model = PeftModel.from_pretrained(
            base_model,
            adapter_path,
            strict=False,
        )
    except KeyError as e:
        print(f"ERROR: KeyError loading adapter: {e}")
        sys.exit(1)

    # Check state dict key mismatches
    loaded_keys = set(adapter_model.state_dict().keys())
    base_keys = set(base_model.state_dict().keys())
    missing_keys = loaded_keys - base_keys
    unexpected_keys = base_keys - loaded_keys

    print_header("Adapter Compatibility Report")
    print(f"Adapter keys loaded: {len(loaded_keys)}")
    print(f"Base model keys: {len(base_keys)}")
    print(f"Missing keys in base model (adapter expects but base lacks): {len(missing_keys)}")
    for k in list(missing_keys)[:10]:
        print("  -", k)
    if len(missing_keys) > 10:
        print(f"  ... plus {len(missing_keys)-10} more")

    print(f"Unexpected keys in base model (base has but adapter didn't load): {len(unexpected_keys)}")
    for k in list(unexpected_keys)[:10]:
        print("  -", k)
    if len(unexpected_keys) > 10:
        print(f"  ... plus {len(unexpected_keys)-10} more")

    print("\nSuccess! Adapter loaded with wrapped base model module structure.")

if __name__ == "__main__":
    main()
