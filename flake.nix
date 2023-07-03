{
  description = "Snips.sh - passwordless, anonymous SSH-powered pastebin with a human-friendly TUI and web UI ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        # add more systems as they are supported
      ];
      perSystem = {
        config,
        pkgs,
        ...
      }: let
        inherit (pkgs) callPackage mkShell;
      in {
        packages = rec {
          snips-sh = callPackage ./nix/default.nix {};
          default = snips-sh;
        };

        devShells.default = mkShell {
          name = "nyx";
          packages = with pkgs; [
            nil # nix ls
            alejandra # formatter
            git # flakes require git
            statix # nix linting and suggestions
            deadnix # clean up unused nix code
            go # for working on the source
          ];
        };

        # provide the formatter for nix fmt
        formatter = pkgs.alejandra;
      };
      flake = {
        # TODO: write nixos module
        nixosModules = rec {
          snips-sh = null;
          default = snips-sh;
        };
      };
    };
}
