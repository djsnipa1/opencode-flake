{
  description = "OpenCode and OpenCode2 (v2) - AI coding agent for the terminal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # ============================================================
        # OpenCode v1 (stable) - from GitHub releases
        # ============================================================
        opencode-v1 = pkgs.callPackage ./opencode-v1.nix { };

        # ============================================================
        # OpenCode v2 (beta) - from npm registry @opencode/cli
        # ============================================================
        opencode-v2 = pkgs.callPackage ./opencode-v2.nix { };

        # ============================================================
        # Overlay for nixpkgs
        # ============================================================
        overlay = final: prev: {
          opencode = opencode-v1;
          opencode2 = opencode-v2;
        };

      in {
        # Packages
        packages = {
          default = opencode-v1;
          inherit opencode-v1 opencode-v2;
          # Aliases for convenience
          opencode = opencode-v1;
          opencode2 = opencode-v2;
        };

        # Apps (for `nix run`)
        apps = {
          default = {
            type = "app";
            program = "${opencode-v1}/bin/opencode";
          };
          opencode = {
            type = "app";
            program = "${opencode-v1}/bin/opencode";
          };
          opencode2 = {
            type = "app";
            program = "${opencode-v2}/bin/opencode2";
          };
        };

        # Dev shell with both
        devShells.default = pkgs.mkShell {
          buildInputs = [ opencode-v1 opencode-v2 ];
        };

        # Overlay for nixpkgs integration
        overlays.default = overlay;
      }
    )
    // {
      # Top-level overlay for direct flake usage
      overlays.default = (system: final: prev: {
        opencode = self.packages.${system}.opencode;
        opencode2 = self.packages.${system}.opencode2;
      });
    };
}