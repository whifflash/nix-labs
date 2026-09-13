# Zephyr application

A west **T2 workspace**: this directory is the workspace root, `app/` is the manifest
repository (your application + `west.yml`), and `west update` clones Zephyr and the HAL
modules next to it. Toolchain, west and Zephyr's Python requirements come from the pinned
[nix-labs](https://github.com/whifflash/nix-labs) shell — nothing is installed globally.

```sh
direnv allow                          # or: nix develop  (sets ZEPHYR_SDK_INSTALL_DIR, ZEPHYR_BASE)
west init -l app                      # once: register app/west.yml as the manifest
west update                           # clone zephyr + the allow-listed modules
west build -b nrf52840dk/nrf52840 app # or: esp32c3_devkitm | esp32_devkitc/esp32/procpu | rpi_pico
west flash                            # openocd / pyocd / probe-rs / esptool, per board
tio /dev/ttyACM0                      # serial console
```

- Fewer clones: trim `name-allowlist` in `app/west.yml` to the HALs you use.
- ESP32 (Xtensa/RISC-V): `west blobs fetch hal_espressif` once before the first build.
- The Zephyr revision in `app/west.yml` should match the Python environment nix-labs pins
  (zephyr-nix); a mismatch shows up as a missing Python module at `west build`.
- Re-pin the shell: `nix flake update nix-labs`.
