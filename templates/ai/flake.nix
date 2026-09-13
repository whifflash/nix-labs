{
  description = "Project wired to the nix-labs ai shell";

  inputs.nix-labs.url = "github:whifflash/nix-labs";

  outputs =
    { nix-labs, ... }:
    {
      # `direnv allow` / `nix develop` puts the agents and their tooling on PATH.
      # To add project tools, replace the right-hand side with
      #   let pkgs = nix-labs.inputs.nixpkgs.legacyPackages.<system>; in
      #   pkgs.mkShell { inputsFrom = [ shells.ai ]; packages = [ pkgs.<tool> ]; }
      devShells = builtins.mapAttrs (_: shells: { default = shells.ai; }) nix-labs.devShells;
    };
}
