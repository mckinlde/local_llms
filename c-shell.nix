# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    clang
    cmake
    gnumake
    git
  ];

  shellHook = ''
    echo "✅ Entered llama.cpp dev shell"
    echo "💡 Run 'make -j' to build the project"
  '';
}
