# SDR workspace

Pinned to the `sdr` environment of [nix-labs](https://github.com/whifflash/nix-labs):
LimeSuite, SoapySDR (+ LimeSDR/rtl-sdr/HackRF modules), SDR++, gqrx, urh, inspectrum.
Switch the flake to `shells.sdr-full` for GNU Radio Companion, SDRangel and SatDump.

```sh
direnv allow                    # or: nix develop
LimeUtil --find                 # LimeSDR present?
SoapySDRUtil --find             # every SoapySDR device (lime, rtlsdr, hackrf, …)
sdrpp                           # SDR++: Source → SoapySDR (or the LimeSDR source), then play
gqrx                            # device string for the LimeSDR: soapy=0,driver=lime
LimeSuiteGUI                    # calibration / firmware
```

Recordings: SDR++'s recorder writes WAV; `inspectrum capture.cf32` (Linux) or `urh` for
analysis. USB 3 is required for LimeSDR-USB sample rates above ~10 MS/s; inside `lab vm sdr`
(USB over usb-redir) stay well below that.
Re-pin: `nix flake update nix-labs`.
