{ pkgs ? import <nixpkgs> { } }:
let
  nixpkgs.config.raylib.alsaSupport = true;
in
with pkgs; mkShell {
  packages = [ cmake ninja ];
  inputsFrom = [ raylib { alsaSupport = true; } ];
  buildInputs = [ mesa.drivers llvmPackages.clang ];
  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${llvmPackages.libclang.lib}/lib/clang/${lib.getVersion clang}/include";
}
