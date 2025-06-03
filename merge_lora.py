from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import torch
from pathlib import Path  # ✅ Correct import

# Convert to absolute paths to avoid Hugging Face Hub confusion
base_model_path = Path("../git_lfs_models/Meta-Llama-Guard-2-8B").resolve()
lora_model_path = Path("../git_lfs_models/generate-conventional-commit-messages").resolve()
output_path = "./merged-model"

# Load base model from local directory
base_model = AutoModelForCausalLM.from_pretrained(
    base_model_path,
    torch_dtype=torch.float16,
    low_cpu_mem_usage=True,
    local_files_only=True
)

# Load tokenizer (optional but recommended)
tokenizer = AutoTokenizer.from_pretrained(base_model_path, local_files_only=True)

# Load and merge LoRA
model = PeftModel.from_pretrained(base_model, lora_model_path, local_files_only=True)
model = model.merge_and_unload()

# Save merged model
model.save_pretrained(output_path, safe_serialization=True)
tokenizer.save_pretrained(output_path)
