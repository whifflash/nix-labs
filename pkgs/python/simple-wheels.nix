# The small pure-Python pieces of the build123d stack that nixpkgs does not carry.
#
# All of them publish `py3-none-any` wheels with no compiled code, so they are
# one `buildPythonPackage { format = "wheel"; }` each; collecting them in one
# file keeps six near-identical expressions from sprawling.
#
# Versions are pinned to what build123d 0.11.1 accepts — notably ocpsvg 0.6.x,
# because 0.7 moved to the OCP 8 series while build123d still wants OCP 7.9.
{
  lib,
  stdenv,
  buildPythonPackage,
  fetchurl,
  # deps that nixpkgs already has
  numpy,
  scipy,
  svgelements,
  # the real OpenCASCADE binding: upstream declares only the `cadquery_ocp_proxy`
  # shim and pulls OCP through its `novtk` extra, but ocpsvg/ocp_gordon do
  # `import OCP` at module scope, so it has to be a genuine dependency here.
  cadquery-ocp,
}:
let
  wheel =
    {
      pname,
      version,
      file,
      url,
      hash,
      deps ? [ ],
      imports ? [ ],
      description,
      homepage,
      license ? lib.licenses.asl20,
    }:
    buildPythonPackage {
      inherit pname version;
      format = "wheel";
      src = fetchurl {
        inherit url hash;
        name = file;
      };
      dependencies = deps;
      pythonImportsCheck = imports;
      meta = {
        inherit description homepage license;
        platforms = lib.platforms.unix;
      };
    };

  # Platform-tagged, but pure Python: type stubs shipped per-platform.
  stubWheels = {
    "x86_64-linux" = {
      file = "cadquery_ocp_stubs-7.9.3.1.1-py3-none-manylinux_2_31_x86_64.whl";
      url = "https://files.pythonhosted.org/packages/1c/39/d0a4533ef1d776feea0cc04613438ddec1279ed0719f310cdf192f2e42b9/cadquery_ocp_stubs-7.9.3.1.1-py3-none-manylinux_2_31_x86_64.whl";
      hash = "sha256-XzH1+LBO2xUWEvwKGjW8sEkfR/BuFgggFJw7436wFXU=";
    };
    "aarch64-linux" = {
      file = "cadquery_ocp_stubs-7.9.3.1.1-py3-none-manylinux_2_31_aarch64.whl";
      url = "https://files.pythonhosted.org/packages/f0/e6/6ba73f9302f53cb008c487fae82b1198974f3e6f608febba161f56d4993e/cadquery_ocp_stubs-7.9.3.1.1-py3-none-manylinux_2_31_aarch64.whl";
      hash = "sha256-Ho6VCR+7bIABzyWN0eIE5DdU458Yavulj8jSzhT4QZg=";
    };
    "aarch64-darwin" = {
      file = "cadquery_ocp_stubs-7.9.3.1.1-py3-none-macosx_11_0_arm64.whl";
      url = "https://files.pythonhosted.org/packages/ef/f0/0cb52aa92e8c8e3b45c70e3a56958e85068e6a2bc60909eed0ed1613aafe/cadquery_ocp_stubs-7.9.3.1.1-py3-none-macosx_11_0_arm64.whl";
      hash = "sha256-IoW3wz5v4afgnfWJU6DclVDIyxOZDatBkNoCXKQNLw8=";
    };
    "x86_64-darwin" = {
      file = "cadquery_ocp_stubs-7.9.3.1.1-py3-none-macosx_11_0_x86_64.whl";
      url = "https://files.pythonhosted.org/packages/83/f6/bba5582cd3eb416adc404f70140f47c10c4628eb2081957834e2c444127f/cadquery_ocp_stubs-7.9.3.1.1-py3-none-macosx_11_0_x86_64.whl";
      hash = "sha256-fpSsSdIdLQ+mS1Vb2+mG+NV9tfN/Mz/rhvsR0lI6px8=";
    };
  };

  # lib3mf, per platform (see the `lib3mf` attribute below).
  lib3mfWheels = {
    "x86_64-linux" = {
      file = "lib3mf-2.5.0-py3-none-manylinux2014_x86_64.whl";
      url = "https://files.pythonhosted.org/packages/88/83/8b987ba95ac0ed9cc7e9c407a579bf43eff6349b1792b4a66c992ce4f76b/lib3mf-2.5.0-py3-none-manylinux2014_x86_64.whl";
      hash = "sha256-tMAAM8R8/qyTt9qgaftG6N6kOR1VIrec1un2r3XjMBM=";
    };
    "aarch64-darwin" = {
      file = "lib3mf-2.5.0-py3-none-macosx_10_9_universal2.whl";
      url = "https://files.pythonhosted.org/packages/04/87/47504d69f0f36841670d12ce3fe1668025bad74d83ed361ead378f626fed/lib3mf-2.5.0-py3-none-macosx_10_9_universal2.whl";
      hash = "sha256-99xX6iIhT6ktrHKLpm5YxLJLd11GeIgmKoIDONfYQUU=";
    };
    "x86_64-darwin" = {
      file = "lib3mf-2.5.0-py3-none-macosx_10_9_universal2.whl";
      url = "https://files.pythonhosted.org/packages/04/87/47504d69f0f36841670d12ce3fe1668025bad74d83ed361ead378f626fed/lib3mf-2.5.0-py3-none-macosx_10_9_universal2.whl";
      hash = "sha256-99xX6iIhT6ktrHKLpm5YxLJLd11GeIgmKoIDONfYQUU=";
    };
    # aarch64-linux: upstream ships py-lib3mf there, cp313 wheel.
    "aarch64-linux" = {
      file = "py_lib3mf-2.5.0-cp313-cp313-manylinux_2_24_aarch64.manylinux_2_28_aarch64.whl";
      url = "https://files.pythonhosted.org/packages/75/1d/6b7db799a635ae283240daaf91d1c9e50af8de66625565f0b3bc9d6f3635/py_lib3mf-2.5.0-cp313-cp313-manylinux_2_24_aarch64.manylinux_2_28_aarch64.whl";
      hash = "sha256-vNyes2BsZqszb8rbpZaBYCiH0F33h8/XQyYiMH9KQ2I=";
    };
  };
