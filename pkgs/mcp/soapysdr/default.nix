# mcp-soapysdr — our own MCP server for software-defined radios.
#
# Why ours: every SDR MCP server on the market is RTL-SDR-specific (and two of
# them ship no licence at all). Going through SoapySDR instead means one server
# drives the LimeSDR-USB, RTL-SDR dongles, HackRF and anything else with a Soapy
# driver, on Linux and macOS alike.
{
  lib,
  python3Packages,
  limesuite,
  soapyrtlsdr,
  soapyhackrf,
  makeWrapper,
}:
let
  # python3Packages.soapysdr is the SWIG-wrapped build (module `SoapySDR`);
  # the top-level `soapysdr` is the C++ library only. Referred to explicitly —
  # a `with python3Packages;` would NOT shadow a `soapysdr` function argument.
  soapy = python3Packages.soapysdr;

  # Vendor modules the server should be able to see. SoapySDR only looks in its
  # own store path, so the search path is baked into the wrapper.
  soapyModules = [
    limesuite
    soapyrtlsdr
    soapyhackrf
  ];
in
python3Packages.buildPythonApplication {
  pname = "mcp-soapysdr";
  version = "0.1.0";
  pyproject = true;

  src = ./src;

  build-system = [ python3Packages.hatchling ];

  dependencies = [
    soapy
    python3Packages.mcp
    python3Packages.numpy
    python3Packages.scipy
    python3Packages.matplotlib
  ];

  nativeBuildInputs = [ makeWrapper ];

  pythonImportsCheck = [
    "mcp_soapysdr"
    "SoapySDR"
  ];

  postFixup = ''
    wrapProgram $out/bin/mcp-soapysdr \
      --prefix SOAPY_SDR_PLUGIN_PATH : ${lib.makeSearchPath soapy.passthru.searchPath soapyModules}
  '';

  meta = {
    description = "MCP server for SoapySDR radios: probe, capture IQ, PSD/spectrogram images, band scans, FM demodulation";
    license = lib.licenses.mit;
    mainProgram = "mcp-soapysdr";
    platforms = lib.platforms.unix;
  };
}
