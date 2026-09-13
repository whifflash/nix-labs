{ lib }:
{
  # USB device catalogue: single source of truth for the udev rules, the VM
  # runners' default devices and docs/HARDWARE.md.
  hardware = import ./hardware.nix;

  # Environment catalogue (name → description, template, hardware, VM program).
  catalogue = import ../labs/catalogue.nix;

  # udevRules { devices ? <all>; group ? "plugdev"; } → rules text.
  udevRules = import ./udev-rules.nix { inherit lib; };

  # mkLab pkgs { name; description; packages; env; shellHook; … } → { devShell; … }
  mkLab = pkgs: import ./mk-lab.nix { inherit pkgs lib; };
}
