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
              openssl
            ];
            shellHook = ''
              export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.openssl ]}:$LD_LIBRARY_PATH"
            '';
          };
          formatter = pkgs.nixpkgs-fmt;
        }
      );
}
