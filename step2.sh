cd ../llama.cpp
python3 convert.py ../merged-model --outtype f16 --outfile ./models/llama-guard-lora.gguf
./build/bin/quantize ./models/llama-guard-lora.gguf ./models/llama-guard-lora.Q4_K_M.gguf Q4_K_M
./build/bin/main -m ./models/llama-guard-lora.Q4_K_M.gguf -p "Generate a conventional commit message for: fixed bug in data loader"

# Final Directory:
# experiments/local_llms/
# ├── merged-model/                  # output of merge_lora.py
# ├── llama.cpp/
# │   └── models/
# │       └── llama-guard-lora.Q4_K_M.gguf
# ├── merge_lora.py
