# Circuit design and simulation: KiCad for schematic capture and PCB layout,
# ngspice/Xyce/Qucs-s/xschem for making the circuit tell you what it will do
# before you order the board, and gerbv/KLayout for checking what you ordered.
#
# KiCad, xschem, Xyce, LibrePCB, Horizon EDA and openEMS are Linux-only in
# nixpkgs; the simulation core (ngspice, Qucs-s) and the viewers build on macOS
# too, so the environment exists on both — `lab vm eda` is the way to run KiCad
# itself on a Mac.
{
  pkgs,
  lib,
  labPkgs,
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux;

  # python312, not the default 3.13: skidl's `future` dependency does not build
  # on 3.13 in this nixpkgs.
  python = pkgs.python312.withPackages (
    p: with p; [
      skidl # describe a netlist in Python, emit a KiCad schematic
      numpy
      scipy
      matplotlib
      pandas
    ]
  );
in
{
  eda = {
    packages =
      with pkgs;
      [
        # Simulation
        ngspice # the SPICE engine everything else drives
        qucs-s # schematic front-end for ngspice/Xyce/Qucsator
        # Manufacturing output + inspection
        gerbv # gerber viewer
        klayout # GDS/OASIS layout viewer
        freerouting # autorouter KiCad can hand a board to
        python
      ]
      ++ lib.optionals isLinux [
        kicad # schematic capture, PCB layout, kicad-cli
        kicadAddons.kikit # panelisation, fab exports (needs kicad)
        interactive-html-bom # clickable BOM for assembly (needs kicad)
        xschem # schematic capture aimed at ngspice
        xyce # parallel SPICE engine (Sandia)
        gnucap # another circuit simulator, good for teaching/AC analysis
        gaw # waveform viewer for ngspice output
        librepcb # alternative EDA suite
        horizon-eda # alternative EDA suite
        openems # FDTD field solver (antennas, transmission lines)
        elmerfem # multiphysics FEM (thermal, magnetostatics)
        labPkgs.mcp-kicad # agent access to projects/netlists/BOM/DRC
      ];

    # Where KiCad-MCP and kicad-cli look for projects when nothing else says.
    env.KICAD_SEARCH_PATHS = "$PWD";

    shellHook = ''
      ${
        if isLinux then
          ''
            echo "  design: kicad | librepcb | horizon-eda      route: freerouting"
          ''
        else
          ''
            echo "  note:  KiCad is not in nixpkgs for macOS — install it from kicad.org,"
            echo "         or run it inside the VM: lab vm eda"
          ''
      }
      echo "  sim:    qucs-s | ngspice -b sim/rc.cir${lib.optionalString isLinux " | xschem | Xyce"}"
      echo "  check:  gerbv | klayout | python -c 'import skidl'"
    '';
  };
}
