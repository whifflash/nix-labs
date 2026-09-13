{
  description = "Circuit design + simulation workspace on nix-labs";

  inputs.nix-labs.url = "github:whifflash/nix-labs";

  outputs =
    { nix-labs, ... }:
    {
      # `direnv allow` / `nix develop` enters this shell. To add tools, replace the
      # right-hand side with
      #   let pkgs = nix-labs.inputs.nixpkgs.legacyPackages.<system>; in
      #   pkgs.mkShell { inputsFrom = [ shells.eda ]; packages = [ pkgs.<tool> ]; }
      devShells = builtins.mapAttrs (_: shells: { default = shells.eda; }) nix-labs.devShells;
    };
}
