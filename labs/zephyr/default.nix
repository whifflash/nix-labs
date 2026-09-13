# Zephyr RTOS development, per chip family.
#
# zephyr-nix provides the Zephyr SDK as one derivation per toolchain (`sdk.override
# { targets = [ … ]; }` — a slim shell downloads only the toolchains it names,
# `sdkFull` all of them), the west + Zephyr Python requirements (`pythonEnv`,
# pinned to the Zephyr revision the templates use), nixpkgs-based host tools
# and the Zephyr openocd fork. Zephyr itself is a per-project west workspace
# (`lab init zephyr-<variant>` → templates/zephyr).
{
  pkgs,
  lib,
  zephyr,
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux;

  common = [
    zephyr.pythonEnv # west, pyelftools, imgtool, …
    zephyr.hosttools-nix # dtc, qemu, bossac, openocd-zephyr, … from nixpkgs
    pkgs.cmake
    pkgs.ninja
    pkgs.gperf
    pkgs.ccache
    pkgs.dfu-util
    pkgs.tio # serial console: tio /dev/ttyACM0
    pkgs.git
  ];

  # Flashing/debugging for ARM and RISC-V targets.
  debug = [
    zephyr.openocd-zephyr
    pkgs.probe-rs-tools
    pkgs.pyocd
    pkgs.picotool
  ]
  ++ lib.optionals isLinux [ pkgs.stlink ];

  mkZephyr =
    {
      targets ? null, # null → the full SDK
      extra ? [ ],
    }:
    let
      sdk = if targets == null then zephyr.sdkFull else zephyr.sdk.override { inherit targets; };
    in
    {
      packages = common ++ extra ++ [ sdk ];

      env = {
        ZEPHYR_TOOLCHAIN_VARIANT = "zephyr";
        ZEPHYR_SDK_INSTALL_DIR = "${sdk}";
      };

      shellHook = ''
        # Inside a west workspace (T2: ./.west + ./zephyr), point CMake at it.
        if [ -z "''${ZEPHYR_BASE:-}" ] && [ -d .west ] && [ -f zephyr/Kconfig.zephyr ]; then
          export ZEPHYR_BASE="$PWD/zephyr"
        fi
        echo "  sdk:   ${sdk.version} — ${
          if targets == null then "all toolchains" else lib.concatStringsSep " " targets
        }"
        echo "  new:   lab init zephyr-<variant> mydir   then   west init -l app && west update"
        echo "  build: west build -b <board> app && west flash"
      '';
    };
in
{
  zephyr-arm = mkZephyr {
    targets = [ "arm-zephyr-eabi" ];
    extra = debug;
  };

  zephyr-riscv = mkZephyr {
    targets = [ "riscv64-zephyr-elf" ];
    extra = debug ++ [ pkgs.esptool ];
  };

  zephyr-esp32 = mkZephyr {
    targets = [
      "xtensa-espressif_esp32_zephyr-elf"
      "xtensa-espressif_esp32s2_zephyr-elf"
      "xtensa-espressif_esp32s3_zephyr-elf"
      "riscv64-zephyr-elf" # ESP32-C3/C6 (and the S3/C6 LP cores)
    ];
    extra = [
      pkgs.esptool
      zephyr.openocd-zephyr
    ];
  };

  zephyr-full = mkZephyr {
    extra = debug ++ [ pkgs.esptool ];
  };
}
