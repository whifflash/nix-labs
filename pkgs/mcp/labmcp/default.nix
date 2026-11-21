# labmcp — the parts of docs/MCP-RULES.md that are code rather than judgement,
# shared by our own MCP servers (mcp-cad, mcp-soapysdr): stdout protection,
# rejecting unknown arguments, a workspace root for files, and the tool
# annotation presets. callPackage'd from each server's own Python package set.
{
  lib,
  buildPythonPackage,
  hatchling,
  mcp,
}:
buildPythonPackage {
  pname = "labmcp";
  version = "0.1.0";
  pyproject = true;

  src = ./src;

  build-system = [ hatchling ];
  dependencies = [ mcp ];

  pythonImportsCheck = [ "labmcp" ];

  meta = {
    description = "Shared plumbing for the nix-labs MCP servers";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
