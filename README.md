# nix-labs

Portable lab & development environments as Nix flake **devShells**, usable on any
machine with Nix (NixOS, other Linux, macOS):

| environment | what you get | hardware |
|---|---|---|
| `zephyr-arm` `zephyr-riscv` `zephyr-esp32` `zephyr-full` | Zephyr SDK for one chip family (or all), west + Zephyr's Python deps, cmake/ninja/dtc, openocd (Zephyr fork), probe-rs, pyocd, picotool, esptool, tio | debug probes, DFU/BOOTSEL, USB-serial |
| `sdr` / `sdr-full` | LimeSuite, SoapySDR (+ Lime/rtl-sdr/HackRF modules), SDR++, gqrx, urh, inspectrum, rtl-sdr, multimon-ng — `full` adds GNU Radio (gr-osmosdr), SDRangel, SatDump | LimeSDR-USB/Mini, RTL-SDR, HackRF |
| `logic` | PulseView + sigrok-cli built against `libsigrok-sipeed` (Sipeed SLogic driver), fx2lafw firmware | Sipeed SLogic Combo8 / 16U3 / 32U3 |
| `platformio` | PlatformIO in an FHS environment, for everything that is not Zephyr (Linux only) | Arduino/ESP/STM32 boards, probes |

Plus: a **NixOS module** (udev rules + device groups + flake-registry entry), a
**nix-darwin module** (registry entry), a **home-manager module** (`lab` CLI, direnv),
**project templates**, and **`lab-vm-<env>` QEMU runners** for hardware a host cannot
drive natively (e.g. a Mac and the logic analyzer) — see [docs/VM.md](docs/VM.md).

## Use it

```sh
nix develop github:whifflash/nix-labs#logic          # anywhere with flakes enabled
lab list && lab logic                                # with the modules below: registry entry `labs`
lab init zephyr-arm ~/src/blinky && cd ~/src/blinky && direnv allow
lab vm logic                                         # QEMU fallback with the SLogic redirected in
```

`lab <env> -- cmd …` runs one command inside an environment; `nix flake init -t labs#zephyr`
is what `lab init` wraps. Details per environment: [docs/ENVIRONMENTS.md](docs/ENVIRONMENTS.md).

## Consume from a NixOS / nix-darwin / home-manager configuration

```nix
inputs.nix-labs = {
  url = "github:whifflash/nix-labs";
  inputs.nixpkgs.follows = "nixpkgs";   # both on nixos-26.05
};

# NixOS
imports = [ inputs.nix-labs.nixosModules.default ];
labs = {
  enable = true;
  users = [ "alice" ];                  # → plugdev + dialout
  registry.flake = inputs.nix-labs;     # `labs#…` = the revision this system was built from
};

# nix-darwin
imports = [ inputs.nix-labs.darwinModules.default ];
labs.enable = true;
# nix.linux-builder.enable = true;      # only for `lab vm …` (builds the aarch64-linux guest)

# home-manager (both platforms)
imports = [ inputs.nix-labs.homeManagerModules.default ];
# labs.flakeRef = "path:/home/alice/src/nix-labs";   # local dev loop; default "labs"
```

Nothing from the environments lands in the system closure — the module only installs
udev rules (`lib/hardware.nix` → `70-nix-labs.rules`, see [docs/HARDWARE.md](docs/HARDWARE.md))
and a registry entry. Hosts without the module use the full flake reference instead of `labs`.

## Layout

```
flake.nix            outputs: devShells, packages (pulseview-sipeed, sigrok-cli-sipeed, lab, lab-vm-*),
                     overlays, nixosModules, darwinModules, homeManagerModules, templates, checks
lib/                 hardware.nix (USB catalogue), udev-rules.nix, mk-lab.nix
labs/                catalogue.nix (name → description/template/usb/vm) + <env>/default.nix (packages)
pkgs/                sigrok frontends against libsigrok-sipeed, the `lab` CLI
nixos/ darwin/ home/ modules (modules/registry.nix is shared by nixos + darwin)
vm/                  guest.nix (cage kiosk NixOS), runner.sh (QEMU + usbredirect), default.nix
templates/           zephyr (west T2 workspace), sdr, logic
checks/              eval smokes (shells on x86_64-linux + aarch64-darwin, modules, VMs)
docs/                ENVIRONMENTS.md, HARDWARE.md, VM.md
```

## Develop

```sh
nix flake check              # statix, deadnix, shellcheck (lab CLI, VM runner), eval smokes
nix fmt                      # nixfmt + shfmt via treefmt
nix develop .#logic -c sigrok-cli -L | grep sipeed   # the driver really is in
```

Consumers keep a local dev loop with `--override-input nix-labs path:../nix-labs` (or
`LAB_FLAKE=path:../nix-labs lab logic`), and re-pin with `nix flake update nix-labs`.

Adding an environment: an entry in `labs/catalogue.nix`, a package list in `labs/<env>/`,
optionally a template. Adding hardware: an entry in `lib/hardware.nix` (rules, VM defaults and
the docs table follow from it).
