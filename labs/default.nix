# All environments for one package set: catalogue metadata + per-environment
# package lists → mkLab records ({ devShell; packages; usb; vm; … }).
{
  pkgs,
  lib,
  labPkgs,
  zephyr,
}:
let
  catalogue = import ./catalogue.nix;
  mkLab = import ../lib/mk-lab.nix { inherit pkgs lib; };

  defs =
    import ./zephyr { inherit pkgs lib zephyr; }
    // import ./sdr { inherit pkgs lib; }
    // import ./logic { inherit pkgs lib labPkgs; }
    // import ./platformio { inherit pkgs lib; };

  # Linux-only environments simply do not exist on darwin (see labs/platformio).
  expected = lib.filterAttrs (
    _: m: pkgs.stdenv.hostPlatform.isLinux || !(m.linuxOnly or false)
  ) catalogue;

  missing = lib.subtractLists (lib.attrNames defs) (lib.attrNames expected);
  extra = lib.subtractLists (lib.attrNames expected) (lib.attrNames defs);
in
assert lib.assertMsg (
  missing == [ ]
) "labs/catalogue.nix lists environments without a definition: ${toString missing}";
assert lib.assertMsg (
  extra == [ ]
) "labs/ defines environments missing from labs/catalogue.nix: ${toString extra}";
lib.mapAttrs (name: def: mkLab (catalogue.${name} // def // { inherit name; })) defs
