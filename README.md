git clone https://github.com/ggml-org/llama.cpp.git

[dmei@nixos:~/experiments/local_llms]$ cd nix-shells/

[dmei@nixos:~/experiments/local_llms/nix-shells]$ tree
.
├── c-nix-shell
│   └── shell.nix
└── python-nix-shell
    └── shell.nix

3 directories, 2 files

[dmei@nixos:~/experiments/local_llms/proven_scripts]$ tree
.
├── convert_merged_model_to_gguf.sh
└── merge_lora.py

1 directory, 2 files

👏 Done
🕵️ verify existence
-rw-r--r-- 1 dmei users 8.0G Jun  2 22:06 /home/dmei/experiments/local_llms/merged-model/merged_model.gguf

$/home/dmei/experiments/local_llms/model_notes.md
$/home/dmei/experiments/local_llms/.gitignore

[dmei@nixos:~/experiments/local_llms/llama.cpp]$ cd ../../../git_lfs_models/

[dmei@nixos:~/git_lfs_models]$ tree
.
├── generate-conventional-commit-messages
│   ├── adapter_config.json
│   ├── adapter_model.safetensors
│   └── README.md
└── Meta-Llama-Guard-2-8B
    ├── config.json
    ├── generation_config.json
    ├── LICENSE
    ├── model-00001-of-00004.safetensors
    ├── model-00002-of-00004.safetensors
    ├── model-00003-of-00004.safetensors
    ├── model-00004-of-00004.safetensors
    ├── model.safetensors.index.json
    ├── original
    │   ├── consolidated.00.pth
    │   ├── params.json
    │   └── tokenizer.model
    ├── README.md
    ├── special_tokens_map.json
    ├── tokenizer_config.json
    ├── tokenizer.json
    └── USE_POLICY.md

4 directories, 19 files