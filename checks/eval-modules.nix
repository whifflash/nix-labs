# Eval-only smoke test of the NixOS + home-manager modules: a stub system with
# `labs.enable`, one lab user, the registry pinned to this flake, and the HM
# module. Contract assertions make regressions loud; nothing is built.
{
  self,
  nixpkgs,
  home-manager,
  system ? "x86_64-linux",
}:
let
  inherit (nixpkgs) lib;
  pkgs = import nixpkgs { inherit system; };

  sys = lib.nixosSystem {
    inherit system;
    modules = [
      home-manager.nixosModules.home-manager
      self.nixosModules.default
      {
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
        system.stateVersion = "26.05";
        users.users.smoke.isNormalUser = true;

        labs = {
          enable = true;
          users = [ "smoke" ];
          registry.flake = self;
        };

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.smoke = {
            imports = [ self.homeManagerModules.default ];
            home = {
              username = "smoke";
              homeDirectory = "/home/smoke";
              stateVersion = "26.05";
            };
          };
        };
      }
    ];
  };

  c = sys.config;
  h = c.home-manager.users.smoke;
  rules = self.lib.udevRules { };

  expect =
    name: cond: if cond then true else throw "eval-modules (${system}): expectation failed: ${name}";
  ok = lib.all (x: x) [
    (expect "udev rules installed" (
      lib.any (p: p.name == "70-nix-labs.rules") c.services.udev.packages
    ))
    (expect "rules cover both Sipeed vendor IDs" (
      lib.hasInfix ''ATTRS{idVendor}=="359f"'' rules && lib.hasInfix ''ATTRS{idVendor}=="2b1c"'' rules
    ))
    (expect "rules cover the LimeSDR-USB" (
      lib.hasInfix ''ATTRS{idVendor}=="1d50", ATTRS{idProduct}=="6108"'' rules
    ))
    (expect "probes are hidden from ModemManager" (lib.hasInfix "ID_MM_DEVICE_IGNORE" rules))
    (expect "plugdev group exists" (c.users.groups ? plugdev))
    (expect "lab user in plugdev + dialout" (
      lib.all (g: lib.elem g c.users.users.smoke.extraGroups) [
        "plugdev"
        "dialout"
      ]
    ))
    (expect "registry pinned to the flake" (c.nix.registry.labs.to.type == "path"))
    (expect "lab CLI installed" (lib.any (p: p.name == "lab") h.home.packages))
    (expect "direnv + nix-direnv on" (h.programs.direnv.enable && h.programs.direnv.nix-direnv.enable))
  ];
in
assert ok;
pkgs.writeText "eval-modules-${system}" (
  builtins.unsafeDiscardStringContext c.system.build.toplevel.drvPath + "\n"
)