in
rec {
  # 3MF import/export. Upstream splits this by platform: `lib3mf` everywhere
  # except aarch64-linux, which gets `py-lib3mf` instead (see build123d's
  # environment markers). Same module name, so build123d neither knows nor cares.
  lib3mf = wheel (
    {
      pname = "lib3mf";
      version = "2.5.0";
      imports = [ "lib3mf" ];
      description = "Python bindings for lib3mf, the 3MF Consortium reference implementation";
      homepage = "https://github.com/3MFConsortium/lib3mf";
      license = lib.licenses.bsd2;
    }
    // (lib3mfWheels.${stdenv.hostPlatform.system}
      or (throw "lib3mf: no wheel for ${stdenv.hostPlatform.system}")
    )
  );

  cadquery-ocp-proxy = wheel {
    pname = "cadquery-ocp-proxy";
    version = "7.9.3.1.1";
    file = "cadquery_ocp_proxy-7.9.3.1.1-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/30/c0/04e9363a99fee892de2776820e3dcf04f8825b6edc9580efe3416c9465a7/cadquery_ocp_proxy-7.9.3.1.1-py3-none-any.whl";
    hash = "sha256-ykFk7EtUlW2fw+aMZ9VVtUhsuWPC9x4Y3wBboWuSHJE=";
    imports = [ "cadquery_ocp_proxy" ];
    description = "Version-tracking shim that pins cadquery_ocp / cadquery_ocp_novtk";
    homepage = "https://pypi.org/project/cadquery-ocp-proxy/";
  };

  cadquery-ocp-stubs = wheel (
    {
      pname = "cadquery-ocp-stubs";
      version = "7.9.3.1.1";
      description = "Type stubs for the OCP OpenCASCADE bindings";
      homepage = "https://github.com/CadQuery/ocp-stubs";
      license = lib.licenses.lgpl21Only;
    }
    // (stubWheels.${stdenv.hostPlatform.system}
      or (throw "cadquery-ocp-stubs: no wheel for ${stdenv.hostPlatform.system}")
    )
  );

  trianglesolver = wheel {
    pname = "trianglesolver";
    version = "1.2";
    file = "trianglesolver-1.2-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/ff/8e/43d45cf3e18e3f455e4b5ab333a7c27b8e38c4e535f7346b7148ce08eb65/trianglesolver-1.2-py3-none-any.whl";
    hash = "sha256-qgkDw3CLTitJbwbUkMrnLG/2J0sA0e3OQg/Po7K3ZoI=";
    deps = [ numpy ];
    imports = [ "trianglesolver" ];
    description = "Solve a triangle from any three of its sides and angles";
    homepage = "https://github.com/dfrankow/trianglesolver";
    license = lib.licenses.mit;
  };

  ocpsvg = wheel {
    pname = "ocpsvg";
    version = "0.6.0";
    file = "ocpsvg-0.6.0-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/a9/d7/27d2c9d5a2645fdda9e502a2a1a1cb5d4c9d137223ef76a43296eb7c152b/ocpsvg-0.6.0-py3-none-any.whl";
    hash = "sha256-XPxt6y9gLe2EVZZAnkH+j14bOJ4U6MxyfbCVXw6I3ns=";
    deps = [
      cadquery-ocp
      cadquery-ocp-proxy
      svgelements
    ];
    imports = [ "ocpsvg" ];
    description = "SVG paths to and from OpenCASCADE geometry";
    homepage = "https://github.com/snoyer/ocpsvg";
    license = lib.licenses.mit;
  };

  ocp-gordon = wheel {
    pname = "ocp-gordon";
    version = "0.2.2";
    file = "ocp_gordon-0.2.2-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/6c/d1/ee535cdbc502790dda6555e439ea8bcacdd38325859151769d109d307a94/ocp_gordon-0.2.2-py3-none-any.whl";
    hash = "sha256-ZBTpAaEQZaVug5yBtW9BgQC00Lgetaojux+Pcvl/8Jk=";
    deps = [
      cadquery-ocp
      cadquery-ocp-proxy
      cadquery-ocp-stubs
      numpy
      scipy
    ];
    imports = [ "ocp_gordon" ];
    description = "Gordon surface construction for OpenCASCADE";
    homepage = "https://github.com/gumyr/ocp_gordon";
  };
}
