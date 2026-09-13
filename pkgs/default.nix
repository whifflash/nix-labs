# Packages this flake adds on top of nixpkgs (also exposed as overlays.default).
# The `lab` CLI and the pre-rendered MCP configs are built in flake.nix and in
# the home-manager module, because they need the environment catalogue too.
{ pkgs }:
rec {
  # sigrok frontends linked against nixpkgs' libsigrok-sipeed (Sipeed's
  # slogic-dev branch with the `sipeed-slogic-analyzer` driver). Only the
  # library differs; PulseView/sigrok-cli sources are the nixpkgs ones.
  pulseview-sipeed = pkgs.pulseview.override { libsigrok = pkgs.libsigrok-sipeed; };
  sigrok-cli-sipeed = pkgs.sigrok-cli.override { libsigrok = pkgs.libsigrok-sipeed; };

  # MCP servers (see pkgs/mcp/ and docs/MCP.md). Named mcp-* so that
  # `nix run labs#mcp-<name>` — what the generated configs use — resolves.
  mcp-sigrok = pkgs.callPackage ./mcp/sigrok.nix { inherit sigrok-cli-sipeed; };
  mcp-kicad = pkgs.callPackage ./mcp/kicad.nix { };
  mcp-soapysdr = pkgs.callPackage ./mcp/soapysdr { };
}
