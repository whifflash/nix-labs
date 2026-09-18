# Parametric CAD workspace

Pinned to the `cad` environment of [nix-labs](https://github.com/whifflash/nix-labs). Two
engines, both driven from text you can keep in git:

- **`model.py`** — [build123d](https://build123d.readthedocs.io/): Python on the OpenCASCADE
  kernel. Real solids, so fillets and chamfers are exact and it exports **STEP** (CNC, further
  CAD) as well as STL/3MF (printing). This is the one to reach for.
- **`part.scad`** — OpenSCAD's DSL. Quick for simple parts, and what most published parametric
  models are written in. Mesh only — no STEP.

```sh
direnv allow                  # or: nix develop

cad-watch model.py            # edit in your editor; f3d reloads on every save
python model.py               # one-shot: writes build/bracket.step and .stl

openscad part.scad            # GUI; Design → Automatic Reload and Preview
openscad -o build/part.stl part.scad
```

`cad-watch` runs the script on save, exports it, and leaves f3d watching the file — so the loop
works with whatever editor you already use. `--format step` hands the viewer the exact surfaces
instead of a mesh; `--no-viewer` just rebuilds (handy over ssh).

The agent side is wired up in `.mcp.json` / `opencode.json`: ask for a part and it can run the
script, measure it exactly (volume, centre of mass, bounding box straight from the kernel),
render a picture of it, and export STEP/STL. If it is unsure of an API it can call `list_api`
rather than guess.

Conventions worth knowing: a model script assigns its finished solid to **`result`** (or passes
it to `show_object()`), and everything is in **millimetres**.

Re-pin the environment: `nix flake update nix-labs`.
