# Render an environment's MCP servers into the shapes the agents actually read.
#
# There are only three: the "canonical" `mcpServers` object that Claude Code
# established and that gemini-cli, qwen-code and pi's mcp-adapter all copied;
# opencode's `mcp` object (command as an argv ARRAY, `type` and `environment`);
# and codex's TOML. Everything else here is plumbing around those three.
#
#   servers = { <name> = { package; args ? [ ]; env ? { }; description; }; }
{ lib }:
let
  # Escape a Nix string for TOML (basic string: quotes and backslashes).
  tomlStr = s: ''"${lib.escape [ "\\" "\"" ] (toString s)}"'';
  tomlList = xs: "[${lib.concatMapStringsSep ", " tomlStr xs}]";

  # How a client should start the server. Two flavours:
  #   store paths — exact, fast, but a GC can take them away
  #   `nix run`   — portable and safe to commit; resolves via the `labs` registry
  command =
    {
      name,
      server,
      flakeRef,
      storePaths,
    }:
    if storePaths then
      {
        command = lib.getExe server.package;
        args = server.args or [ ];
      }
    else
      {
        command = "nix";
        args = [
          "run"
          "${flakeRef}#mcp-${name}"
        ]
        ++ lib.optionals ((server.args or [ ]) != [ ]) ([ "--" ] ++ server.args);
      };
in
rec {
  # { <name> = { command; args; env; } } — the canonical inner objects.
  entries =
    {
      servers,
      flakeRef ? "labs",
      storePaths ? false,
    }:
    lib.mapAttrs (
      name: server:
      (command {
        inherit
          name
          server
          flakeRef
          storePaths
          ;
      })
      // lib.optionalAttrs ((server.env or { }) != { }) { inherit (server) env; }
    ) servers;

  # Claude Code (.mcp.json), gemini-cli (.gemini/settings.json), qwen-code
  # (.qwen/settings.json), pi (.pi/mcp.json via pi-mcp-adapter), ~/.config/mcp/mcp.json
  canonical = args: { mcpServers = entries args; };

  # opencode.json — different enough to need its own shape.
  opencode =
    args:
    let
      es = entries args;
    in
    {
      "$schema" = "https://opencode.ai/config.json";
      mcp = lib.mapAttrs (
        _: e:
        {
          type = "local";
          command = [ e.command ] ++ e.args;
          enabled = true;
        }
        // lib.optionalAttrs (e ? env) { environment = e.env; }
      ) es;
    };

  # ~/.codex/config.toml — TOML, and codex merges it with the rest of that file,
  # so we emit only the [mcp_servers.*] tables.
  codex =
    args:
    let
      es = entries args;
      block =
        name: e:
        ''
          [mcp_servers.${name}]
          command = ${tomlStr e.command}
          args = ${tomlList e.args}
        ''
        + lib.optionalString (e ? env) (
          ''

            [mcp_servers.${name}.env]
          ''
          + lib.concatStrings (lib.mapAttrsToList (k: v: "${k} = ${tomlStr v}\n") e.env)
        );
    in
    lib.concatStringsSep "\n" (lib.mapAttrsToList block es);

  # Which file each client reads, relative to a project (or $HOME for codex).
  clientFiles = {
    claude = ".mcp.json";
    gemini = ".gemini/settings.json";
    qwen = ".qwen/settings.json";
    pi = ".pi/mcp.json";
    opencode = "opencode.json";
    codex = ".codex/config.toml";
  };

  # The renderer each client needs: canonical | opencode | codex.
  clientFormat = {
    claude = "canonical";
    gemini = "canonical";
    qwen = "canonical";
    pi = "canonical";
    opencode = "opencode";
    codex = "codex";
  };
}
