# Packages this flake adds on top of nixpkgs (also exposed as overlays.default).
# The `lab` CLI and the pre-rendered MCP configs are built in flake.nix and in
# the home-manager module, because they need the environment catalogue too.
#
# `prev` is the pre-overlay nixpkgs. overlays.default replaces the
# libsigrok-sipeed attribute with the one from this set, so the override below
# must build on `prev.libsigrok-sipeed` — `pkgs.libsigrok-sipeed` would refer
# to itself through the overlay and recurse. When this file is imported
# against an already-overlaid pkgs (the devShells path), prev defaults to
# pkgs and the override lands twice — harmless, it is idempotent (same
# version and src on both passes, so the derivation hash doesn't move).
{
  pkgs,
  prev ? pkgs,
}:
let
  # f3d as the cad workflow's viewer. USD support off on darwin: the plugin
  # drags openusd → pyqt6 → qtwebengine, which doesn't build there —
  # chromium's gn drives the raw clang, so the cc-wrapper's libc++ include
  # paths never reach the command line (every C++ TU dies with "'atomic'
  # file not found"), and configure separately demands Apple's Metal
  # toolchain, which the sandboxed apple-sdk doesn't ship. The cad loop
  # previews STL/STEP/GLTF exports, which f3d handles without USD; Linux
  # hosts keep USD (it substitutes from cache there).
  #
  # On darwin f3d installs only an .app bundle — no bin/, so `lib.getExe`
  # (cad-watch, mcp-cad's MCP_CAD_F3D) and the shells' PATH point at nothing.
  # Link the bundle's binary into bin/; Linux keeps the stock derivation.
  cadViewer =
    let
      f3d = pkgs.f3d.override { withUsd = pkgs.stdenv.hostPlatform.isLinux; };
    in
    if pkgs.stdenv.hostPlatform.isDarwin then
      pkgs.symlinkJoin {
        name = "f3d";
        paths = [ f3d ];
        postBuild = ''
          mkdir -p $out/bin
          ln -s ${f3d}/f3d.app/Contents/MacOS/f3d $out/bin/f3d
        '';
        passthru = {
          inherit (f3d) meta;
        };
      }
    else
      f3d;

  # build123d + its OCP bindings, plus our mcp_cad library, in one interpreter.
  cadPython = import ./python { inherit pkgs; f3d = cadViewer; };
in
rec {
  inherit (cadPython) python pythonEnv;
  inherit cadViewer;

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
  libsigrok-sipeed = prev.libsigrok-sipeed.overrideAttrs (_old: {
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
  cad-watch = pkgs.callPackage ./cad-watch.nix {
    inherit (cadPython) python;
    f3d = cadViewer;
  };

  # MCP servers (see pkgs/mcp/ and docs/MCP.md). Named mcp-* so that
  # `nix run labs#mcp-<name>` — what the generated configs use — resolves.
  mcp-sigrok = pkgs.callPackage ./mcp/sigrok.nix { inherit sigrok-cli-sipeed; };
  mcp-kicad = pkgs.callPackage ./mcp/kicad.nix { };
  mcp-soapysdr = pkgs.callPackage ./mcp/soapysdr { };
  mcp-cad = cadPython.python.pkgs.toPythonApplication cadPython.python.pkgs.mcp-cad;
}
