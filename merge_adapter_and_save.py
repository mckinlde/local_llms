# merge_adapter_and_save.py
from transformers import LlamaForCausalLM, AutoTokenizer
from peft import PeftModel, merge_peft_adapters
import torch
import gc

model = LlamaForCausalLM.from_pretrained(
    "dmei~/experiments/local_llms/models/base_model",
    torch_dtype=torch.float32,
    low_cpu_mem_usage=True
)

model = PeftModel.from_pretrained(
    model,
    "dmei~/experiments/local_llms/models/adapter"
)

model = merge_peft_adapters(model)
model.save_pretrained("dmei~/experiments/local_llms/models/merged_model")
gc.collect()
