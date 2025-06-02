# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "commit-gen-env";

  buildInputs = [
    pkgs.python310
    pkgs.python310Packages.virtualenv
  ];

  shellHook = ''
    echo "🐍 Setting up Python virtual environment..."

    if [ ! -d .venv ]; then
      python3 -m venv .venv
      . .venv/bin/activate
      pip install --upgrade pip
      pip install torch transformers
    else
      . .venv/bin/activate
    fi

    echo "✅ Virtual environment activated."
  '';
}

# then confirm:
#python -c "import torch, transformers; print('✅ Ready to use torch & transformers!')"
