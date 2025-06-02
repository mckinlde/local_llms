import torch
from transformers import AutoTokenizer, LlamaForCausalLM
from peft import PeftModel

def main():
    base_model_name = "meta-llama/Llama-2-8b-hf"
    adapter_name = "JosineyJr/generate-conventional-commit-messages"

    print("Loading base model...")
    base_model = LlamaForCausalLM.from_pretrained(base_model_name, torch_dtype=torch.float16, device_map="auto")
    tokenizer = AutoTokenizer.from_pretrained(base_model_name)

    print("Loading adapter weights...")
    model = PeftModel.from_pretrained(base_model, adapter_name)
    model.eval()

    input_text = input("Paste your git diff or message: ")

    inputs = tokenizer(input_text, return_tensors="pt").to(model.device)
    outputs = model.generate(**inputs, max_new_tokens=64, temperature=0.7)
    commit_message = tokenizer.decode(outputs[0], skip_special_tokens=True)

    print("\nGenerated Commit Message:\n", commit_message)

if __name__ == "__main__":
    main()
