{
  description = "drone-platform V1 developer shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        python = pkgs.python3.withPackages (ps: with ps; [ pyyaml ]);
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            ansible
            bash
            coreutils
            docker-client
            docker-compose
            git
            pre-commit
            python
            yamllint
            yq
          ];

          shellHook = ''
            echo "drone-platform dev shell (V1)"
            echo "Run: python3 ops/scripts/validate-config.py --all"
          '';
        };
      });
}
