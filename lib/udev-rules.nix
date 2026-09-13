# Generate udev rules from lib/hardware.nix.
#
# Every listed device becomes accessible to the logged-in seat (TAG+="uaccess",
# handled by systemd-logind) and to members of `group`. Entries without a pid
# match the whole vendor. Device families flagged `mmIgnore` additionally get
# ENV{ID_MM_DEVICE_IGNORE}="1" so ModemManager does not probe debug probes and
# serial bridges (which would hijack the port for seconds after plug-in).
{ lib }:
{
  devices ? import ./hardware.nix,
  group ? "plugdev",
}:
let
  rule =
    dev: id:
    lib.concatStringsSep ", " (
      [
        ''SUBSYSTEM=="usb"''
        ''ATTRS{idVendor}=="${id.vid}"''
      ]
      ++ lib.optional (id ? pid) ''ATTRS{idProduct}=="${id.pid}"''
      ++ [
        ''MODE="0660"''
        ''GROUP="${group}"''
        ''TAG+="uaccess"''
      ]
      ++ lib.optional (dev.mmIgnore or false) ''ENV{ID_MM_DEVICE_IGNORE}="1"''
    );

  block =
    name: dev:
    ''
      # ${name}: ${dev.description}
    ''
    + lib.concatMapStringsSep "\n" (rule dev) dev.udev
    + "\n";
in
''
  # nix-labs — user access to lab hardware (logic analyzers, SDRs, debug probes,
  # USB-serial bridges). Generated from lib/hardware.nix; do not edit by hand.
  ACTION!="add|change", GOTO="nix_labs_end"

''
+ lib.concatStringsSep "\n" (lib.mapAttrsToList block devices)
+ ''

  LABEL="nix_labs_end"
''
