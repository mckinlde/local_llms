# /home/dmei/experiments/local_llms/nix-shells/c-nix-shell/shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "llama.cpp-dev-env";

  buildInputs = [
    pkgs.cmake
    pkgs.gcc
    pkgs.python3
    pkgs.pkg-config
    pkgs.curl.dev  # 🧩 Needed for CURL support
  ];

  shellHook = ''
    echo "✅ Entered llama.cpp dev shell"
    echo "💡 Run 'make -j' to build the project"
    echo "🧹 Run 'rm -rf /home/dmei/experiments/local_llms/llama.cpp/build' to clean out an old build
  '';
}
