# PlatformIO (Arduino/ESP-IDF/STM32 boards, and everything else its registry
# covers) — the escape hatch for projects that are not Zephyr.
#
# PlatformIO downloads its own prebuilt toolchains at runtime and installs them
# under ~/.platformio, so it needs a filesystem layout those binaries expect:
# buildFHSEnv provides one. Linux only (no FHS sandbox on Darwin); on macOS use
# `nix shell nixpkgs#platformio` and let it manage its own toolchains, which it
# can do there because macOS has no NixOS-style dynamic-loader problem.
{ pkgs, lib }:
lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  platformio = {
    shell =
      (pkgs.buildFHSEnv {
        name = "platformio";
        targetPkgs =
          ps: with ps; [
            platformio
            (python3.withPackages (
              p: with p; [
                pip
                virtualenv
              ]
            ))
            git
            openocd
            avrdude
            dfu-util
          ];
        profile = ''
          if [ -z "''${LAB_QUIET:-}" ]; then
            printf '\033[1m[nix-labs] platformio\033[0m — pio run | pio run -t upload | pio device monitor\n'
          fi
        '';
      }).env;
  };
}
