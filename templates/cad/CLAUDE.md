# Agent notes — the `cad` environment

The toolchain in this shell is already complete. Do not create a venv, run pip, or
`nix shell` extra packages: `python3` (3.13) has build123d, trimesh, meshio,
manifold3d and numpy, and the lab's PYTHONPATH is exported into every subprocess —
a venv built beside it resolves the wrong site-packages and breaks in confusing
ways. If something seems missing, it is `build123d`'s job, not pip's.

- Reach for **build123d** (`from build123d import *`) unless the part is trivial
  or you are remixing an existing `.scad`. OpenSCAD is mesh/CSG only — no STEP,
  hand-rolled fillet approximations.
- Units are **millimetres**. A model script assigns its finished solid to
  **`result`** (or passes it to `show_object()`) — `cad-watch` and the MCP server
  both look for that name.
- Generated geometry goes to `build/` and is gitignored. The script is the source
  of truth, never the export.
- Verify before declaring done: `result.is_valid`, `.bounding_box().size`,
  `.volume` — straight from the kernel, not a tessellation. Unsure of an API?
  The MCP `list_api` tool beats guessing; invented method names are the classic
  generated-CAD failure mode.
- The edit loop is `cad-watch model.py`: save in any editor, the script re-runs,
  f3d reloads the export. `--format step` shows exact surfaces; `--no-viewer`
  just rebuilds (over ssh).
- If the MCP tools (`run`, `measure`, `preview`, `list_api`) are not connected:
  `lab mcp cad --write` in the project directory, or start the client as
  `claude --mcp-config "$LAB_MCP_CONFIG"` (set inside every `lab cad` shell).
- macOS: no slicer in this shell (nixpkgs' PrusaSlicer/OrcaSlicer need
  webkitgtk, broken on darwin) — export STL and slice in a PrusaSlicer or
  OrcaSlicer installed from their own releases.
