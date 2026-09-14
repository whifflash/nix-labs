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

  # Same thing, unstripped and with -g, for when PulseView crashes and a
  # backtrace full of hex addresses is not enough. Not in the shell — build it
  # on demand:  nix build labs#pulseview-sipeed-debug
  # then reproduce and read the trace with `coredumpctl gdb pulseview`, or
  # attach to the running process (the bin/ entry is a Qt wrapper script, so
  # gdb cannot exec it directly). See docs/ENVIRONMENTS.md.
  # RelWithDebInfo, not Debug: same -O2 as the binary that actually crashes, so
  # the backtrace lines up with it, plus -g for line numbers. The flag is passed
  # explicitly because the `cmakeBuildType` attribute did not reach the cmake
  # hook here (it still configured with CMAKE_BUILD_TYPE=Release).
  pulseview-sipeed-debug = pulseview-sipeed.overrideAttrs (old: {
    pname = "${old.pname}-debug";
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DCMAKE_BUILD_TYPE=RelWithDebInfo" ];
    dontStrip = true;
  });

  # MCP servers (see pkgs/mcp/ and docs/MCP.md). Named mcp-* so that
  # `nix run labs#mcp-<name>` — what the generated configs use — resolves.
  mcp-sigrok = pkgs.callPackage ./mcp/sigrok.nix { inherit sigrok-cli-sipeed; };
  mcp-kicad = pkgs.callPackage ./mcp/kicad.nix { };
  mcp-soapysdr = pkgs.callPackage ./mcp/soapysdr { };
}
