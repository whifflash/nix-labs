# Environment catalogue — pure data, shared by the shells (labs/<env>), the
# `lab` CLI (`lab list`), the VM runners (default USB devices, kiosk program)
# and the docs. Package lists live next to each environment in labs/<env>/.
#
#   description  one line, shown by `lab list`
#   template     templates/<name> used by `lab init <env>`
#   usb          lib/hardware.nix keys the environment talks to
#   vm           null, or { program = "<binary>"; } → a `lab-vm-<env>` runner exists
#   mcp          MCP server names the environment provides (details in labs/<env>);
#                listed here so `lab list` / `lab mcp` know without evaluating a shell
{
  zephyr-arm = {
    description = "Zephyr RTOS — ARM Cortex-M (nRF, STM32, RP2040, NXP): arm-zephyr-eabi SDK, west, openocd, probe-rs, pyocd";
    template = "zephyr";
    usb = [
      "debug-probes"
      "bootloaders"
      "usb-serial"
    ];
    vm = null;
  };

  zephyr-riscv = {
    description = "Zephyr RTOS — RISC-V (ESP32-C3/C6, RP2350 RISC-V, generic): riscv64-zephyr-elf SDK, west, openocd, probe-rs, esptool";
    template = "zephyr";
    usb = [
      "debug-probes"
      "bootloaders"
      "usb-serial"
    ];
    vm = null;
  };

  zephyr-esp32 = {
    description = "Zephyr RTOS — Espressif ESP32 / S2 / S3 (Xtensa) + C-series (RISC-V): xtensa + riscv SDKs, west, esptool";
    template = "zephyr";
    usb = [
      "bootloaders"
      "usb-serial"
    ];
    vm = null;
  };

  zephyr-full = {
    description = "Zephyr RTOS — every SDK toolchain (~2 GB) plus all debug/flash tools";
    template = "zephyr";
    usb = [
      "debug-probes"
      "bootloaders"
      "usb-serial"
    ];
    vm = null;
  };

  sdr = {
    description = "Software-defined radio — LimeSuite, SoapySDR (+plugins), SDR++, gqrx, urh, inspectrum, rtl-sdr, multimon-ng";
    template = "sdr";
    usb = [
      "limesdr"
      "rtl-sdr"
      "hackrf"
    ];
    vm = {
      program = "sdrpp";
    };
    mcp = [ "soapysdr" ];
  };

  sdr-full = {
    description = "sdr + GNU Radio 3.10 (gr-osmosdr), SDRangel, SatDump";
    template = "sdr";
    usb = [
      "limesdr"
      "rtl-sdr"
      "hackrf"
    ];
    vm = null;
  };

  slogic = {
    description = "Logic analyzer — PulseView + sigrok-cli built against libsigrok-sipeed (Sipeed SLogic driver), fx2lafw firmware";
    template = "slogic";
    usb = [ "sipeed-slogic" ];
    vm = {
      program = "pulseview";
    };
    mcp = [ "sigrok" ];
  };

  eda = {
    description = "Circuit design + simulation — KiCad, ngspice/Xyce/Qucs-s/xschem, gerbv, KLayout, FreeRouting, KiKit, SKiDL";
    template = "eda";
    usb = [ "usb-serial" ]; # bench instruments on USB-TTL
    vm = {
      # KiCad is Linux-only in nixpkgs, so on macOS this VM *is* the way to run it.
      program = "kicad";
    };
    mcp = [ "kicad" ];
  };

  ai = {
    description = "AI coding agents — opencode, pi, claude-code, codex, gemini-cli, qwen-code, crush, goose, aider + context and MCP tooling";
    template = "ai";
    usb = [ ];
    vm = null;
    mcp = [
      "nixos"
      "github"
      "fetch"
      "playwright"
    ];
  };

  platformio = {
    description = "PlatformIO in an FHS environment (Arduino, ESP-IDF, STM32, … — for projects that are not Zephyr); Linux only";
    template = null;
    usb = [
      "bootloaders"
      "usb-serial"
      "debug-probes"
    ];
    vm = null;
    linuxOnly = true;
  };
}
