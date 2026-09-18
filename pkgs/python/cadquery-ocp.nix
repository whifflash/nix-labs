# OpenCASCADE's Python bindings (pybind11), as published by the CadQuery project.
#
# From the prebuilt wheel rather than source: OCP is a generated binding over the
# whole of OCCT and takes hours to compile, while the wheels are ~67 MB and exist
# for cp310-cp314 on manylinux x86_64/aarch64 and macOS arm64/x86_64 — including
# cp313, which is nixpkgs' default python3.
#
# The `novtk` variant is what build123d depends on; it drops the VTK bridge,
# which we do not use and which would pull VTK into every CAD closure.
{
  lib,
  stdenv,
  buildPythonPackage,
  fetchurl,
  python,
  autoPatchelfHook,
  cadquery-ocp-proxy,
  # shared libraries the bundled OCCT needs on Linux
  libglvnd,
  libx11,
  libxext,
  libxmu,
  libxi,
  libsm,
  libice,
  fontconfig,
  freetype,
  zlib,
}:
let
  version = "7.9.3.1.1";
  pyTag = "cp${builtins.replaceStrings [ "." ] [ "" ] python.pythonVersion}";

  # <python tag>-<nix system> → the PyPI wheel. PyPI paths carry a content hash,
  # so each entry needs its own URL rather than a template.
  wheels = {
    "cp313-x86_64-linux" = {
      file = "cadquery_ocp_novtk-${version}-cp313-cp313-manylinux_2_31_x86_64.whl";
      url = "https://files.pythonhosted.org/packages/f3/31/82baf17406c0a13f2eb98c1d46d09a640795fc7d6b373a69bc5f44344db3/cadquery_ocp_novtk-7.9.3.1.1-cp313-cp313-manylinux_2_31_x86_64.whl";
      hash = "sha256-/80E1O+gh9OqlCNgAgJloawOEkB717z+s35wtNHuct8=";
    };
    "cp313-aarch64-linux" = {
      file = "cadquery_ocp_novtk-${version}-cp313-cp313-manylinux_2_31_aarch64.whl";
      url = "https://files.pythonhosted.org/packages/6a/bc/3eb58a3b7513309d665e0a65c00da93fc825dc930744cd8ab23626cd2e1f/cadquery_ocp_novtk-7.9.3.1.1-cp313-cp313-manylinux_2_31_aarch64.whl";
      hash = "sha256-2PaLBcKRf7D16lae2IxpfUfMV6eyk5KdhjtSyZrOkxI=";
    };
    "cp313-aarch64-darwin" = {
      file = "cadquery_ocp_novtk-${version}-cp313-cp313-macosx_11_0_arm64.whl";
      url = "https://files.pythonhosted.org/packages/f7/80/dc46dac2ebb6ae6bcce27bc7f717438b99897199be25323cda559a76e0a1/cadquery_ocp_novtk-7.9.3.1.1-cp313-cp313-macosx_11_0_arm64.whl";
      hash = "sha256-IoeBLyE69wIPi7xpsH1gOeUp9eDhVMAZIiGv8/2sZnY=";
    };
    "cp313-x86_64-darwin" = {
      file = "cadquery_ocp_novtk-${version}-cp313-cp313-macosx_11_0_x86_64.whl";
      url = "https://files.pythonhosted.org/packages/97/55/93f76eb2a1874b2d51c98e6cad1b55ae7562fc9b6eb36365e3b0597d25c4/cadquery_ocp_novtk-7.9.3.1.1-cp313-cp313-macosx_11_0_x86_64.whl";
      hash = "sha256-4padISm/IQZ/RJUxF8wY8UJvWqyu2LzAdCKOtQ8xebI=";
    };
  };

  key = "${pyTag}-${stdenv.hostPlatform.system}";
  wheel =
    wheels.${key} or (throw ''
      cadquery-ocp: no wheel recorded for ${key}.
      Upstream publishes cp310-cp314 for manylinux x86_64/aarch64 and macOS arm64/x86_64 —
      add the URL and hash to pkgs/python/cadquery-ocp.nix.
    '');
in
buildPythonPackage {
  pname = "cadquery-ocp";
  inherit version;
  format = "wheel";

  src = fetchurl {
    inherit (wheel) url hash;
    name = wheel.file;
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    libglvnd
    fontconfig
    freetype
    zlib
    libx11
    libxext
    libxmu
    libxi
    libsm
    libice
  ];

  dependencies = [ cadquery-ocp-proxy ];

  # The wheel bundles OCCT's shared objects beside the extension modules, so they
  # have to be on the search path before autoPatchelf resolves the bindings.
  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    addAutoPatchelfSearchPath "$out/${python.sitePackages}/OCP"
  '';

  pythonImportsCheck = [ "OCP" ];

  meta = {
    description = "Python bindings for OpenCASCADE (OCCT) from the CadQuery project, without the VTK bridge";
    homepage = "https://github.com/CadQuery/OCP";
    license = lib.licenses.lgpl21Only; # OCCT
    platforms = lib.platforms.unix;
  };
}
