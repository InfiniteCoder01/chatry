{ pkgs ? import <nixpkgs> { } }:
let
  libPath = with pkgs; lib.makeLibraryPath [
    libGL
    libxkbcommon
    wayland
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
  ];
in
with pkgs; mkShell {
  packages = [ cargo cmake pkg-config ];
  inputsFrom = [ ];
  buildInputs = [ fontconfig xorg.libX11 xorg.libXcursor xorg.libXrandr xorg.libXi wayland ];
  LD_LIBRARY_PATH = "${libPath}";
  WINIT_UNIX_BACKEND = "wayland";
}
