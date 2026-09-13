# Logic analyzer: sigrok with the Sipeed SLogic driver.
#
# nixpkgs ships `libsigrok-sipeed` (Sipeed's slogic-dev branch, driver
# `sipeed-slogic-analyzer`, Combo8/16U3/32U3); PulseView and sigrok-cli are
# rebuilt against it in ../../pkgs. The driver is plain libusb, so this works
# natively on Linux and macOS; `lab vm logic` is the fallback.
{
  pkgs,
  lib,
  labPkgs,
}:
{
  logic = {
    packages = [
      labPkgs.pulseview-sipeed
      labPkgs.sigrok-cli-sipeed
      pkgs.libsigrok-sipeed
      pkgs.sigrok-firmware-fx2lafw # for the cheap fx2 "Saleae clone" analyzers
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.usbutils ];

    # libsigrok-sipeed copies the fx2lafw blobs into its own share dir.
    env.SIGROK_FIRMWARE_DIR = "${pkgs.libsigrok-sipeed}/share/sigrok-firmware";

    shellHook = ''
      echo "  scan:  sigrok-cli --driver sipeed-slogic-analyzer --scan"
      echo "  gui:   pulseview"
    '';
  };
}
