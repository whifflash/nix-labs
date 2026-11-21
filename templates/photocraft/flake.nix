{
  description = "Image-editing workspace on nix-labs (PhotoCraft)";

  inputs.nix-labs.url = "github:whifflash/nix-labs";

  outputs =
    { nix-labs, ... }:
    {
      # `direnv allow` / `nix develop` puts photocraft, photocraft-cli and the MCP
      # server on PATH. To add tools, replace the right-hand side with
      #   let pkgs = nix-labs.inputs.nixpkgs.legacyPackages.<system>; in
      #   pkgs.mkShell { inputsFrom = [ shells.photocraft ]; packages = [ pkgs.<tool> ]; }
      devShells = builtins.mapAttrs (_: shells: { default = shells.photocraft; }) nix-labs.devShells;
    };
}
