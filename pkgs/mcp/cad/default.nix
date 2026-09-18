# mcp-cad — our MCP server for parametric CAD.
#
# build123d does the modelling and f3d does the rendering, so the agent gets
# pictures of what it built rather than only numbers. OpenSCAD is wired in too,
# for the mesh/DSL half of the lab.
#
# A buildPython*Package* rather than an Application: `cad-watch` imports
# `mcp_cad.runner` so that the live preview and the agent build models exactly
# the same way. pkgs/default.nix turns it into the CLI with toPythonApplication.
{
  lib,
  buildPythonPackage,
  hatchling,
  mcp,
  build123d,
  f3d,
  openscad-unstable,
  makeWrapper,
}:
buildPythonPackage {
  pname = "mcp-cad";
  version = "0.1.0";
  pyproject = true;

  src = ./src;

  build-system = [ hatchling ];

  dependencies = [
    mcp
    build123d
  ];

  nativeBuildInputs = [ makeWrapper ];

  pythonImportsCheck = [
    "mcp_cad"
    "mcp_cad.runner"
  ];

  postFixup = ''
    wrapProgram $out/bin/mcp-cad \
      --set-default MCP_CAD_F3D ${lib.getExe f3d} \
      --set-default MCP_CAD_OPENSCAD ${lib.getExe openscad-unstable}
  '';

  meta = {
    description = "MCP server for build123d and OpenSCAD: run scripts, export STEP/STL/3MF, render previews, report mass properties";
    license = lib.licenses.mit;
    mainProgram = "mcp-cad";
    platforms = lib.platforms.unix;
  };
}
