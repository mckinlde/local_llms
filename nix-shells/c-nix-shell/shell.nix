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
    # Makefile:2: *** The Makefile build is deprecated. Use the CMake build instead. For more details, see https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md.  Stop.
    echo "💡 Run 'proven_scripts/build_llama_with_cmake.sh' to build llama.cpp"
    echo "🧹 Run 'rm -rf /home/dmei/experiments/local_llms/llama.cpp/build' to clean out an old build"
  '';
}
