# home-manager (Linux + macOS): the `lab` CLI and direnv/nix-direnv so the
# project templates' `.envrc` (`use flake`) activate environments on cd.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.labs;

  catalogue = import ../labs/catalogue.nix;
  labPkgs = import ../pkgs { inherit pkgs; };
  # Rendering MCP configs needs only pkgs + the catalogue (never the zephyr
  # input), which is why pkgs/mcp is kept independent of labs/.
  mcpConfigs = pkgs.callPackage ../pkgs/mcp-config.nix {
    inherit catalogue;
    inherit (cfg) flakeRef;
    servers = import ../pkgs/mcp { inherit pkgs labPkgs; };
    mcpLib = import ../lib/mcp.nix { inherit lib; };
  };
in
{
  options.labs = {
    cli.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the `lab` helper (list / enter / init / vm / mcp) on PATH.";
    };

    flakeRef = lib.mkOption {
      type = lib.types.str;
      default = "labs";
      example = "path:/home/me/src/nix-labs";
      description = ''
        Flake reference `lab` uses. `labs` is the registry entry the nix-labs NixOS/darwin
        module sets; a path reference gives a local dev loop. LAB_FLAKE overrides at runtime.
      '';
    };

    direnv.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable programs.direnv + nix-direnv (as mkDefault) for the template projects.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.cli.enable {
      home.packages = [
        (pkgs.callPackage ../pkgs/lab.nix {
          inherit (cfg) flakeRef;
          inherit catalogue mcpConfigs;
        })
      ];
    })
    (lib.mkIf cfg.direnv.enable {
      programs.direnv = {
        enable = lib.mkDefault true;
        nix-direnv.enable = lib.mkDefault true;
      };
    })
  ];
}
