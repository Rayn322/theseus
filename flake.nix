{
  description = "The official Modrinth launcher";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{self, ...}:
    inputs.utils.lib.eachDefaultSystem (system: let
      pkgs = import inputs.nixpkgs { inherit system; };
      fenix = inputs.fenix.packages.${system};
      utils = inputs.utils.lib;

      toolchain = with fenix;
        combine [
          minimal.rustc minimal.cargo
        ];

      naersk = inputs.naersk.lib.${system}.override {
        rustc = toolchain;
        cargo = toolchain;
      };

      deps = with pkgs; {
        global = [
          openssl pkg-config gcc
        ];
        gui = [
          gtk4 gdk-pixbuf atk webkitgtk dbus
        ];
        shell = [
          toolchain
          (with fenix; combine [toolchain default.clippy rust-analyzer])
          git
          jdk17 jdk8
        ];
      };
    in {
      packages = {
        theseus-cli = naersk.buildPackage {
          pname = "theseus_cli";
          src = ./.;
          buildInputs = deps.global;
          cargoBuildOptions = x: x ++ ["-p" "theseus_cli"];
        };
      };

      apps = {
        cli = utils.mkApp {
          drv = self.packages.${system}.theseus-cli;
        };
        cli-test = utils.mkApp {
          drv = pkgs.writeShellApplication {
            name = "theseus-test-cli";
            runtimeInputs = [
              (self.packages.${system}.theseus-cli.overrideAttrs (old: old // {
                release = false;
              }))
            ];
            text = ''
              DUMMY_ID="$(printf '%0.sa' {1..32})"
              theseus_cli profile run -t "" -n "Test" -i "$DUMMY_ID" "$@"
            '';
          };
        };
      };

      devShell = pkgs.mkShell {
        buildInputs = with deps;
          global ++ gui ++ shell;
      };
    });
}