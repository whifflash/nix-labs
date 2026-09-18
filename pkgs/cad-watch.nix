# The live-preview loop: rebuild on save, let f3d reload the result.
#
# Uses the same runner as mcp-cad, so "what the agent builds" and "what you see
# while editing" cannot drift apart.
{
  lib,
  writeShellApplication,
  writeText,
  python,
  f3d,
  watchexec,
}:
let
  # Tiny CLI around mcp_cad.runner: script → exported file.
  runnerCli = writeText "cad-build.py" ''
    """Build one model file. Args: <script> <out-dir> <name> <format>."""
    import sys
    from pathlib import Path

    from mcp_cad import runner

    script, out_dir, name, fmt = sys.argv[1:5]
    path = Path(script)
    model = runner.run(path.read_text(), path=path, workdir=path.parent)
    written = runner.export(model.shape, Path(out_dir), name, [fmt])
    info = runner.measure(model.shape)
    print(
        f"{written[fmt]['path']}  {written[fmt]['bytes']}B  "
        f"volume={info['volume_mm3']}mm^3  valid={info['is_valid']}",
        file=sys.stderr,
    )
  '';

  pythonEnv = python.withPackages (ps: [ ps.mcp-cad ]);
in
writeShellApplication {
  name = "cad-watch";
  runtimeInputs = [
    f3d
    watchexec
  ];
  text =
    lib.replaceStrings
      [
        "@PYTHON@"
        "@F3D@"
        "@WATCHEXEC@"
        "@RUNNER@"
      ]
      [
        "${pythonEnv}/bin/python"
        (lib.getExe f3d)
        (lib.getExe watchexec)
        "${runnerCli}"
      ]
      (builtins.readFile ./cad-watch.sh);

  meta = {
    description = "Rebuild a build123d model on save and live-reload it in f3d";
    mainProgram = "cad-watch";
  };
}
