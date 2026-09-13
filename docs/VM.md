# `lab-vm-<env>` — the QEMU fallback

Native first: the sigrok, LimeSuite and SoapySDR stacks are user-space libusb programs and
run on Linux and macOS alike. The VM exists for the cases where that fails (a macOS build of
PulseView that does not work, a driver that needs Linux udev/kernel behaviour) — not as the
default way to use the hardware.

The exception is **`lab vm eda`**: KiCad is not in nixpkgs for macOS at all, so on a Mac the VM
is a first-class way to run it (no USB involved — the runner simply starts without redirection).

```sh
lab vm slogic                          # = nix run labs#lab-vm-slogic
lab vm slogic -- -m 8G                 # extra QEMU arguments after --
lab vm sdr --usb 1d50:6108 --usb 0bda:2838 --share ~/captures --kbd de
lab-vm-slogic --help
```

## What runs

- **Guest**: NixOS (`vm/guest.nix`) on nixpkgs' `qemu-vm` module — `services.cage` kiosk
  starting the environment's GUI (`pulseview`, `sdrpp`, `kicad`; restarted when closed), the
  environment's packages installed system-wide, the nix-labs udev rules, `sshd`, user `lab`
  (password `lab`, passwordless sudo). 4 GiB RAM, 4 cores, 8 GiB disk (persistent qcow2 under
  `~/.local/state/nix-labs/vm/<env>/`).
- **Host runner** (`vm/runner.sh`): starts the guest's run script, then for every USB device
  one `usbredirect --device VID:PID --to 127.0.0.1:<port>` against a QEMU `usb-redir` device on
  the guest's xHCI controller — re-attached automatically when the device is replugged. Defaults
  come from `lib/hardware.nix` (`slogic`: `359f:3031`, `2b1c:3031`; `sdr`: `1d50:6108`, …);
  `--usb` replaces them, `--no-usb` disables redirection.
- **Share**: `--share DIR` (default `$HOME/lab`) is the guest's `/home/lab/work` (9p) — the
  kiosk program starts there, captures land on the host. `ssh -p 2223 lab@127.0.0.1` for
  anything else.
- **Keyboard**: `--kbd LAYOUT` (or `LAB_KBD`) reaches the guest through QEMU fw_cfg.

Why usbredir and not `-device usb-host`: nixpkgs builds QEMU without libusb (on Linux and
macOS), so direct host-device passthrough is not available; `usbredir` is, and its
`usbredirect` tool provides the host side. Rebuilding QEMU with libusb would cost an hour per
machine for the same result.

## Platforms

| host | guest | accel | notes |
|---|---|---|---|
| x86_64 Linux (NixOS) | x86_64-linux | KVM | `usbredirect` runs as your user thanks to the udev rules (`labs.enable`) |
| Apple Silicon macOS | aarch64-linux | HVF | build the guest with a Linux builder: `nix.linux-builder.enable = true` in nix-darwin, or a remote builder; `usbredirect` needs `sudo` to detach the device from macOS (the runner prompts) |

## Caveats

- **macOS USB**: claiming a device needs root, and Apple-Silicon passthrough is known to be
  flaky for some devices (QEMU issues #1951, #2178). The logic analyzer (bulk transfers,
  moderate rates) is the realistic case; a LimeSDR at high sample rates over a TCP usbredir
  stream will drop samples — use the SDR VM for GUI/analysis at low rates only.
- **9p share**: it arrives owned by the host user, so a boot service chowns it to the kiosk user
  (with the default `mapped-xattr` model that is an xattr on the host, not a real ownership
  change). A host filesystem without xattr support leaves the share read-only in the guest — the
  service says so in the journal; `scp -P 2223` is the fallback. `-virtfs` on a Darwin host is
  expected to work but has not been verified here; if the guest fails to start on the Mac, the
  share can be made conditional on the host platform.
- **First start** builds the guest closure (a full NixOS with the environment's packages) —
  minutes on Linux, longer on a Mac through the Linux builder. Later starts boot in seconds.
- The guest's `/nix/store` is the host's, mounted read-only over 9p (qemu-vm default) — the
  disk image only holds state.
