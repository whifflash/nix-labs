# Agent notes — the `slogic` environment

Logic analyzer: PulseView and sigrok-cli built against libsigrok with the Sipeed
SLogic driver (`sipeed-slogic-analyzer`: Combo8, 16U3, 32U3). Plain libusb, no
kernel module — works natively on Linux (with the nix-labs udev rules) and
macOS; `lab vm slogic` is the fallback.

- **Always give a sample count.** The driver has no default: without
  `--samples N` (sigrok-cli) or a fixed sample count (PulseView — never
  continuous mode, it cannot honour it) the capture ends in ~0.02 s with **no
  data and no error** — zero transfers submitted, nothing logged. This is the
  one way this bench fails silently.
- Channels come from the `logic_channels` option (4, 8 or 16 on a 16U3 — legal
  values, and the rate ceiling follows), **not** from which channels are ticked.
  Sample rates must come from the device's own list (`--show`).
- Three driver log lines are harmless noise, not failures: `Align up to 4(from
  2)!`, `Device instance not active, can't set config`, `Failed to configure
  vref` (documented in nix-labs' ENVIRONMENTS.md — the write succeeds).
- Captures are `.sr` files (open in PulseView). `srdecode` does the text-side
  analysis: baud detection, UART frame extraction, diffing against a baseline
  (`srdecode CAPTURE.sr --diff BASELINE.sr`). `python3` with numpy is here for
  ad-hoc analysis — do not pip-install; the interpreter shares srdecode's numpy.
- The MCP server (`mcp-sigrok`) can scan, capture and decode for you (I²C/SPI/
  UART/CAN plus ~100 more protocols) and render waveforms as images. If it is
  not connected: `lab mcp slogic --write` (entering via `lab slogic` wires it
  automatically).
- `SIGROK_FIRMWARE_DIR` is preset with fx2lafw firmware for the cheap FX2
  "Saleae clone" analyzers.
