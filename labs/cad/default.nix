# Parametric CAD as code.
#
# build123d is the primary engine: Python on the OpenCASCADE B-rep kernel, so
# parts are real solids — fillets and chamfers are kernel operations, and the
# export is genuine STEP for CNC as well as STL/3MF for printing.
#
# OpenSCAD comes along for the ride: its DSL is quick for simple parts, and it is
# what the large body of existing parametric designs on the model sites is
# written in. It is mesh/CSG only — no STEP — which is why it is the second
# engine rather than the first. `solidpython2` bridges the two: write Python,
# emit .scad.
#
# Live preview is `cad-watch`: your editor saves, the script re-runs, f3d reloads
# the export. Nothing in the loop cares which editor you use.
{
  pkgs,
  lib,
  labPkgs,
}:
{
  cad = {
    packages = [
      labPkgs.pythonEnv # build123d + trimesh/meshio/manifold3d
      labPkgs.cad-watch # the live-preview loop
      labPkgs.mcp-cad # agent access: run, measure, preview, list_api
    ]
    ++ (with pkgs; [
      openscad-unstable # 2026 nightly: manifold CSG, far faster than 2021.01
      openscad-lsp # editor support for .scad
      python3Packages.solidpython2 # write Python, emit .scad
      f3d # viewer + the offscreen renderer the MCP server uses
      watchexec
    ])
    # Slicers: both pull wxGTK → webkitgtk, which nixpkgs marks broken on
    # darwin. On a Mac install PrusaSlicer/OrcaSlicer from their own releases;
    # the modelling half of this shell is unaffected.
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux (
      with pkgs;
      [
        prusa-slicer # STL/3MF → gcode
        orca-slicer
      ]
    );

    shellHook = ''
      echo "  model:   \$EDITOR model.py   then   cad-watch model.py   (f3d reloads on save)"
      echo "  scad:    openscad part.scad  (Design → Automatic Reload and Preview)"
      echo "  export:  STEP for CNC, STL/3MF for printing — build123d does both"
      echo "  agent:   lab mcp cad --write"
      ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
        echo "  note:    no slicer here — nixpkgs' PrusaSlicer/OrcaSlicer need webkitgtk,"
        echo "           which is broken on darwin; install them from prusa3d.com / orcaslicer.com"
      ''}
    '';
  };
}
