# Packages this flake adds on top of nixpkgs (also exposed as overlays.default).
# The `lab` CLI and the pre-rendered MCP configs are built in flake.nix and in
# the home-manager module, because they need the environment catalogue too.
{ pkgs }:
let
  # build123d + its OCP bindings, plus our mcp_cad library, in one interpreter.
  cadPython = import ./python { inherit pkgs; };
in
rec {
  inherit (cadPython) python pythonEnv;

  # nixpkgs pins Sipeed's slogic-dev branch at 0ce0720 (2025-12-17); the branch
  # has moved on, and three of the newer commits matter for the SLogic16U3:
  #
  #   0c36240 sipeed-slogic-analyzer: fix premature transfer timeout
  #           — the timeout compared `transfers_reached_duration / SR_KHZ(1)`
  #             (a units error) and tripped once timeout_count exceeded the
  #             number of transfers used, so an acquisition could abort after a
  #             tenth of a second having delivered nothing at all.
  #   6027cbf fix model check (`!= support_models_ptr[1]` → `== [0]`, i.e. the
  #           Combo8 special case was being applied to the 16U3) and make the
  #           channel mask shift 64-bit.
  #   732589f add the SLogic32U3 model.
  #
  # Drop this override once nixpkgs' libsigrok-sipeed catches up.
  libsigrok-sipeed = pkgs.libsigrok-sipeed.overrideAttrs (_old: {
    version = "0.6.0-unstable-2026-07-24";
    src = pkgs.fetchFromGitHub {
      owner = "sipeed";
      repo = "libsigrok";
      rev = "0c36240d8dbb2b2e06f9a9ba9d889a9be752536c";
      hash = "sha256-6PSqGVlBWGRcaAaGoc74J2UaAq7ZqCGP3ELHOdibKUU=";
    };
  });

  # sigrok frontends linked against the libsigrok above (Sipeed's slogic-dev
  # branch with the `sipeed-slogic-analyzer` driver). Only the library differs;
  # PulseView/sigrok-cli sources are the nixpkgs ones.
  pulseview-sipeed = pkgs.pulseview.override { libsigrok = libsigrok-sipeed; };
  sigrok-cli-sipeed = pkgs.sigrok-cli.override { libsigrok = libsigrok-sipeed; };

  # Live preview for the cad lab: rebuild on save, f3d reloads the export.
  cad-watch = pkgs.callPackage ./cad-watch.nix { inherit (cadPython) python; };

  # MCP servers (see pkgs/mcp/ and docs/MCP.md). Named mcp-* so that
  # `nix run labs#mcp-<name>` — what the generated configs use — resolves.
  mcp-sigrok = pkgs.callPackage ./mcp/sigrok.nix { inherit sigrok-cli-sipeed; };
  mcp-kicad = pkgs.callPackage ./mcp/kicad.nix { };
  mcp-soapysdr = pkgs.callPackage ./mcp/soapysdr { };
  mcp-cad = cadPython.python.pkgs.toPythonApplication cadPython.python.pkgs.mcp-cad;
}
