# /home/dmei/experiments/local_llms/nix-shells/python-nix-shell/shell.nix
{ pkgs ? import <nixpkgs> {} }:
# Assumes (and uses requirements.txt from) you have cloned llama.cpp from https://github.com/ggml-org/llama.cpp.git
pkgs.mkShell {
  name = "llm-conversion-env";

  buildInputs = [
    pkgs.python311
    pkgs.python311Packages.pip
    pkgs.python311Packages.virtualenv
    pkgs.python311Packages.huggingface-hub
    pkgs.python311Packages.sentencepiece  # <-- required for llama.cpp/convert_hf_to_gguf.py; not currently in requirements.txt
    pkgs.git
  ];

  env.LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ 
    pkgs.stdenv.cc.cc.lib
    pkgs.libz
  ];

  shellHook = ''
    echo "🐍 Setting up Python virtual environment..."

    if [ ! -d .venv ]; then
      python3 -m venv .venv
      . .venv/bin/activate
      pip install --upgrade pip
      pip install -r /home/dmei/experiments/local_llms/llama.cpp/requirements.txt
    else
      . .venv/bin/activate
    fi

    echo "✅ Virtual environment activated."
  '';
}
