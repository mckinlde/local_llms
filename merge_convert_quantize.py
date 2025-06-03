import os
import time
import torch
import psutil
import gc
import subprocess
import threading

from transformers import LlamaForCausalLM
from peft import PeftModel

# === Config ===

base_model_path = os.path.expanduser("~/git_lfs_models/Meta-Llama-Guard-2-8B")
adapter_path = os.path.expanduser("~/git_lfs_models/generate-conventional-commit-messages")
merged_model_dir = os.path.expanduser("~/experiments/local_llms/models/merged_llama_guard_2_8B_with_commit_adapter")
gguf_output_dir = os.path.expanduser("~/experiments/local_llms/models/gguf")
os.makedirs(merged_model_dir, exist_ok=True)
os.makedirs(gguf_output_dir, exist_ok=True)

gguf_basename = "merged-llama-guard-2-8B-with-commit.gguf"
gguf_path = os.path.join(gguf_output_dir, gguf_basename)

convert_script = os.path.expanduser("~/experiments/local_llms/llama.cpp/convert.py")
quantize_binary = os.path.expanduser("~/experiments/local_llms/llama.cpp/build/bin/quantize")
quantized_basename = "merged-llama-guard-2-8B-with-commit-q4_K_M.gguf"
quantized_path = os.path.join(gguf_output_dir, quantized_basename)
quantize_type = "q4_K_M"

# === Define merge function ===

def merge_peft_adapters(model: PeftModel) -> LlamaForCausalLM:
    print("Merging adapter weights into the base model...")
    if hasattr(model, "merge_and_unload"):
        model = model.merge_and_unload()
    elif hasattr(model, "merge_adapter"):
        model.merge_adapter()
    else:
        raise RuntimeError("Model does not support merging adapters")
    return model

# === Resource logging ===

def log_resources(interval=3):
    while True:
        ram = psutil.virtual_memory()
        cpu = psutil.cpu_percent()
        print(f"[Resource Monitor] CPU: {cpu:.1f}% | RAM: {ram.used / 1e9:.2f}GB / {ram.total / 1e9:.2f}GB")
        time.sleep(interval)

# === Adapter merge ===

def merge_adapter():
    print("Loading base model for merge...")
    # model = LlamaForCausalLM.from_pretrained(
    #     base_model_path,
    #     torch_dtype=torch.float32,
    #     low_cpu_mem_usage=True
    # )
    # We keep hitting the RAM ceiling, so let's try offloading to SSD
    # I still want to use full float32 for accuracy of finetuning given that I'm not running with a GPU
    model = LlamaForCausalLM.from_pretrained(
        base_model_path,
        torch_dtype=torch.float32,
        low_cpu_mem_usage=True,
        device_map="auto",           # Auto-assign layers to CPU and disk offload
        offload_folder="./offload",  # Local folder to offload weights to SSD
    )

    print("Loading PEFT adapter...")
    model = PeftModel.from_pretrained(model, adapter_path)

    model = merge_peft_adapters(model)

    print(f"Saving merged model to {merged_model_dir}...")
    model.save_pretrained(merged_model_dir)

    del model
    gc.collect()
    print("Adapter merged and saved successfully.")

def adapted_merge_adapter(): # adapted to handle adapter/model mismatch more gracefully and improve memory handling:
    print("Loading base model for merge...")
    model = LlamaForCausalLM.from_pretrained(
        base_model_path,
        torch_dtype=torch.float32,
        low_cpu_mem_usage=True,
        device_map="auto",
        offload_folder="./offload",
    )

    print("Loading PEFT adapter with strict=False...")
    model = PeftModel.from_pretrained(model, adapter_path, strict=False)

    print("Cleaning up memory before merging...")
    gc.collect()
    try:
        torch.cuda.empty_cache()
    except Exception:
        pass  # Ignore if no GPU or CUDA not available

    print("Merging adapter weights into the base model...")
    model = merge_peft_adapters(model)

    print(f"Saving merged model to {merged_model_dir}...")
    model.save_pretrained(merged_model_dir)

    del model
    gc.collect()
    print("Adapter merged and saved successfully.")


# === Convert to GGUF ===

def convert_to_gguf():
    print("Converting merged model to GGUF format...")
    cmd = [
        "python3", convert_script,
        "--outfile", gguf_path,
        "--outtype", "f16",
        merged_model_dir
    ]
    print(f"Running: {' '.join(cmd)}")
    subprocess.run(cmd, check=True)
    print(f"GGUF model saved to: {gguf_path}")

# === Quantize GGUF ===

def quantize_gguf():
    print("Quantizing GGUF model...")
    cmd = [
        quantize_binary,
        gguf_path,
        quantized_path,
        quantize_type
    ]
    print(f"Running: {' '.join(cmd)}")
    subprocess.run(cmd, check=True)
    print(f"Quantized model saved to: {quantized_path}")

# === Main ===

if __name__ == "__main__":
    print("Starting resource monitor thread...")
    monitor_thread = threading.Thread(target=log_resources, daemon=True)
    monitor_thread.start()

    start_time = time.time()
    try:
        adapted_merge_adapter()
        convert_to_gguf()
        quantize_gguf()
    except Exception as e:
        print(f"ERROR: {e}")
    finally:
        elapsed = time.time() - start_time
        print(f"Done in {elapsed:.2f} seconds.")
