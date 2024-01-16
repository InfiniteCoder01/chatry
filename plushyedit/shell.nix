{ pkgs ? import <nixpkgs> { } }:
with pkgs; mkShell {
  inputsFrom = [ raylib ];
  buildInputs = [ rustup cmake ninja ];
  LIBCLANG_PATH="${llvmPackages.libclang.lib}/lib";
  BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${llvmPackages.libclang.lib}/lib/clang/${lib.getVersion clang}/include";
}
