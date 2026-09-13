# Software-defined radio around the LimeSDR-USB (LimeSuite), with SoapySDR as
# the common device layer for SDR++ / gqrx / GNU Radio.
#
# SoapySDR finds vendor modules through SOAPY_SDR_PLUGIN_PATH; nixpkgs' plain
# `soapysdr` only knows its own directory, so the shell exports the modules it
# ships (LimeSuite's SoapyLMS7, rtl-sdr, HackRF, audio, remote) for every
# program in the shell, not just SoapySDRUtil.
{
  pkgs,
  lib,
  labPkgs,
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux;

  soapyModules = with pkgs; [
    limesuite # SoapyLMS7
    soapyrtlsdr
    soapyhackrf
    soapyaudio
    soapyremote
  ];

  base = {
    packages =
      with pkgs;
      [
        limesuite # LimeUtil, LimeSuiteGUI, LimeQuickTest
        soapysdr # SoapySDRUtil
        sdrpp
        gqrx
        urh
        rtl-sdr
        hackrf
        multimon-ng
        kalibrate-rtl
        sox
      ]
      ++ soapyModules
      ++ [ labPkgs.mcp-soapysdr ] # agent access: probe, capture, PSD/waterfall, scan, demod
      ++ lib.optionals isLinux [
        inspectrum
        usbutils
      ];

    env.SOAPY_SDR_PLUGIN_PATH = lib.makeSearchPath pkgs.soapysdr.passthru.searchPath soapyModules;

    shellHook = ''
      echo "  find:  LimeUtil --find    SoapySDRUtil --find"
      echo "  gui:   sdrpp | gqrx | LimeSuiteGUI | urh"
      echo "  agent: lab mcp sdr --write   (then ask it for a PSD or a band scan)"
    '';
  };
in
{
  sdr = base;

  sdr-full = base // {
    packages =
      base.packages
      ++ [
        # GNU Radio Companion with the OsmoSDR source (LimeSDR via Soapy).
        (pkgs.gnuradio.override { extraPackages = [ pkgs.gnuradioPackages.osmosdr ]; })
        pkgs.sdrangel
      ]
      ++ lib.optionals isLinux [ pkgs.satdump ];

    shellHook = base.shellHook + ''
      echo "  more:  gnuradio-companion | sdrangel${lib.optionalString isLinux " | satdump-ui"}"
    '';
  };
}
