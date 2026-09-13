# sigrok MCP server (KenosInc/sigrok-mcp-server) — lets an agent drive a logic
# analyzer: scan_devices, capture_data, decode_protocol, render_waveform, …
#
# Upstream shells out to whatever `sigrok-cli` it finds (or $SIGROK_CLI_PATH).
# We pin it to OUR sigrok-cli — the one built against libsigrok-sipeed — which
# is what makes the Sipeed SLogic analyzers work; upstream's Docker image cannot
# see them at all.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  sigrok-cli-sipeed,
}:
buildGoModule {
  pname = "mcp-sigrok";
  version = "0-unstable-2026-05-20";

  src = fetchFromGitHub {
    owner = "KenosInc";
    repo = "sigrok-mcp-server";
    rev = "71a652dcae5ad663d00ee774857cf40dcbfd1df6";
    hash = "sha256-3eYkgoGuFBgOumOdfa01pC6iJwjZttVoYQ1dInSuuXw=";
  };

  vendorHash = "sha256-YnQj5kcfzfJjWoBdUBYBUelVNBSbGpuWV2QYR4h1PYY=";

  subPackages = [ "cmd/sigrok-mcp-server" ];

  ldflags = [
    "-s"
    "-w"
  ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/sigrok-mcp-server \
      --set-default SIGROK_CLI_PATH ${lib.getExe sigrok-cli-sipeed}
  '';

  meta = {
    description = "MCP server for sigrok, pinned to the Sipeed-enabled sigrok-cli";
    homepage = "https://github.com/KenosInc/sigrok-mcp-server";
    license = lib.licenses.mit;
    mainProgram = "sigrok-mcp-server";
    platforms = lib.platforms.unix;
  };
}
