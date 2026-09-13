{
  description = "nix-labs — portable lab & development environments (Zephyr per chip family, SDR with LimeSDR, Sipeed SLogic logic analyzer) as devShells, plus udev/registry modules, project templates and a QEMU VM fallback for hardware a host cannot drive natively";

  inputs = {
    # Stable is the only target: the shells are meant to be cache-warm on every
    # machine. Consumers may `follows` their own 26.05 nixpkgs.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Zephyr SDK (per-target toolchains), west + Zephyr's Python requirements,
    # host tools and the Zephyr openocd fork.
    zephyr-nix = {
      url = "github:nix-community/zephyr-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Only used by `checks` (home-manager module eval smoke).
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [ inputs.treefmt-nix.flakeModule ];

      flake = {
        # Pure data + helpers: the USB hardware catalogue, the environment
        # catalogue and the udev rule generator (see docs/HARDWARE.md).
        lib = import ./lib { inherit (nixpkgs) lib; };

        # pulseview-sipeed / sigrok-cli-sipeed (nixpkgs' libsigrok-sipeed) and
        # the `lab` helper, for consumers who prefer an overlay to `packages`.
        overlays.default = final: _prev: import ./pkgs { pkgs = final; };

        # NixOS: `labs.enable` — udev rules for lab hardware, plugdev/dialout
        # for `labs.users`, and the `labs` flake-registry entry.
        nixosModules.default = import ./nixos;
        # nix-darwin: the registry entry only (no udev on macOS).
        darwinModules.default = import ./darwin;
        # home-manager (Linux + macOS): the `lab` CLI and direnv/nix-direnv.
        homeManagerModules.default = import ./home;

        templates = {
          zephyr = {
            path = ./templates/zephyr;
            description = "Zephyr application (west T2 workspace: app/ manifest + hello world) pinned to a nix-labs Zephyr shell";
          };
          sdr = {
            path = ./templates/sdr;
            description = "SDR workspace pinned to the nix-labs sdr shell (direnv)";
          };
          logic = {
            path = ./templates/logic;
            description = "Logic-analyzer capture workspace pinned to the nix-labs logic shell (direnv)";
          };
        };
      };

      perSystem =
        {
          pkgs,
          lib,
          system,
          ...
        }:
        let
          # Everything an environment needs, instantiated for a given package
          # set — used for the host system here and for the VM guest system.
          labsFor =
            pkgs':
            import ./labs {
              pkgs = pkgs';
              inherit lib;
              labPkgs = import ./pkgs { pkgs = pkgs'; };
              zephyr = inputs.zephyr-nix.lib.mkZephyr { pkgs = pkgs'; };
            };
          labs = labsFor pkgs;
          labPkgs = import ./pkgs { inherit pkgs; };

          vms = import ./vm {
            inherit lib labsFor;
            inherit (inputs) nixpkgs;
            hostPkgs = pkgs;
            labsFlake = self;
          };
        in
        {
          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              nixfmt.enable = true;
              shfmt.enable = true;
            };
          };

          packages =
            labPkgs
            // vms
            // {
              inherit (pkgs) libsigrok-sipeed;
            };

          devShells = lib.mapAttrs (_: l: l.devShell) labs // {
            # Maintainer shell for this repo.
            default = pkgs.mkShellNoCC {
              packages = with pkgs; [
                nixfmt
                shfmt
                shellcheck
                statix
                deadnix
              ];
            };
          };

          checks = {
            statix = pkgs.runCommand "statix" { nativeBuildInputs = [ pkgs.statix ]; } ''
              statix check ${self}
              touch $out
            '';
            deadnix = pkgs.runCommand "deadnix" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
              deadnix --fail ${self}
              touch $out
            '';
            # writeShellApplication shellchecks at build time: build the CLI and
            # the VM runner's script body (the runner itself would build a whole
            # guest system, so only its text is checked here).
            lab-cli = labPkgs.lab;
            vm-runner-script = pkgs.writeShellApplication {
              name = "lab-vm-runner-check";
              runtimeInputs = [ pkgs.usbredir ];
              text = builtins.readFile ./vm/runner.sh;
            };
            # Eval-only: every environment's shell derivation on this system
            # and — from Linux — on aarch64-darwin, the NixOS + home-manager
            # module plumbing, and the VM packages' derivations.
            eval-shells = import ./checks/eval-shells.nix {
              inherit pkgs lib labs;
              label = system;
            };
            eval-vms = pkgs.writeText "eval-vms-${system}" (
              lib.concatMapStringsSep "\n" (p: builtins.unsafeDiscardStringContext p.drvPath) (lib.attrValues vms)
              + "\n"
            );
          }
          // lib.optionalAttrs (system == "x86_64-linux") {
            eval-shells-darwin =
              let
                darwinPkgs = import nixpkgs { system = "aarch64-darwin"; };
              in
              import ./checks/eval-shells.nix {
                # host pkgs write the result; the shells are darwin's
                inherit pkgs lib;
                labs = labsFor darwinPkgs;
                label = "aarch64-darwin";
              };
            eval-modules = import ./checks/eval-modules.nix {
              inherit self system;
              inherit (inputs) nixpkgs home-manager;
            };
          };
        };
    };
}
