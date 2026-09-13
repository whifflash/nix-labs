# mkLab: one environment record → its devShell plus the metadata the other
# outputs (the `lab` CLI, the udev module, the VM runner, the docs) read.
#
#   { name; description; packages; env = { VAR = "…"; }; shellHook; usb = [ <hardware.nix keys> ];
#     vm = null | { program = "<binary on PATH>"; }; template = "<templates/ dir>";
#     shell = null | <derivation> (a ready-made shell, e.g. buildFHSEnv's .env, which
#             cannot be assembled from a package list — packages/env/shellHook are then unused) }
{ pkgs, lib }:
{
  name,
  description,
  packages ? [ ],
  env ? { },
  shellHook ? "",
  usb ? [ ],
  vm ? null,
  template ? null,
  shell ? null,
  linuxOnly ? false,
  mcp ? [ ],
}:
let
  banner = ''
    if [ -z "''${LAB_QUIET:-}" ]; then
      printf '\033[1m[nix-labs] %s\033[0m — %s\n' ${lib.escapeShellArg name} ${lib.escapeShellArg description}
    fi
  '';
in
{
  inherit
    name
    description
    packages
    usb
    vm
    template
    linuxOnly
    mcp
    ;

  # mkShell (with a host compiler: Zephyr's native_sim, Python wheels and the
  # occasional out-of-tree tool need one). Extra attrs become environment
  # variables inside the shell.
  devShell =
    if shell != null then
      shell
    else
      pkgs.mkShell (
        {
          inherit name packages;
          shellHook = banner + shellHook;
        }
        // env
      );
}
