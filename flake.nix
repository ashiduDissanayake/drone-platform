{
  description = "drone-platform V1 developer shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            bash
            coreutils
            git
            yq
          ];

          shellHook = ''
            echo "drone-platform dev shell (V1 bootstrap)"
            echo "Run: ./ops/scripts/validate-config.sh"
          '';
        };
      });
}
