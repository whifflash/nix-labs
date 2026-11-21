# Starts every MCP server this flake builds and speaks to it over stdio, the
# way a client does (checks/mcp-smoke.py). Every server must keep stdout clean
# and list its tools; servers marked `strict` in pkgs/mcp/default.nix are held
# to the rest of docs/MCP-RULES.md. No tool does real work: no hardware, no
# network, no files outside a scratch directory.
{
  pkgs,
  lib,
  servers,
}:
let
  manifest = pkgs.writeText "mcp-smoke-servers.json" (
    builtins.toJSON (
      lib.mapAttrsToList (name: s: {
        inherit name;
        command = lib.getExe s.package;
        args = s.args or [ ];
        env = s.env or { };
        strict = s.strict or false;
      }) servers
    )
  );
in
pkgs.runCommand "mcp-smoke-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  # The build sandbox points SSL_CERT_FILE at a file that does not exist, and
  # httpx loads it when a client is created: kicad-mcp then dies at start-up
  # with a bare ENOENT. Every real environment has a CA bundle, so give it
  # one; there is still no network in here.
  export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
  python3 ${./mcp-smoke.py} ${manifest}
  touch $out
''
