# `lab-vm-<env>` runners: a NixOS guest (qemu-vm) that boots straight into the
# environment's GUI in a cage kiosk, with the environment's packages installed
# and host USB devices redirected in over QEMU's usb-redir (nixpkgs' QEMU has no
# libusb, so `-device usb-host` is not an option; the host side is `usbredirect`
# from the usbredir package — see vm/runner.sh and docs/VM.md).
#
# The guest is built for the host's CPU architecture (x86_64 → x86_64-linux,
# Apple Silicon → aarch64-linux, HVF). Building it on macOS needs a Linux
# builder (nix-darwin `nix.linux-builder.enable = true`).
{
  lib,
  nixpkgs,
  hostPkgs,
  labsFor,
  labsFlake,
}:
let
  guestSystem = "${hostPkgs.stdenv.hostPlatform.parsed.cpu.name}-linux";
  guestPkgs = import nixpkgs { system = guestSystem; };
  guestLabs = labsFor guestPkgs;

  catalogue = import ../labs/catalogue.nix;
  hardware = import ../lib/hardware.nix;
  sshPort = 2223;

  mkVm =
    name: meta:
    let
      lab = guestLabs.${name};
      guest = nixpkgs.lib.nixosSystem {
        system = guestSystem;
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          labsFlake.nixosModules.default
          ./guest.nix
          { _module.args = { inherit lab hostPkgs sshPort; }; }
        ];
      };
      runScript = "${guest.config.system.build.vm}/bin/run-${guest.config.system.name}-vm";
      usbDefaults = lib.concatMap (d: hardware.${d}.vm or [ ]) meta.usb;
    in
    hostPkgs.writeShellApplication {
      name = "lab-vm-${name}";
      runtimeInputs = [
        hostPkgs.usbredir
        hostPkgs.coreutils
      ];
      text =
        lib.replaceStrings
          [
            "@LAB@"
            "@VM_RUN@"
            "@USB_DEFAULT@"
            "@SSH_PORT@"
          ]
          [
            name
            runScript
            (lib.concatStringsSep " " usbDefaults)
            (toString sshPort)
          ]
          (builtins.readFile ./runner.sh);
      meta.description = "Run the nix-labs '${name}' environment in a QEMU VM with host USB devices redirected into it";
    };
in
lib.mapAttrs' (name: meta: lib.nameValuePair "lab-vm-${name}" (mkVm name meta)) (
  lib.filterAttrs (_: m: m.vm != null) catalogue
)
