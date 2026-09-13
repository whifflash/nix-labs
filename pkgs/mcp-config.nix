# Pre-rendered MCP configs, one directory per environment:
#
#   <env>/canonical.json   Claude Code / gemini-cli / qwen-code / pi
#   <env>/opencode.json    opencode
#   <env>/codex.toml       codex ([mcp_servers.*] tables to merge)
#   <env>/store.json       canonical, but with absolute store paths
#
# Generating these at build time means `lab mcp` is a `cat`, the templates ship
# working configs, and every lab shell can export LAB_MCP_CONFIG.
{
  lib,
  runCommand,
  formats,
  mcpLib,
  servers,
  catalogue,
  flakeRef ? "labs",
}:
let
  json = formats.json { };

  forEnv =
    env: meta:
    let
      names = meta.mcp or [ ];
      picked = lib.getAttrs (lib.filter (n: servers ? ${n}) names) servers;
      args = {
        servers = picked;
        inherit flakeRef;
      };
    in
    lib.optionalAttrs (picked != { }) {
      "${env}/canonical.json" = json.generate "mcp-${env}.json" (mcpLib.canonical args);
      "${env}/store.json" = json.generate "mcp-${env}-store.json" (
        mcpLib.canonical (args // { storePaths = true; })
      );
      "${env}/opencode.json" = json.generate "mcp-${env}-opencode.json" (mcpLib.opencode args);
      "${env}/codex.toml" = builtins.toFile "mcp-${env}-codex.toml" (mcpLib.codex args);
    };

  files = lib.foldl' lib.mergeAttrs { } (lib.mapAttrsToList forEnv catalogue);
in
runCommand "nix-labs-mcp-configs" { passthru.environments = lib.attrNames catalogue; } (
  lib.concatStrings (
    lib.mapAttrsToList (rel: file: ''
      mkdir -p "$out/$(dirname ${rel})"
      cp ${file} "$out/${rel}"
    '') files
  )
  + ''
    mkdir -p "$out"
  ''
)
