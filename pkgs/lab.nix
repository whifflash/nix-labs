# `lab` CLI: a thin, catalogue-aware front for `nix develop`/`nix flake init`/
# `nix run` against the nix-labs flake. The flake reference defaults to the
# registry name `labs` (set by the NixOS/darwin module); LAB_FLAKE or the
# home-manager option `labs.flakeRef` point it elsewhere (local dev loop).
{
  lib,
  writeShellApplication,
  writeText,
  coreutils,
  jq,
  gnused,
  catalogue,
  flakeRef ? "labs",
}:
let
  catalogueJson = writeText "nix-labs-catalogue.json" (
    builtins.toJSON (
      lib.mapAttrs (_: l: {
        inherit (l) description template;
        vm = l.vm != null;
        linuxOnly = l.linuxOnly or false;
      }) catalogue
    )
  );
in
writeShellApplication {
  name = "lab";
  runtimeInputs = [
    coreutils
    jq
    gnused
  ];
  text = lib.replaceStrings [ "@CATALOGUE@" "@FLAKE@" ] [ "${catalogueJson}" flakeRef ] (
    builtins.readFile ./lab.sh
  );
  meta = {
    description = "Enter, list, scaffold and virtualise nix-labs environments";
    mainProgram = "lab";
  };
}
