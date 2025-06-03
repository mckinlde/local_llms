import os
from transformers import AutoTokenizer, LlamaForCausalLM
from peft import PeftModel
import torch
import subprocess
import psutil
import threading
import time

# call monitor_resources() at the beginning of the script to see how we're doing
def monitor_resources(interval=5):
    def log():
        while True:
            mem = psutil.virtual_memory()
            cpu = psutil.cpu_percent()
            print(f"[Resource Monitor] CPU: {cpu}% | RAM: {mem.used / (1024**3):.2f}GB / {mem.total / (1024**3):.2f}GB")
            time.sleep(interval)
    thread = threading.Thread(target=log, daemon=True)
    thread.start()

print("Start resource monitor...")
monitor_resources()

# Paths
base_model_path = os.path.expanduser("~/git_lfs_models/Meta-Llama-Guard-2-8B")
adapter_path = os.path.expanduser("~/git_lfs_models/generate-conventional-commit-messages")
merged_model_dir = os.path.expanduser("~/experiments/local_llms/models/merged_llama_guard_2_8B_with_commit_adapter")
gguf_output_dir = os.path.expanduser("~/experiments/local_llms/models/gguf")

# Step 1: Load base model and adapter
print("Loading base model...")
base_model = LlamaForCausalLM.from_pretrained(base_model_path, torch_dtype=torch.float32)
print("Loading adapter...")
model = PeftModel.from_pretrained(base_model, adapter_path)

# Step 2: Merge LoRA adapter into base model
print("Merging adapter into base model...")
model = model.merge_and_unload()

# Step 3: Save merged model
print(f"Saving merged model to {merged_model_dir}...")
model.save_pretrained(merged_model_dir)
tokenizer = AutoTokenizer.from_pretrained(base_model_path)
tokenizer.save_pretrained(merged_model_dir)

# Step 4: Convert to GGUF using llama.cpp conversion script
print("Converting to GGUF...")
convert_script_path = "~/llama.cpp/convert.py"  # adjust if you placed it elsewhere
convert_script_path = os.path.expanduser(convert_script_path)
subprocess.run([
    "python3",
    convert_script_path,
    "--outfile",
    os.path.join(gguf_output_dir, "llama_guard_commit.gguf"),
    merged_model_dir
], check=True)

print("✅ GGUF conversion complete.")
