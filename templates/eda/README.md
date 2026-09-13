# Circuit design + simulation workspace

Pinned to the `eda` environment of [nix-labs](https://github.com/whifflash/nix-labs):
KiCad (Linux), ngspice, Qucs-s, gerbv, KLayout, FreeRouting and a Python with SKiDL.
`.mcp.json` / `opencode.json` wire the KiCad MCP server into the agent you use here.

```sh
direnv allow                  # or: nix develop

# Simulation — works everywhere, no GUI, no hardware:
ngspice -b sim/rc.cir         # prints the -3 dB corner and the settled step value
qucs-s                        # schematic front-end driving ngspice/Xyce

# Design (Linux; on macOS install KiCad from kicad.org or run `lab vm eda`):
kicad                         # schematic capture + PCB layout
kicad-cli sch export netlist board.kicad_sch -o board.net
kicad-cli pcb drc board.kicad_pcb -o drc.rpt
gerbv gerbers/*.gbr           # check what you are about to order
```

Ask the agent things like *"what nets connect to U1 pin 3"*, *"run DRC and summarise"*,
or *"analyse the BOM"* — those go through the `kicad` MCP server, which reads this
directory (`KICAD_SEARCH_PATHS` defaults to the project).

Re-pin the environment: `nix flake update nix-labs`.
