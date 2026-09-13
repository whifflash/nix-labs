{
  description = "Zephyr application on nix-labs";

  inputs.nix-labs.url = "github:whifflash/nix-labs";

  outputs =
    { nix-labs, ... }:
    {
      # Variant: zephyr-arm | zephyr-riscv | zephyr-esp32 | zephyr-full
      # (`lab init zephyr-<variant>` rewrites the line below.) To add tools:
      #   let pkgs = nix-labs.inputs.nixpkgs.legacyPackages.<system>; in
      #   pkgs.mkShell { inputsFrom = [ shells.zephyr-arm ]; packages = [ pkgs.<tool> ]; }
      devShells = builtins.mapAttrs (_: shells: { default = shells.zephyr-arm; }) nix-labs.devShells;
    };
}
