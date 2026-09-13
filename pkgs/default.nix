# Packages this flake adds on top of nixpkgs (also exposed as overlays.default).
{ pkgs }:
{
  # sigrok frontends linked against nixpkgs' libsigrok-sipeed (Sipeed's
  # slogic-dev branch with the `sipeed-slogic-analyzer` driver). Only the
  # library differs; PulseView/sigrok-cli sources are the nixpkgs ones.
  pulseview-sipeed = pkgs.pulseview.override { libsigrok = pkgs.libsigrok-sipeed; };
  sigrok-cli-sipeed = pkgs.sigrok-cli.override { libsigrok = pkgs.libsigrok-sipeed; };

  # `lab` — list / enter / scaffold / virtualise environments.
  lab = pkgs.callPackage ./lab.nix { catalogue = import ../labs/catalogue.nix; };
}
