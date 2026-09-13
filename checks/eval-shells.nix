# Eval-only check: force the derivation of every environment's devShell for
# the package set `labs` was built from (possibly another system than the one
# writing the result). Catches missing/unsupported packages per platform.
{
  pkgs, # host pkgs — only used to write the result
  lib,
  labs,
  label,
}:
pkgs.writeText "eval-shells-${label}" (
  lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: lab: "${name} ${builtins.unsafeDiscardStringContext lab.devShell.drvPath}"
    ) labs
  )
  + "\n"
)
