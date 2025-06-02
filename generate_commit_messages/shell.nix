# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "commit-gen-env";

  buildInputs = [
    pkgs.python311
    pkgs.python311Packages.pip
    pkgs.python311Packages.virtualenv
    pkgs.python311Packages.huggingface-hub
    pkgs.git
  ];


  env.LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ 
  # import libraries that your python packages depend on
  # these are the most common
   pkgs.stdenv.cc.cc.lib
   pkgs.libz
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

# # Alternatively, if you want everything managed by Nix (no venv, no pip install):

# { pkgs ? import <nixpkgs> {} }:

# pkgs.mkShell {
#   name = "commit-gen-env";

#   buildInputs = [
#     pkgs.python311
#     pkgs.python311Packages.pytorch
#     pkgs.python311Packages.transformers
#     pkgs.python311Packages.huggingface-hub
#     pkgs.git
#   ];
# }

