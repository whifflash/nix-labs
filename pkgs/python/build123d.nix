# build123d — parametric CAD as Python on the OpenCASCADE B-rep kernel.
#
# Solids rather than meshes, so exports are real STEP as well as STL, and
# fillets/chamfers are kernel operations rather than approximations.
{
  lib,
  buildPythonPackage,
  fetchurl,
  cadquery-ocp,
  cadquery-ocp-proxy,
  ocpsvg,
  ocp-gordon,
  trianglesolver,
  anytree,
  ezdxf,
  ipython,
  numpy,
  scipy,
  scikit-learn,
  requests,
  lib3mf,
  svgpathtools,
  sympy,
  typing-extensions,
  webcolors,
}:
buildPythonPackage {
  pname = "build123d";
  version = "0.11.1";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/e7/f2/c466dbd4cb3aa75a192ba39f1a49058f828fcc0eb6f9cf6936ed6078308b/build123d-0.11.1-py3-none-any.whl";
    name = "build123d-0.11.1-py3-none-any.whl";
    hash = "sha256-TpX6fMvcg+YkMTvkkufE9fDrLqHfNhMOtxi7DCWonhA=";
  };

  dependencies = [
    cadquery-ocp
    cadquery-ocp-proxy
    ocpsvg
    ocp-gordon
    trianglesolver
    anytree
    ezdxf
    ipython
    numpy
    scipy
    scikit-learn
    requests
    lib3mf
    svgpathtools
    sympy
    typing-extensions
    webcolors
  ];

  # Upstream pins webcolors ~=24.8; nixpkgs carries a newer one and the two
  # functions build123d uses (name_to_hex / hex_to_rgb) are unchanged.
  pythonRelaxDeps = [ "webcolors" ];

  pythonImportsCheck = [ "build123d" ];

  meta = {
    description = "Python CAD as code on the OpenCASCADE kernel, exporting STEP, STL, 3MF and more";
    homepage = "https://build123d.readthedocs.io/";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
}
