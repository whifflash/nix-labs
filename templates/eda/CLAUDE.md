# Agent notes — the `eda` environment

Circuit design + simulation. The toolchain is complete — do not create a venv or
pip-install: this shell's `python3` is **3.12**, not 3.13 (skidl's `future`
dependency does not build on 3.13), with skidl/numpy/scipy/matplotlib/pandas.

- **Simulate before ordering**: `ngspice -b sim/<file>.cir` is the engine; qucs-s
  is the schematic front-end driving it. SPICE sources live in `sim/`.
- **macOS**: KiCad is not in nixpkgs for darwin — install it from kicad.org (the
  MCP server finds that binary) or run `lab vm eda`. Simulation (ngspice, qucs-s)
  and the viewers (gerbv, klayout) work natively; xschem/Xyce/openEMS/elmerfem
  are Linux-only.
- The `kicad` MCP tools (netlists, net↔pin lookups, DRC, BOM) read projects from
  this directory — `KICAD_SEARCH_PATHS` is preset to `$PWD`. Questions like
  "what nets connect to U1 pin 3" or "run DRC and summarise" go through them.
- If the MCP tools are not connected: `lab mcp eda --write` (entering via
  `lab eda` wires them automatically), or start the client with
  `claude --mcp-config "$LAB_MCP_CONFIG"`.
- Verify what you are about to order: `gerbv gerbers/*.gbr` before sending
  anything to a fab.
