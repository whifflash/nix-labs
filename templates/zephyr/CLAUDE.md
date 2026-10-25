# Agent notes — the `zephyr` environments

Zephyr RTOS development, one variant per chip family (`zephyr-arm`,
`zephyr-riscv`, `zephyr-esp32`, `zephyr-full`). No MCP servers here — the work
is west/build/flash.

- This directory is a west **T2 workspace** root; `app/` is the manifest
  repository (the application + `west.yml`). Zephyr itself is **not** in the
  shell — `west update` clones it and the HAL modules next to `app/`, so
  board/HAL revisions travel with the project, exactly as upstream intends.
- The flow: `west init -l app && west update`, then
  `west build -b <board> app && west flash` (openocd/probe-rs/pyocd/esptool per
  board), `tio /dev/ttyACM0` for the console. First time in a workspace, the
  shell auto-sets `ZEPHYR_BASE` when it sees `.west/` + `zephyr/`.
- Do not pip-install. The Python environment (west, pyelftools, imgtool, …) is
  pinned to the Zephyr revision the templates use — the Zephyr revision in
  `app/west.yml` must match it; a mismatch shows up as a missing Python module
  at `west build`. Re-pin the shell (`nix flake update nix-labs`), not pip.
- `ZEPHYR_TOOLCHAIN_VARIANT=zephyr` and `ZEPHYR_SDK_INSTALL_DIR` are preset; the
  variant's SDK is slim (only its toolchains). Another target:
  `sdk.override { targets = [ … ]; }` in `labs/zephyr/default.nix`, names from
  the Zephyr SDK release's `toolchain_*_<target>.tar.xz` files.
- Keep clones small: trim `name-allowlist` in `app/west.yml` to the HALs in use.
  ESP32 (Xtensa/RISC-V): `west blobs fetch hal_espressif` once before the first
  build.
