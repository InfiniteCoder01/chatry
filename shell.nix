{ pkgs ? import <nixpkgs> { } }:
let
  libPath = with pkgs; lib.makeLibraryPath [
    libGL
    libxkbcommon
    wayland
    # xorg.libX11
    # xorg.libXcursor
    # xorg.libXi
    # xorg.libXrandr
  ];
in
with pkgs; mkShell {
  inputsFrom = [ ];
  buildInputs = [ rustup cmake pkg-config fontconfig cargo-watch ];
  LD_LIBRARY_PATH = "${libPath}";
}
