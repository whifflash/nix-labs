# Environments

Every environment is a `devShell`: `nix develop labs#<env>` (with the registry entry) or
`nix develop github:whifflash/nix-labs#<env>`, `lab <env>` with the home-manager module.
Linux-only tools are simply absent on macOS; everything else is identical on both.

## Zephyr — `zephyr-arm`, `zephyr-riscv`, `zephyr-esp32`, `zephyr-full`

Built on [zephyr-nix](https://github.com/nix-community/zephyr-nix).

| shell | SDK toolchains | extra tools |
|---|---|---|
| `zephyr-arm` | `arm-zephyr-eabi` | openocd (Zephyr fork), probe-rs, pyocd, picotool, stlink (Linux) |
| `zephyr-riscv` | `riscv64-zephyr-elf` | the above + esptool (ESP32-C3/C6) |
| `zephyr-esp32` | `xtensa-espressif_esp32{,s2,s3}_zephyr-elf` + `riscv64-zephyr-elf` | esptool, openocd |
| `zephyr-full` | all (≈2 GB) | everything |

Common: west + Zephyr's Python requirements (`pythonEnv`, pinned to the Zephyr revision the
template manifest uses), nixpkgs host tools (`dtc`, `qemu`, `bossac`, …), cmake, ninja, gperf,
ccache, dfu-util, tio. The shell exports `ZEPHYR_TOOLCHAIN_VARIANT=zephyr`,
`ZEPHYR_SDK_INSTALL_DIR`, and `ZEPHYR_BASE` when started inside a west workspace.

Workflow (see `templates/zephyr/README.md`):

```sh
lab init zephyr-arm ~/src/blinky && cd ~/src/blinky && direnv allow
west init -l app && west update
west build -b nrf52840dk/nrf52840 app && west flash
```

Zephyr sources are **not** in the shell — a west workspace per project is how Zephyr is meant
to be used (board/HAL revisions travel with the project). Slimness comes from the SDK
selection and from `name-allowlist` in `app/west.yml`.

Other chip family? `zephyr.sdk.override { targets = [ "x86_64-zephyr-elf" ]; }` in
`labs/zephyr/default.nix` — target names are the `toolchain_*_<target>.tar.xz` files of the
[Zephyr SDK release](https://github.com/zephyrproject-rtos/sdk-ng/releases)
(`aarch64-zephyr-elf`, `arc-zephyr-elf`, `mips-zephyr-elf`, `sparc-zephyr-elf`, …).

## SDR — `sdr`, `sdr-full`

| | |
|---|---|
| `sdr` | LimeSuite (`LimeUtil`, `LimeSuiteGUI`, `LimeQuickTest`), SoapySDR + modules (LimeSDR, rtl-sdr, HackRF, audio, remote — exported via `SOAPY_SDR_PLUGIN_PATH` for every program), SDR++, gqrx, urh, rtl-sdr, hackrf, multimon-ng, kalibrate-rtl, sox; Linux: inspectrum, usbutils |
| `sdr-full` | + GNU Radio 3.10 with gr-osmosdr (`gnuradio-companion`), SDRangel; Linux: SatDump |

```sh
LimeUtil --find; SoapySDRUtil --find
sdrpp            # Source: LimeSDR (native) or SoapySDR
gqrx             # device string: soapy=0,driver=lime
```

LimeSDR-USB needs USB 3 for high sample rates; inside `lab vm sdr` (USB over TCP) stay at a
few MS/s — the VM is for GUI/analysis convenience, not for wideband capture.

## Logic analyzer — `logic`

PulseView and sigrok-cli from nixpkgs, rebuilt against nixpkgs' `libsigrok-sipeed` (Sipeed's
`slogic-dev` libsigrok with the `sipeed-slogic-analyzer` driver: SLogic Combo8, 16U3, 32U3).
`SIGROK_FIRMWARE_DIR` points at the bundled fx2lafw firmware for the cheap FX2 analyzers.

```sh
sigrok-cli --driver sipeed-slogic-analyzer --scan
sigrok-cli --driver sipeed-slogic-analyzer --config samplerate=20m --samples 1M -o capture.sr
pulseview
```

The driver is plain libusb — no kernel module — so it works natively on Linux (with the
udev rules) and should on macOS; `lab vm logic` is the fallback if it does not.

## PlatformIO — `platformio` (Linux only)

For boards and frameworks outside Zephyr (Arduino, ESP-IDF, STM32Cube, …). PlatformIO
downloads its own prebuilt toolchains into `~/.platformio` at runtime, which needs an FHS
filesystem layout — hence `buildFHSEnv` rather than a plain shell, and hence Linux only. On
macOS run `nix shell nixpkgs#platformio` directly; PlatformIO's own toolchains work there.

```sh
lab platformio
pio project init --board esp32dev
pio run -t upload && pio device monitor
```

## Templates — `lab init <env> [dir]`

`nix flake init -t labs#{zephyr,sdr,logic}`: a `flake.nix` that re-exports the chosen shell
(pinned via `flake.lock`), `.envrc` (`use flake`), `.gitignore`, README; the Zephyr template adds
the `app/` manifest repo (west.yml with a small allowlist, CMakeLists, prj.conf, hello world).
`lab init` rewrites the shell name for the variant you asked for.
