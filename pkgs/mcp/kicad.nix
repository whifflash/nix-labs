# KiCad MCP server (lamaalrajih/kicad-mcp): projects, netlists, BOM, DRC (via
# kicad-cli), board visualisation, circuit-pattern recognition.
#
# `kicad` is Linux-only in nixpkgs, so KICAD_CLI_PATH is pre-set only there; on
# macOS the server still runs and finds a KiCad installed from kicad.org (it
# looks in the standard application paths, and KICAD_CLI_PATH overrides).
{
  lib,
  python3Packages,
  fetchFromGitHub,
  makeWrapper,
  kicad,
}:
let
  haveKicad = kicad.meta.available or false;
in
python3Packages.buildPythonApplication {
  pname = "mcp-kicad";
  version = "0.1.0-unstable-2025-10-17";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "lamaalrajih";
    repo = "kicad-mcp";
    rev = "98c9ea41cb393393a8bafd157a93e84431e00afb";
    hash = "sha256-45+uc0QMqQKCRkmUOq/+F36Ap4Ab3iiJy0kTqDz2SeI=";
  };

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    mcp
    fastmcp
    pandas
    pyyaml
    defusedxml
  ];

  # Upstream pins fastmcp>=2; nixpkgs carries 3.x. The server only uses the
  # FastMCP surface that survived the major bump (tools/resources/prompts) —
  # pythonImportsCheck below is what actually proves that.
  pythonRelaxDeps = [ "fastmcp" ];

  nativeBuildInputs = [ makeWrapper ];

  # The repo's tests need a KiCad installation and sample projects.
  doCheck = false;
  pythonImportsCheck = [
    "kicad_mcp"
    "kicad_mcp.server"
  ];

  postFixup = lib.optionalString haveKicad ''
    wrapProgram $out/bin/kicad-mcp \
      --set-default KICAD_CLI_PATH ${lib.getBin kicad}/bin/kicad-cli
  '';

  meta = {
    description = "MCP server for KiCad: project, netlist, BOM, DRC and PCB analysis";
    homepage = "https://github.com/lamaalrajih/kicad-mcp";
    license = lib.licenses.mit;
    mainProgram = "kicad-mcp";
    platforms = lib.platforms.unix;
  };
}
