{
  inputs = {
    cargo-geng.url = "github:geng-engine/cargo-geng";
  };

  outputs = { self, cargo-geng }:
    cargo-geng.eachDefaultSystem (system:
      {
        inherit
          (cargo-geng.makeFlakeSystemOutputs system {
            src = ./.;
            rust.toolchain-kind = "nightly";
          })
          devShell formatter lib;
      }
    );
}
