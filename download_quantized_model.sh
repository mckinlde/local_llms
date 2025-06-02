# Create a models directory
mkdir -p ~/experiments/local_llms/models

# Download a small GGUF model (e.g., TinyLlama 1.1B)
cd ~/experiments/local_llms/models
wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-GGUF/resolve/main/tinyllama-1.1b-chat.q4_K_M.gguf
