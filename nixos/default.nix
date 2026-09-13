# NixOS: `labs.enable` — hardware access for the lab environments (udev rules,
# plugdev/dialout for `labs.users`) and the `labs` flake-registry entry. No lab
# software enters the system closure; the environments are `nix develop` shells.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.labs;
  udevRules = import ../lib/udev-rules.nix { inherit lib; };
  rulesPkg = pkgs.writeTextDir "lib/udev/rules.d/70-nix-labs.rules" (udevRules {
    inherit (cfg.udev) group;
  });
in
{
  imports = [ ../modules/registry.nix ];

  options.labs = {
    enable = lib.mkEnableOption "nix-labs host support (udev rules for lab hardware, device groups, flake registry entry)";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "alice" ];
      description = "Users added to the device groups (`udev.group` and `dialout`) so they can open USB lab hardware and serial consoles without sudo.";
    };

    udev = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the generated 70-nix-labs.rules (see lib/hardware.nix and docs/HARDWARE.md).";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "plugdev";
        description = "Group that owns the lab USB devices (created if missing).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.udev.packages = lib.mkIf cfg.udev.enable [ rulesPkg ];

    users.groups = {
      ${cfg.udev.group} = { };
      dialout = { };
    };

    users.users = lib.genAttrs cfg.users (_: {
      extraGroups = [
        cfg.udev.group
        "dialout"
      ];
    });
  };
}
