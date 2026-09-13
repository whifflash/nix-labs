# Shared between the NixOS and nix-darwin modules: the `labs` flake-registry
# entry so `nix develop labs#<env>` / `lab <env>` work on every host.
{ config, lib, ... }:
let
  cfg = config.labs;
in
{
  options.labs.registry = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register `labs` in the system flake registry (`nix develop labs#<env>`).";
    };
    name = lib.mkOption {
      type = lib.types.str;
      default = "labs";
      description = "Registry name. The `lab` CLI's default flake reference must match (home-manager `labs.flakeRef`).";
    };
    flake = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      example = lib.literalExpression "inputs.nix-labs";
      description = ''
        Pin the registry entry to a flake (typically the consumer's `inputs.nix-labs`), so
        `labs#…` resolves to the revision the system was built from — deterministic and
        cache-warm. When null, the entry points at `to` and Nix fetches the latest revision.
      '';
    };
    to = lib.mkOption {
      type = lib.types.attrs;
      default = {
        type = "github";
        owner = "whifflash";
        repo = "nix-labs";
      };
      description = "Flake reference used when `flake` is null.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.registry.enable) {
    nix.registry.${cfg.registry.name} =
      if cfg.registry.flake != null then
        { inherit (cfg.registry) flake; }
      else
        { inherit (cfg.registry) to; };
  };
}
