# The MCP renderers produce three different wire formats; this asserts that all
# three parse, that every catalogue environment claiming servers actually gets
# them, and that the commands point somewhere real. Cheap — no server is run.
{
  pkgs,
  lib,
  mcpConfigs,
  catalogue,
}:
let
  withMcp = lib.filterAttrs (_: m: (m.mcp or [ ]) != [ ]) catalogue;
  expected = lib.concatStringsSep " " (lib.attrNames withMcp);
in
pkgs.runCommand "mcp-render-check"
  {
    nativeBuildInputs = [
      pkgs.jq
      pkgs.python3
    ];
    inherit expected;
  }
  ''
    fail() { echo "mcp-render: $*" >&2; exit 1; }

    for env in $expected; do
      dir="${mcpConfigs}/$env"
      [ -d "$dir" ] || fail "$env has MCP servers in the catalogue but no rendered config"

      # Canonical (Claude Code / gemini / qwen / pi): a non-empty mcpServers map
      # where every entry has a command.
      for file in canonical.json store.json; do
        jq -e '.mcpServers | length > 0' "$dir/$file" >/dev/null || fail "$env/$file: no servers"
        jq -e '[.mcpServers[] | select((.command // "") == "")] | length == 0' "$dir/$file" >/dev/null ||
          fail "$env/$file: a server has no command"
      done

      # store.json must name real store paths that exist and are executable.
      while read -r cmd; do
        [ -x "$cmd" ] || fail "$env/store.json: $cmd is not an executable store path"
      done < <(jq -r '.mcpServers[].command' "$dir/store.json")

      # canonical.json must go through `nix run <flake>#mcp-<name>` instead, so a
      # committed project file survives garbage collection.
      jq -e '[.mcpServers[] | select(.command != "nix")] | length == 0' "$dir/canonical.json" >/dev/null ||
        fail "$env/canonical.json: expected every command to be `nix run …`"

      # opencode: argv ARRAY, type=local, enabled.
      jq -e '.mcp | length > 0' "$dir/opencode.json" >/dev/null || fail "$env/opencode.json: no servers"
      jq -e '[.mcp[] | select((.type != "local") or (.enabled != true) or ((.command | type) != "array"))] | length == 0' \
        "$dir/opencode.json" >/dev/null || fail "$env/opencode.json: wrong shape for a local server"

      # codex: valid TOML with one [mcp_servers.<name>] table per server.
      python3 - "$dir/codex.toml" "$dir/canonical.json" <<'PY' || fail "$env/codex.toml: invalid or incomplete"
    import json, sys, tomllib
    toml = tomllib.load(open(sys.argv[1], "rb"))
    want = set(json.load(open(sys.argv[2]))["mcpServers"])
    got = set(toml.get("mcp_servers", {}))
    assert got == want, f"{got} != {want}"
    assert all(t.get("command") for t in toml["mcp_servers"].values())
    PY
    done

    echo "mcp-render: ok for: $expected"
    touch $out
  ''
