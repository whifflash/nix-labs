# nix-labs

Portable lab & development environments as Nix flake **devShells**, usable on any
machine with Nix (NixOS, other Linux, macOS):

| environment | what you get | hardware |
|---|---|---|
| `zephyr-arm` `zephyr-riscv` `zephyr-esp32` `zephyr-full` | Zephyr SDK for one chip family (or all), west + Zephyr's Python deps, cmake/ninja/dtc, openocd (Zephyr fork), probe-rs, pyocd, picotool, esptool, tio | debug probes, DFU/BOOTSEL, USB-serial |
| `sdr` / `sdr-full` | LimeSuite, SoapySDR (+ Lime/rtl-sdr/HackRF modules), SDR++, gqrx, urh, inspectrum, rtl-sdr, multimon-ng — `full` adds GNU Radio (gr-osmosdr), SDRangel, SatDump | LimeSDR-USB/Mini, RTL-SDR, HackRF |
| `slogic` | PulseView + sigrok-cli built against `libsigrok-sipeed` (Sipeed SLogic driver), fx2lafw firmware | Sipeed SLogic Combo8 / 16U3 / 32U3 |
| `eda` | KiCad 10 + KiKit + FreeRouting, ngspice/Xyce/Qucs-s/xschem, gerbv/KLayout, SKiDL | bench gear on USB-serial |
| `cad` | Parametric CAD as code: build123d (Python/OCCT — STEP + STL), OpenSCAD, live preview via `cad-watch` + f3d | — |
| `ai` | opencode, pi, claude-code, codex, gemini-cli, qwen-code, crush, goose, aider + context and MCP tooling | — |
| `platformio` | PlatformIO in an FHS environment, for everything that is not Zephyr (Linux only) | Arduino/ESP/STM32 boards, probes |

Plus: an **MCP server per hardware environment** so an agent can drive the bench
([docs/MCP.md](docs/MCP.md)), a **NixOS module** (udev rules + device groups + flake-registry
entry), a **nix-darwin module** (registry entry), a **home-manager module** (`lab` CLI, direnv),
**project templates**, and **`lab-vm-<env>` QEMU runners** for hardware — or software, like
KiCad on a Mac — a host cannot run natively ([docs/VM.md](docs/VM.md)).

## Use it

```sh
nix develop github:whifflash/nix-labs#slogic         # anywhere with flakes enabled
lab list && lab slogic                               # with the modules below: registry entry `labs`
lab init zephyr-arm ~/src/blinky && cd ~/src/blinky && direnv allow
lab mcp slogic --write                               # let this project's agent drive the analyzer
lab vm slogic                                        # QEMU fallback with the SLogic redirected in
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
flake.nix            outputs: devShells, packages (sigrok-*-sipeed, mcp-*, lab, lab-vm-*, mcpConfigs),
                     overlays, nixosModules, darwinModules, homeManagerModules, templates, checks
lib/                 hardware.nix (USB catalogue), udev-rules.nix, mk-lab.nix, mcp.nix (config renderers)
labs/                catalogue.nix (name → description/template/usb/vm/mcp) + <env>/default.nix (packages)
pkgs/                sigrok frontends against libsigrok-sipeed, python/ (the build123d stack),
                     mcp/ (four MCP servers), cad-watch.nix (the CAD preview loop),
                     mcp-config.nix (pre-rendered client configs), lab.nix + lab.sh (the CLI)
nixos/ darwin/ home/ modules (modules/registry.nix is shared by nixos + darwin)
vm/                  guest.nix (cage kiosk NixOS), runner.sh (QEMU + usbredirect), default.nix
templates/           zephyr (west T2 workspace), sdr, slogic, eda, cad, ai
checks/              eval smokes (shells on x86_64-linux + aarch64-darwin, modules, VMs), mcp-render
docs/                ENVIRONMENTS.md, MCP.md, HARDWARE.md, VM.md
```

## Develop

```sh
nix flake check              # statix, deadnix, shellcheck (lab CLI, VM runner), eval smokes, mcp-render
nix fmt                      # nixfmt + shfmt via treefmt
nix develop .#slogic -c sigrok-cli -L | grep sipeed   # the driver really is in
```

Consumers keep a local dev loop with `--override-input nix-labs path:../nix-labs` (or
`LAB_FLAKE=path:../nix-labs lab slogic`), and re-pin with `nix flake update nix-labs`.

Adding an environment: an entry in `labs/catalogue.nix`, a package list in `labs/<env>/`,
optionally a template. Adding hardware: an entry in `lib/hardware.nix` (rules, VM defaults and
the docs table follow from it). Adding an MCP server: see [docs/MCP.md](docs/MCP.md).
