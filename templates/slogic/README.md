# Logic-analyzer workspace

Pinned to the `slogic` environment of [nix-labs](https://github.com/whifflash/nix-labs):
PulseView and sigrok-cli built against libsigrok with the Sipeed SLogic driver.

```sh
direnv allow                    # or: nix develop
sigrok-cli --driver sipeed-slogic-analyzer --scan
pulseview                       # GUI; pick "Sipeed Slogic Analyzer" in the device dialog

# headless capture: 16 channels, 20 MHz, 1 M samples → capture.sr (open in PulseView)
sigrok-cli --driver sipeed-slogic-analyzer --config samplerate=20m --samples 1M -o capture.sr
```

No device found? On Linux the host needs the nix-labs udev rules (`labs.enable`); on macOS
try `lab vm slogic` if PulseView cannot open the analyzer natively.
Re-pin: `nix flake update nix-labs`.
