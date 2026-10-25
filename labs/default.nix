# All environments for one package set: catalogue metadata + per-environment
# package lists → mkLab records ({ devShell; packages; usb; vm; … }).
{
  pkgs,
  lib,
  labPkgs,
  zephyr,
  aiPkgs,
  mcpServers,
  mcpConfigs,
}:
let
  catalogue = import ./catalogue.nix;
  mkLab = import ../lib/mk-lab.nix { inherit pkgs lib; };

  defs =
    import ./zephyr { inherit pkgs lib zephyr; }
    // import ./sdr { inherit pkgs lib labPkgs; }
    // import ./slogic { inherit pkgs lib labPkgs; }
    // import ./eda { inherit pkgs lib labPkgs; }
    // import ./cad { inherit pkgs lib labPkgs; }
    // import ./ai {
      inherit
        pkgs
        lib
        aiPkgs
        labPkgs
        mcpServers
        ;
    }
    // import ./platformio { inherit pkgs lib; };

  # Linux-only environments simply do not exist on darwin (see labs/platformio).
  expected = lib.filterAttrs (
    _: m: pkgs.stdenv.hostPlatform.isLinux || !(m.linuxOnly or false)
  ) catalogue;

  missing = lib.subtractLists (lib.attrNames defs) (lib.attrNames expected);
  extra = lib.subtractLists (lib.attrNames expected) (lib.attrNames defs);

  # Every shell exports LAB_ENV (its name), so anything running inside —
  # scripts, editors, coding agents — can tell which lab it is in without
  # guessing from PATH. Environments with MCP servers additionally get
  # LAB_MCP_CONFIG pointing at their ready-made canonical config (store paths —
  # the servers are in the shell anyway), so `claude --mcp-config
  # "$LAB_MCP_CONFIG"` works with no setup.
  withEnv =
    name: def:
    let
      hasMcp = (catalogue.${name}.mcp or [ ]) != [ ];
    in
    def
    // {
      env =
        (def.env or { })
        // {
          LAB_ENV = name;
        }
        // lib.optionalAttrs hasMcp {
          LAB_MCP_CONFIG = "${mcpConfigs}/${name}/store.json";
        };
    };
in
assert lib.assertMsg (
  missing == [ ]
) "labs/catalogue.nix lists environments without a definition: ${toString missing}";
assert lib.assertMsg (
  extra == [ ]
) "labs/ defines environments missing from labs/catalogue.nix: ${toString extra}";
lib.mapAttrs (name: def: mkLab (catalogue.${name} // (withEnv name def) // { inherit name; })) defs
