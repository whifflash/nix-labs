# Hardware access

`lib/hardware.nix` is the single catalogue of USB devices. From it:

- `nixosModules.default` generates `70-nix-labs.rules` (`labs.enable`): every device gets
  `MODE="0660", GROUP="plugdev", TAG+="uaccess"` — the logged-in seat and members of
  `labs.udev.group` (`plugdev`) can open it. `labs.users` are added to `plugdev` and `dialout`
  (serial consoles). Debug probes and USB-serial bridges also get `ID_MM_DEVICE_IGNORE=1` so
  ModemManager leaves them alone.
- the `lab-vm-<env>` runners take their default `--usb VID:PID` list from the `vm` field.
- this table.

| key | devices | udev matches | VM default |
|---|---|---|---|
| `sipeed-slogic` | Sipeed SLogic Combo8 (`…:0300`), **SLogic16U3 (`…:3031`)**, SLogic32U3 (`…:3032`) | vendor `359f` (libsigrok-sipeed as packaged in nixpkgs, 2025-12) **and** `2b1c` (Sipeed branch head 2026) | `359f:3031`, `2b1c:3031` |
| `limesdr` | LimeSDR-USB `1d50:6108`, LimeSDR-Mini `0403:601f`, FX3 bootloader `04b4:8613`/`04b4:00f1`, `0403:6001` | from LimeSuite's `64-limesuite.rules` | `1d50:6108` |
| `rtl-sdr` | RTL2832U dongles `0bda:2838`, `0bda:2832` | | `0bda:2838` |
| `hackrf` | HackRF One `1d50:6089`, Jawbreaker `1d50:604b`, DFU `1d50:cc15` | | `1d50:6089` |
| `debug-probes` | ST-Link V1/V2/V2-1/V3 (`0483:3744/3748/374b/374d/374e/374f/3752/3753/3754`), J-Link (vendor `1366`), Pi Debug Probe `2e8a:000c`, Black Magic Probe `1d50:6018/6017`, DAPLink `0d28:0204` | + ModemManager ignore | — |
| `bootloaders` | STM32 DFU `0483:df11`, RP2040 BOOTSEL `2e8a:0003`, RP2350 BOOTSEL `2e8a:000f`, Nordic (vendor `1915`), Espressif USB-JTAG/serial `303a:1001`, DFU `303a:1002` | | — |
| `usb-serial` | FTDI `0403:6001/6010/6011/6014/6015`, CP210x `10c4:ea60/ea70`, CH340 `1a86:7523`, CH9102 `1a86:55d4` | + ModemManager ignore | — |

Check what your device enumerates as with `lsusb` (Linux) or
`system_profiler SPUSBDataType` (macOS). The SLogic16U3 is expected as `359f:3031`; if yours
shows `2b1c:3031` the rules already cover it — tell the VM runner with `--usb 2b1c:3031`
(the default list tries both).

Without NixOS: install the same rules by hand —
`nix eval --raw github:whifflash/nix-labs#lib.udevRules --apply 'f: f {}' > /etc/udev/rules.d/70-nix-labs.rules`
(then `udevadm control --reload && udevadm trigger`), and add yourself to `plugdev`/`dialout`.

macOS needs no rules: libusb opens devices directly unless a system driver has claimed them
(serial bridges appear as `/dev/cu.usb*`; the analyzer/SDRs are vendor-class devices).
