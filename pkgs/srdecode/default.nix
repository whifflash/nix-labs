# srdecode — numpy-based .sr analyzer for protocol reverse engineering.
#
# The MCP server renders captures as ASCII art (and gives up entirely on the
# multi-million-sample captures a 5 MHz analyzer produces in seconds); this is
# the text-side counterpart: baud estimation, UART decode with stop-bit
# validation, frame segmentation and capture diffing. Pure python + numpy, so
# it substitutes from cache on every platform the labs support.
{
  lib,
  stdenv,
  makeWrapper,
  python3,
}:
let
  pythonEnv = python3.withPackages (ps: [ ps.numpy ]);
in
stdenv.mkDerivation {
  pname = "srdecode";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [ pythonEnv ];

  dontBuild = true;

  installPhase = ''
    install -Dm555 srdecode.py $out/libexec/srdecode.py
    makeWrapper ${pythonEnv}/bin/python $out/bin/srdecode \
      --add-flags "$out/libexec/srdecode.py"
  '';

  meta = {
    description = "Analyze sigrok .sr captures: baud detect, UART decode, frame diff";
    mainProgram = "srdecode";
    platforms = lib.platforms.unix;
  };
}
