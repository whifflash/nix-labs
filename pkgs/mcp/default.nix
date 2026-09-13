# MCP servers the labs expose, as a catalogue:
#
#   <name> = { package; args ? [ ]; env ? { }; description; }
#
# Kept independent of labs/ (which needs the zephyr-nix input) so that a
# consumer's home-manager module can render MCP configs from `pkgs` alone.
# lib/mcp.nix turns these into the per-client config formats.
{
  pkgs,
  labPkgs,
}:
{
  sigrok = {
    package = labPkgs.mcp-sigrok;
    description = "Logic analyzers via sigrok: scan devices, capture samples, decode I²C/SPI/UART/CAN and 100+ other protocols, render waveforms (Sipeed SLogic supported)";
  };

  soapysdr = {
    package = labPkgs.mcp-soapysdr;
    description = "Software-defined radios via SoapySDR (LimeSDR, RTL-SDR, HackRF, …): probe, capture IQ, PSD and spectrogram images, band scans, FM demodulation";
  };

  kicad = {
    package = labPkgs.mcp-kicad;
    description = "KiCad projects: list/inspect projects, extract netlists and BOMs, run DRC via kicad-cli, visualise boards, recognise circuit patterns";
  };

  # Off-the-shelf servers from nixpkgs — declared here so `lab mcp ai` produces
  # a useful starting config without shipping any code of our own.
  nixos = {
    package = pkgs.mcp-nixos;
    description = "Search nixpkgs packages, NixOS options, home-manager and nix-darwin options";
  };

  github = {
    package = pkgs.github-mcp-server;
    args = [ "stdio" ];
    description = "GitHub issues, pull requests, code search and releases (needs GITHUB_PERSONAL_ACCESS_TOKEN)";
  };

  fetch = {
    package = pkgs.mcp-server-fetch;
    description = "Fetch a URL and convert it to markdown for the model to read";
  };

  playwright = {
    package = pkgs.playwright-mcp;
    description = "Drive a real browser: navigate, click, type, snapshot the accessibility tree";
  };
}
