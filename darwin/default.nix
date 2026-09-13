# nix-darwin: `labs.enable` — the `labs` flake-registry entry. macOS needs no
# udev; libusb-based tools (sigrok, LimeSuite, SoapySDR) open devices directly.
{ lib, ... }:
{
  imports = [ ../modules/registry.nix ];

  options.labs.enable = lib.mkEnableOption "nix-labs host support (flake registry entry)";
}
