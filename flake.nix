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
        python = pkgs.python3.withPackages (ps: with ps; [ 
          pyyaml
          pymavlink  # MAVLink protocol for ArduPilot
          pyserial   # Serial connections for hardware
        ]);
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            ansible
            bash
            coreutils
            docker-client
            docker-compose
            git
            netcat     # For healthchecks and debugging
            pre-commit
            python
            yamllint
            yq
          ];

          shellHook = ''
            echo "drone-platform dev shell (V1)"
            echo ""
            echo "Quick start:"
            echo "  1. Start SITL: docker compose -f infra/compose/docker-compose.sitl.yaml up"
            echo "  2. Validate:   python3 ops/scripts/validate-config.py --all"
            echo "  3. Run mission: python3 -m autonomy.mission_manager --deployment deployments/full_sitl__single_device.yaml"
            echo ""
            echo "Available commands:"
            echo "  sitl-up    - Start ArduPilot SITL"
            echo "  sitl-down  - Stop ArduPilot SITL"
            echo "  sitl-logs  - View SITL logs"
          '';
        };
      });
}
