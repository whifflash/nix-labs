# A python3 carrying the build123d stack.
#
# build123d and its OCP bindings are not in nixpkgs, so they are added here as a
# `packageOverrides` layer rather than as loose derivations: the lab shell, the
# `cad-watch` runner and the `mcp-cad` server then all share one interpreter and
# one OCCT, instead of three subtly different ones.
#
# `f3d` comes from pkgs/default.nix (cadViewer) so the MCP server wraps the
# same USD-less-on-darwin build the rest of the cad tooling uses.
{
  pkgs,
  f3d,
}:
let
  python = pkgs.python3.override {
    self = python;
    packageOverrides =
      pyfinal: _pyprev:
      # Laziness resolves the apparent cycle: cadquery-ocp needs the proxy from
      # simple-wheels, and ocpsvg/ocp-gordon in simple-wheels need cadquery-ocp.
      (pkgs.callPackage ./simple-wheels.nix {
        inherit (pyfinal)
          buildPythonPackage
          numpy
          scipy
          svgelements
          cadquery-ocp
          ;
      })
      // {
        cadquery-ocp = pyfinal.callPackage ./cadquery-ocp.nix { };
        build123d = pyfinal.callPackage ./build123d.nix { };
        # Our own: a library so `cad-watch` can import the same runner the MCP
        # server uses; pkgs/default.nix exposes the CLI via toPythonApplication.
        mcp-cad = pyfinal.callPackage ../mcp/cad { inherit f3d; };
      };
  };
in
{
  inherit python;

  # The interpreter the lab, the watcher and the MCP server all use.
  pythonEnv = python.withPackages (
    ps: with ps; [
      build123d
      # mesh-side tools, for post-processing exports
      trimesh
      numpy-stl
      meshio
      manifold3d
      numpy
      scipy
    ]
  );
}
