{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system: let
        pkgs = (import nixpkgs { inherit system; });
      in
        {
          devShell = pkgs.mkShell {
            buildInputs = with pkgs; [
              pkg-config openssl
            ];
          };
          PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
          formatter = pkgs.nixpkgs-fmt;
        }
      );
}
