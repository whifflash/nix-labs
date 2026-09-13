{
  description = "SDR workspace on nix-labs";

  inputs.nix-labs.url = "github:whifflash/nix-labs";

  outputs =
    { nix-labs, ... }:
    {
      # `direnv allow` / `nix develop` enters this shell (sdr-full adds GNU Radio,
      # SDRangel, SatDump). To add tools, replace the right-hand side with
      #   let pkgs = nix-labs.inputs.nixpkgs.legacyPackages.<system>; in
      #   pkgs.mkShell { inputsFrom = [ shells.sdr ]; packages = [ pkgs.<tool> ]; }
      devShells = builtins.mapAttrs (_: shells: { default = shells.sdr; }) nix-labs.devShells;
    };
}
