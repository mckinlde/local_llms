# shell.nix
# This sets up a minimal environment using python310, transformers, and torch:
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "commit-gen-env";

  buildInputs = [
    pkgs.python310
    pkgs.python310Packages.pip
  ];

  shellHook = ''
    echo "Setting up virtual environment..."
    if [ ! -d .venv ]; then
      python3 -m venv .venv
      . .venv/bin/activate
      pip install --upgrade pip
      pip install torch transformers
    else
      . .venv/bin/activate
    fi

    echo "Virtual environment activated."
  '';
}
