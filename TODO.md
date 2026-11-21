# TODO

## MCP servers end up in every host's closure

The home-manager module installs `lab`, and `lab` embeds `mcpConfigs`. Each environment's
`store.json` in there holds absolute store paths, so the `lab` closure is every MCP server in the
catalogue, along with everything they build. That covers `mcp-photocraft` → `photocraft`
(a Rust build from source, ~25 min on a 2-core VM), `mcp-sigrok` → `libsigrok-sipeed` (built
from source), and the cad stack. The nixos config imports `homeManagerModules.default` for every host, not only for hosts
with `[features] labs`. So each `task build` on each machine compiles all of these once per
bump. The flake's README already promises that environments are fetched on demand and never
enter a host's closure; the MCP servers break that promise.

The same happens in the nixos repo's `nix flake check`, because `flake-modules/dev` merges in
`nix-labs.checks`, and `mcp-render` and `lab-cli` depend on `mcpConfigs`.

Options, best first:

1. Ship only the `nix run labs#mcp-<name>` renderings (canonical, opencode, codex) in the `lab`
   CLI. They carry no store context. Keep `store.json` for the shells only: `LAB_MCP_CONFIG`
   inside a lab shell, where the servers are on PATH anyway. `lab mcp --store-paths` would then
   resolve the paths at run time (`nix build --no-link --print-out-paths labs#mcp-<name>`)
   instead of reading a pre-rendered file. `mcp-render` would split the same way, so the
   consumer's flake check stops building the servers.
2. Substitute rather than compile: push `photocraft`, `libsigrok-sipeed` and the other
   uncached lab packages to the attic cache from CI. This doesn't fix the closure, but it makes
   entering a shell fast on every machine, so it's worth doing alongside 1.
3. In the nixos config, gate `nix-labs.homeManagerModules.default` (or `labs.cli.enable`) on
   `features.labs`. This is cheap and limits the damage to lab hosts.
4. (Rejected) `unsafeDiscardStringContext` on `store.json`. It would hand out paths that were
   never built or have been garbage-collected.

## MCP rule 9: keep slow or crashing work away from the server loop

docs/MCP-RULES.md rule 9, not yet adopted. FastMCP calls synchronous tools on its event loop,
so while a tool runs, the server answers nothing: no ping, no cancellation.

- mcp-cad runs the model script in-process with `exec`, with no time limit, and `chdir`s the
  whole process. An endless loop hangs the server, and a crash in OpenCASCADE kills it. Run each
  script in a subprocess (the runner is already a separate module), with a timeout
  (`MCP_CAD_TIMEOUT`), and pass the shape back as a BREP file. That also makes cancellation a
  `kill`.
- mcp-soapysdr blocks for the whole capture (up to 60 s). Make the tools async, run the capture
  with `anyio.to_thread.run_sync`, and report progress for long captures. Serialise access to a
  device with a lock, since two captures cannot share one radio.

Update the status table in MCP-RULES.md when done. checks/mcp-smoke.nix could then also assert
that ping answers while a slow tool runs.

