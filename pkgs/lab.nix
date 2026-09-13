# `lab` CLI: a thin, catalogue-aware front for `nix develop`/`nix flake init`/
# `nix run`, plus `lab mcp` which hands a project the MCP server configs
# rendered by ./mcp-config.nix. The flake reference defaults to the registry
# name `labs` (set by the NixOS/darwin module); LAB_FLAKE or the home-manager
# option `labs.flakeRef` point it elsewhere (local dev loop).
{
  lib,
  writeShellApplication,
  writeText,
  coreutils,
  jq,
  gnused,
  gnugrep,
  catalogue,
  mcpConfigs,
  flakeRef ? "labs",
}:
let
  catalogueJson = writeText "nix-labs-catalogue.json" (
    builtins.toJSON (
      lib.mapAttrs (_: l: {
        inherit (l) description template;
        vm = l.vm != null;
        linuxOnly = l.linuxOnly or false;
        mcp = l.mcp or [ ];
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
    gnugrep
  ];
  text =
    lib.replaceStrings
      [
        "@CATALOGUE@"
        "@MCPCONFIGS@"
        "@FLAKE@"
      ]
      [
        "${catalogueJson}"
        "${mcpConfigs}"
        flakeRef
      ]
      (builtins.readFile ./lab.sh);
  meta = {
    description = "Enter, list, scaffold and virtualise nix-labs environments, and wire up their MCP servers";
    mainProgram = "lab";
  };
}
