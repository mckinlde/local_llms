import torch
from transformers import AutoModelForCausalLM
from peft import PeftModel
from safetensors.torch import load_file
import os

def print_model_stats(model):
    total_params = sum(p.numel() for p in model.parameters())
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"Base model total parameters: {total_params:,}")
    print(f"Trainable parameters: {trainable_params:,}")
    # Example: print number of layers if accessible (adjust to your model)
    try:
        num_layers = len(model.model.model.layers)
        print(f"Number of transformer layers: {num_layers}")
    except AttributeError:
        print("Model structure does not expose 'layers' attribute for layer count.")

def print_adapter_stats(adapter_state_dict):
    lora_keys = [k for k in adapter_state_dict.keys() if 'lora_' in k]
    print(f"Adapter total keys: {len(adapter_state_dict)}")
    print(f"LoRA keys in adapter: {len(lora_keys)}")

def main():
    print("\n========================================")
    print("Environment Info")
    print("========================================")
    import transformers
    print(f"Transformers version: {transformers.__version__}")

    print("\n========================================")
    print("Loading Base Model")
    print("========================================")
    base_model_name = "meta-llama/Llama-2-7b-chat-hf"  # adjust as needed
    base_model = AutoModelForCausalLM.from_pretrained(
        base_model_name,
        device_map="auto",
        offload_folder="offload",
        offload_state_dict=True,
        torch_dtype=torch.float16,

    print("\nOriginal base model keys sample:\n")
    for k in list(base_model.state_dict().keys())[:10]:
        print(f"  {k}")

    print_model_stats(base_model)

    print("\n========================================")
    print("Loading Adapter")
    print("========================================")
    adapter_path = "/home/dmei/git_lfs_models/generate-conventional-commit-messages/adapter_model.safetensors"
    adapter_state_dict = load_file(adapter_path)
    print("Adapter keys before stripping prefix sample:")
    for k in list(adapter_state_dict.keys())[:10]:
        print(f"  {k}")

    # Strip extra prefixes to match base model keys
    prefix_to_remove = "base_model.model.model.model."
    new_adapter_state_dict = {}
    for k, v in adapter_state_dict.items():
        if k.startswith(prefix_to_remove):
            new_key = k[len(prefix_to_remove):]
        else:
            new_key = k
        new_adapter_state_dict[new_key] = v

    print("\nAdapter keys after stripping prefix sample:")
    for k in list(new_adapter_state_dict.keys())[:10]:
        print(f"  {k}")

    print_adapter_stats(new_adapter_state_dict)

    # Wrap the base model with PeftModel (without loading adapter weights automatically)
    peft_model = PeftModel(base_model, None)

    # Load adapter weights manually
    print("\nLoading adapter weights into the PEFT model...")
    load_result = peft_model.load_state_dict(new_adapter_state_dict, strict=False)

    print("\nLoad results:")
    print(f"  Missing keys: {len(load_result.missing_keys)}")
    for k in load_result.missing_keys[:10]:
        print(f"    {k}")
    if len(load_result.missing_keys) > 10:
        print(f"    ...and {len(load_result.missing_keys) - 10} more")

    print(f"  Unexpected keys: {len(load_result.unexpected_keys)}")
    for k in load_result.unexpected_keys[:10]:
        print(f"    {k}")
    if len(load_result.unexpected_keys) > 10:
        print(f"    ...and {len(load_result.unexpected_keys) - 10} more")

    print("\nFinal stats after loading adapter:")
    print_model_stats(peft_model)

if __name__ == "__main__":
    main()
