# Agent notes — the `sdr` environment

Software-defined radio around the LimeSDR-USB, with SoapySDR as the common
device layer. Everything is in the shell — do not build or install SDR stacks:
`SOAPY_SDR_PLUGIN_PATH` is exported so **every** program here sees the same
modules (LimeSDR, rtl-sdr, HackRF, audio, remote), not just SoapySDRUtil.

- Discovery first: `LimeUtil --find` (LimeSDR present?), `SoapySDRUtil --find`
  (everything Soapy sees). GUIs: `sdrpp` (Source → SoapySDR), `gqrx` (device
  string `soapy=0,driver=lime`), `LimeSuiteGUI` (calibration/firmware).
- **LimeSDR-USB needs USB 3** above ~10 MS/s. Inside `lab vm sdr` (USB over
  usb-redir) stay well below that — the VM is for GUI/analysis convenience, not
  wideband capture.
- The MCP server (`mcp-soapysdr`) can probe, capture, compute PSD/spectrograms,
  scan bands and demodulate FM for you. `psd`/`spectrogram` return **PNG images**
  plus a JSON peak summary — look at the picture, don't parse numbers. Captures
  are bounded (`MCP_SOAPYSDR_MAX_SAMPLES`, default 32 Mi ≈ 256 MB) and written
  under the working directory — a typo'd duration cannot fill the disk.
- Recordings are complex-float32 (`.cf32`); `capture_iq` writes a JSON sidecar
  and `analyse_iq_file` re-opens the file later without a radio attached.
- If the MCP tools are not connected: `lab mcp sdr --write` (entering via
  `lab sdr` wires them automatically).
