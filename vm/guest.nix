# NixOS guest for `lab-vm-<env>`: boots into the environment's GUI in a cage
# kiosk, has the environment's packages installed system-wide, the nix-labs
# udev rules for the redirected USB devices, SSH for file transfer and a 9p
# share of the host's lab directory. `lab`, `hostPkgs` and `sshPort` come from
# vm/default.nix via _module.args.
{
  pkgs,
  lab,
  hostPkgs,
  sshPort,
  ...
}:
let
  # Kiosk session: start in the shared directory and restart the program when it
  # is closed (the cage unit itself has no Restart=).
  session = pkgs.writeShellScript "lab-session" ''
    cd /home/lab/work 2>/dev/null || cd /home/lab
    while true; do
      /run/current-system/sw/bin/${lab.vm.program} || true
      sleep 1
    done
  '';
in
{
  system.stateVersion = "26.05";

  networking = {
    hostName = "lab-${lab.name}";
    firewall.enable = false; # QEMU user networking: only the host reaches us
  };

  # Redirected devices show up as ordinary USB devices in the guest, so the
  # same udev rules apply here; no registry inside the VM.
  labs = {
    enable = true;
    users = [ "lab" ];
    registry.enable = false;
  };

  users = {
    mutableUsers = false;
    users.lab = {
      isNormalUser = true;
      description = "nix-labs";
      password = "lab";
      extraGroups = [
        "wheel"
        "video"
        "input"
      ];
    };
  };
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = lab.packages ++ [ pkgs.usbutils ];

  services = {
    cage = {
      enable = true;
      user = "lab";
      program = "${session}";
      environment = {
        # Software rendering: works on bochs/std VGA (x86) and virtio-gpu (aarch64)
        # alike, and Xwayland (Qt5 PulseView, GLFW SDR++) needs no GPU.
        WLR_RENDERER = "pixman";
        XCURSOR_SIZE = "24";
      };
    };
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true;
        PermitRootLogin = "no";
      };
    };
  };

  hardware.graphics.enable = true;
  fonts.enableDefaultPackages = true;
  boot.kernelModules = [ "qemu_fw_cfg" ]; # /sys/firmware/qemu_fw_cfg for --kbd

  systemd.services = {
    # Runtime settings the host runner passes in, applied before the kiosk starts.
    lab-prepare = {
      description = "nix-labs VM: apply host runner settings and share ownership";
      before = [ "cage-tty1.service" ];
      wantedBy = [ "cage-tty1.service" ];
      unitConfig.RequiresMountsFor = "/home/lab/work";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # --kbd, via QEMU fw_cfg. It has to reach *cage* (the compositor reads
        # XKB_DEFAULT_LAYOUT at start-up), not the program cage launches.
        : >/run/lab-env
        layout=/sys/firmware/qemu_fw_cfg/by_name/opt/nix-labs/xkb_layout/raw
        if [ -r "$layout" ]; then
          printf 'XKB_DEFAULT_LAYOUT=%s\n' "$(cat "$layout")" >>/run/lab-env
        fi

        # The 9p share arrives owned by the host user. Under the default
        # mapped-xattr security model a guest-side chown is recorded in an xattr
        # and leaves host ownership alone, which is what lets the kiosk user save
        # captures there. Best effort: a host filesystem without xattr support
        # keeps the share read-only for `lab` — use scp over the forwarded port.
        if ! chown lab:users /home/lab/work 2>/dev/null; then
          echo "nix-labs: /home/lab/work may be read-only for the kiosk user (see docs/VM.md)" >&2
        fi
      '';
    };

    cage-tty1.serviceConfig.EnvironmentFile = "-/run/lab-env";
  };

  virtualisation = {
    host.pkgs = hostPkgs; # run script + QEMU for the *host* platform (Linux or macOS/HVF)
    memorySize = 4096;
    cores = 4;
    diskSize = 8192;
    graphics = true;
    resolution = {
      x = 1600;
      y = 900;
    };
    forwardPorts = [
      {
        from = "host";
        host.port = sshPort;
        guest.port = 22;
      }
    ];
    # Host directory (runner --share, default $HOME/lab) at /home/lab/work; the
    # run script expands the shell variable at start-up.
    sharedDirectories.work = {
      source = ''"''${LAB_SHARE:-$HOME/lab}"'';
      target = "/home/lab/work";
    };
    # xHCI controller for the usb-redir devices the runner adds at start-up.
    qemu.options = [ "-device qemu-xhci,id=xhci" ];
  };
}
