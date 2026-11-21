# PhotoCraft — an open-source, clean-room reimplementation of Photoshop in pure
# Rust (egui on wgpu): layers, masks, adjustment layers, layer styles, type,
# vectors and real PSD/PSB round trips. One package, two programs: the desktop
# app `photocraft`, and `photocraft-cli` (convert, run, batch, droplets, and
# the stdio MCP server that pkgs/mcp/photocraft.nix wraps).
#
# From source rather than the release tarball/DMG: it is an ordinary cargo
# workspace that builds in minutes (not the hours that put cadquery-ocp on
# wheels), and one expression then covers every system this flake supports.
# Built the way upstream's release packaging builds it (packaging/linux/
# package.sh): both binaries, `--features heif` (pure-Rust heic-rs).
{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  versionCheckHook,
  # Loaded with dlopen at runtime on Linux (see postPatch/postFixup).
  libxkbcommon,
  wayland,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  vulkan-loader,
  libglvnd,
  dbus,
}:
let
  # winit opens the window through these, wgpu the GPU (Vulkan, or EGL), and
  # rfd reaches the XDG file-chooser portal through libdbus. None of them is a
  # NEEDED entry — upstream lists them as package dependencies instead
  # (packaging/linux/nfpm.yaml) — so the binary gets an rpath to them.
  runtimeLibs = [
    libxkbcommon # libxkbcommon.so.0, libxkbcommon-x11.so.0
    wayland
    libx11 # libX11.so.6, libX11-xcb.so.1
    libxcb
    libxcursor
    libxi
    vulkan-loader
    libglvnd # libEGL.so.1
    dbus
  ];
  runtimeLibDirs = map (p: "${lib.getLib p}/lib") runtimeLibs;
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "photocraft";
  version = "0.8.2";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "photocraft";
    rev = "d43db3e153c76aefce9b32cef9099e458eaf17a8"; # tag v0.8.2
    hash = "sha256-kqKpZ8IBPmCd93XXvyxyAjPjJEWFfZh49qQc9KMSp4Y=";
  };

  cargoHash = "sha256-dafKVsoBYuChW0nsjUhk5GqCChAO07A4Rhhv2UAdEx0=";

  # The commit the release packaging stamps in (packaging/env.sh), so the
  # About box and `--version` read like an official build rather than
  # "(dev build)". No build date: it would change on every rebuild.
  env.PHOTOCRAFT_BUILD_SHA = finalAttrs.src.rev;

  # Before opening the window, the app checks for the libraries above itself
  # (apps/photocraft/src/linux_libs.rs) in `ldconfig -p` and a fixed list of
  # FHS directories, and exits naming a distro package when the cache is
  # readable and lacks one — on a non-NixOS host the host's cache decides,
  # whatever the rpath provides. The same probe gates opening the window
  # through Xwayland when a pen is attached (tablet.rs: no pen input on native
  # Wayland). Putting our library directories first in that list makes the
  # probe see what the rpath loads, without leaking LD_LIBRARY_PATH into
  # every process the app starts.
  postPatch = lib.optionalString stdenv.hostPlatform.isLinux ''
    substituteInPlace apps/photocraft/src/linux_libs.rs \
      --replace-fail 'for d in ["/app/lib", ' \
        'for d in [${lib.concatMapStrings (d: ''"${d}", '') runtimeLibDirs}"/app/lib", '
  '';

  cargoBuildFlags = [
    "-p"
    "photocraft"
    "-p"
    "photocraft-cli"
  ];
  buildFeatures = [ "heif" ];

  # ~1,700 tests in ~260 binaries, including GPU-vs-CPU compositor oracles and
  # PSD corpora that `cargo xtask corpus` downloads — upstream CI's job, not a
  # package build's. The install check below runs the built CLI instead.
  doCheck = false;

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/photocraft-cli";
  doInstallCheck = true;

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    install -Dm644 packaging/linux/ai.storyteller.photocraft.desktop -t $out/share/applications
    install -Dm644 packaging/linux/ai.storyteller.photocraft.mime.xml \
      $out/share/mime/packages/ai.storyteller.photocraft.xml
    mkdir -p $out/share/icons
    cp -R assets/app-icon/hicolor $out/share/icons/
  '';

  # The CLI is headless (no window, no GPU): only the desktop app needs the rpath.
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    patchelf --add-rpath ${lib.concatStringsSep ":" runtimeLibDirs} $out/bin/photocraft
  '';

  meta = {
    description = "Open-source, clean-room Photoshop reimplementation in pure Rust: layers, adjustment layers, layer styles, type, vectors, PSD round trips; plus a headless CLI and MCP server";
    homepage = "https://github.com/storytold/photocraft";
    changelog = "https://github.com/storytold/photocraft/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "photocraft";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
