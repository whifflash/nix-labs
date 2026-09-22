# Logic analyzer: sigrok with the Sipeed SLogic driver.
#
# ../../pkgs builds `libsigrok-sipeed` from Sipeed's slogic-dev branch HEAD (driver
# `sipeed-slogic-analyzer`, Combo8/16U3/32U3); PulseView and sigrok-cli are
# rebuilt against it in ../../pkgs. The driver is plain libusb, so this works
# natively on Linux and macOS; `lab vm slogic` is the fallback.
{
  pkgs,
  lib,
  labPkgs,
}:
{
  slogic = {
    packages = [
      labPkgs.pulseview-sipeed
      labPkgs.sigrok-cli-sipeed
      labPkgs.mcp-sigrok # agent access: scan, capture, decode, render
      labPkgs.srdecode # text-side analysis: baud detect, UART frames, diffing
      # Scratch interpreter for ad-hoc capture analysis; same interpreter
      # srdecode wraps, so the numpy in the closure is shared, not duplicated.
      (pkgs.python3.withPackages (ps: [ ps.numpy ]))
      labPkgs.libsigrok-sipeed
      pkgs.sigrok-firmware-fx2lafw # for the cheap fx2 "Saleae clone" analyzers
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.usbutils ];

    # libsigrok-sipeed copies the fx2lafw blobs into its own share dir.
    env.SIGROK_FIRMWARE_DIR = "${labPkgs.libsigrok-sipeed}/share/sigrok-firmware";

    shellHook = ''
      echo "  scan:  sigrok-cli --driver sipeed-slogic-analyzer --scan"
      echo "  gui:   pulseview"
      echo "  look:  srdecode CAPTURE.sr --diff BASELINE.sr"
      echo "  calc:  python3 (numpy)"
      echo "  agent: lab mcp slogic --write   (then ask it to capture and decode)"
    '';
  };
}
