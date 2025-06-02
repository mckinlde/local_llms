from transformers import AutoTokenizer, LlamaForCausalLM
from peft import PeftModel
import torch

def load_local_model_and_adapter():
    base_model_path = "/home/dmei/git_lfs_models/Meta-Llama-Guard-2-8B"
    adapter_path = "/home/dmei/git_lfs_models/generate-conventional-commit-messages"

    print("Loading base model from local path...")
    base_model = LlamaForCausalLM.from_pretrained(
        base_model_path,
        torch_dtype=torch.float16,
        device_map="auto"
    )

    print("Loading tokenizer from local path...")
    tokenizer = AutoTokenizer.from_pretrained(base_model_path)

    print("Loading adapter weights locally...")
    model = PeftModel.from_pretrained(
        base_model,
        adapter_path,
        device_map="auto"
    )

    model.eval()
    return model, tokenizer

# Example usage:
model, tokenizer = load_local_model_and_adapter()
