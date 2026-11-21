# mcp-photocraft — PhotoCraft's own MCP server (`photocraft-cli mcp`, stdio),
# with the filesystem authority an agent in a project needs.
#
# Upstream fails closed: without --automation-read-root/--automation-write-root
# the server can neither open nor save a file, which leaves an agent able to
# edit only documents it created in memory. The project's MCP config starts
# the server in the project directory, so that is the default for both roots
# (MCP_PHOTOCRAFT_ROOT overrides it). The CLI takes the last occurrence of a
# flag, so explicit roots — or `--bridge 127.0.0.1:<port> --control-token-file
# <path>` to drive a running `photocraft --control <port>`, where the app's
# own roots apply — still work when appended.
{
  writeShellApplication,
  photocraft,
}:
writeShellApplication {
  name = "mcp-photocraft";
  runtimeInputs = [ photocraft ];
  text = ''
    root=''${MCP_PHOTOCRAFT_ROOT:-$PWD}
    exec photocraft-cli mcp --automation-read-root "$root" --automation-write-root "$root" "$@"
  '';
  meta = {
    description = "PhotoCraft's MCP server (headless engine, or bridged to the running app), rooted at the project directory";
    mainProgram = "mcp-photocraft";
    inherit (photocraft.meta) license platforms;
  };
}
