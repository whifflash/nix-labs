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

        # pulseview-sipeed / sigrok-cli-sipeed (against nixpkgs' libsigrok-sipeed)
        # and the MCP servers, for consumers who prefer an overlay to `packages`.
        # `lab` is not here: it needs the catalogue and the rendered MCP configs,
        # so it comes from `packages.lab` or the home-manager module.
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
          slogic = {
            path = ./templates/slogic;
            description = "Logic-analyzer capture workspace pinned to the nix-labs slogic shell (direnv + MCP)";
          };
          cad = {
            path = ./templates/cad;
            description = "Parametric CAD workspace (build123d + OpenSCAD) pinned to the nix-labs cad shell";
          };
          eda = {
            path = ./templates/eda;
            description = "Circuit design + simulation workspace (KiCad, ngspice) pinned to the nix-labs eda shell";
          };
          ai = {
            path = ./templates/ai;
            description = "Project wired to the nix-labs ai shell (agents + MCP servers)";
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
          catalogue = import ./labs/catalogue.nix;

          # Several AI agents carry vendor licences nixpkgs marks unfree. Allow
          # exactly those, for the `ai` environment only — the rest of this
          # flake stays free-only.
          aiPkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfreePredicate =
              p:
              builtins.elem (lib.getName p) [
                "claude-code"
                "crush"
              ];
          };

          # Everything an environment needs, instantiated for a given package
          # set — used for the host system here and for the VM guest system.
          labsFor =
            pkgs':
            let
              labPkgs' = import ./pkgs { pkgs = pkgs'; };
              mcpServers' = import ./pkgs/mcp {
                pkgs = pkgs';
                labPkgs = labPkgs';
              };
            in
            import ./labs {
              pkgs = pkgs';
              inherit lib aiPkgs;
              labPkgs = labPkgs';
              mcpServers = mcpServers';
              mcpConfigs = mcpConfigsFor pkgs' mcpServers';
              zephyr = inputs.zephyr-nix.lib.mkZephyr { pkgs = pkgs'; };
            };

          mcpConfigsFor =
            pkgs': servers':
            pkgs'.callPackage ./pkgs/mcp-config.nix {
              inherit catalogue;
              servers = servers';
              mcpLib = self.lib.mcp;
            };

          labPkgs = import ./pkgs { inherit pkgs; };
          mcpServers = import ./pkgs/mcp { inherit pkgs labPkgs; };
          mcpConfigs = mcpConfigsFor pkgs mcpServers;
          labs = labsFor pkgs;

          lab = pkgs.callPackage ./pkgs/lab.nix { inherit catalogue mcpConfigs; };

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
            # `nix run labs#mcp-<name>` — what the generated configs invoke —
            # for every server, including the ones that are plain nixpkgs.
            // lib.mapAttrs' (n: s: lib.nameValuePair "mcp-${n}" s.package) mcpServers
            // {
              inherit lab mcpConfigs;
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
            lab-cli = lab;
            # The three MCP wire formats parse, and every environment that claims
            # servers really gets them (see docs/MCP.md).
            mcp-render = import ./checks/mcp-render.nix {
              inherit
                pkgs
                lib
                mcpConfigs
                catalogue
                ;
            };
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
