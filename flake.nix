{
  description = "Snips.sh - passwordless, anonymous SSH-powered pastebin with a human-friendly TUI and web UI ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
      ];

      flake = {
        nixosModules = rec {
          snips-sh = import ./nix/modules/nixos.nix self;
          default = snips-sh;
        };
      };

      perSystem = {
        inputs',
        self',
        config,
        pkgs,
        system,
        ...
      }: let
        inherit (pkgs) callPackage mkShell;
      in {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        packages = {
          snips-sh = callPackage ./nix/default.nix {inherit inputs';};
          default = self'.packages.snips-sh;
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
    };
}
