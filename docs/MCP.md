# MCP — letting an agent drive the bench

Every hardware environment ships a [Model Context Protocol](https://modelcontextprotocol.io)
server, so an agent can capture a trace, sweep a band or read a schematic instead of telling
you which buttons to press. The servers are ordinary packages (`nix run labs#mcp-<name>`);
what `lab mcp` adds is the config plumbing, because every client invented its own file format.

| environment | server | what the agent can do |
|---|---|---|
| `slogic` | `mcp-sigrok` | `scan_devices`, `capture_data`, `decode_protocol` (I²C/SPI/UART/CAN + 100 more), `render_waveform`, `show_driver_details`, `check_firmware_status` … 14 tools |
| `sdr` | `mcp-soapysdr` | `list_devices`, `probe_device`, `capture_iq`, `psd`, `spectrogram`, `scan_band`, `demod_fm`, `analyse_iq_file` |
| `eda` | `mcp-kicad` | `list_projects`, `extract_project_netlist`, `find_component_connections`, `run_drc_check`, `analyze_bom`, `export_bom_csv`, `identify_circuit_patterns`, `generate_pcb_thumbnail` … 16 tools |
| `cad` | `mcp-cad` | `run` (export STEP/STL/GLB/3MF/BREP), `measure` (volume, area, centre of mass, bbox, validity — from the B-rep, not a mesh), `preview` (renders as **images**), `list_api` (build123d symbols + signatures), `openscad_render` |
| `photocraft` | `mcp-photocraft` | `command_list`, `command_run`, `command_batch` (the editor's 500+ commands), `doc_inspect` (layer tree, history, selection), `render_preview` (as an **image**), open/save documents; bridged to the running app, also `ui_inspect` and `ui_screenshot` |
| `ai` | `mcp-nixos`, `mcp-github`, `mcp-fetch`, `mcp-playwright` | nixpkgs/NixOS/home-manager option search, GitHub, URL→markdown, browser automation |

`mcp-sigrok` is upstream's [KenosInc/sigrok-mcp-server](https://github.com/KenosInc/sigrok-mcp-server)
wrapped so that `SIGROK_CLI_PATH` points at **our** `sigrok-cli-sipeed` — that is what makes it
see a Sipeed SLogic, which the stock build cannot. `mcp-kicad` is
[lamaalrajih/kicad-mcp](https://github.com/lamaalrajih/kicad-mcp) with `KICAD_CLI_PATH` pre-set.
`mcp-photocraft` is PhotoCraft's own server (`photocraft-cli mcp`), with its filesystem roots
set to the project. `mcp-soapysdr` and `mcp-cad` are ours (see below).

## Using it

```sh
lab mcp slogic                      # print the Claude Code config
lab mcp slogic --write              # merge it into ./.mcp.json
lab mcp sdr --client opencode --write
lab mcp eda --client codex --write  # appends to ~/.codex/config.toml
lab init eda ~/src/board            # scaffolds .mcp.json + opencode.json for you
```

Inside any lab shell, `$LAB_MCP_CONFIG` already points at a ready-made config with absolute
store paths, so `claude --mcp-config "$LAB_MCP_CONFIG"` needs no files at all.

MCP tools alone are not context: an agent also needs to know which engine to reach for, the
`result` convention and that the shell's Python is complete (never pip-install beside it — the
lab's PYTHONPATH leaks into venvs and breaks them). That is what the `CLAUDE.md` (+ `AGENTS.md`
symlink) in the templates is for; in a project that predates `lab init`, copy it from
`templates/<env>/`.

The servers wire themselves these days: `lab <env>` run inside a project directory registers
that environment's servers in `./.mcp.json` as part of entering — merge-if-absent, never
touching entries the project set itself (the `lab mcp <env> --write` rule, without the
forgetting). Entering through direnv or a direct `nix develop` bypasses `lab`, which is why
the templates ship the file pre-written; there, `lab mcp <env> --write` remains the manual
equivalent.

`--write` merges rather than overwrites, and refuses to replace a server entry that is already
there unless you pass `--force`.

## The three formats

| client | file | shape |
|---|---|---|
| Claude Code | `.mcp.json` | `{"mcpServers":{"<name>":{"command","args","env"}}}` |
| gemini-cli | `.gemini/settings.json` | same |
| qwen-code | `.qwen/settings.json` | same |
| pi (via adapter) | `.pi/mcp.json` | same |
| opencode | `opencode.json` | `{"mcp":{"<name>":{"type":"local","command":["…"],"enabled":true,"environment":{}}}}` |
| codex | `~/.codex/config.toml` | `[mcp_servers.<name>]` with `command` / `args` |

**pi has no built-in MCP** — that is a deliberate upstream decision. Install
`@earendil-works/pi-mcp-adapter`, run `pi-mcp-adapter init`, and then `lab mcp <env> --client pi`;
the adapter reads exactly the Claude-style shape.

By default the generated commands are `nix run labs#mcp-<name>`, which keeps a committed
project file working after a garbage collection and resolves through the `labs` registry entry
the NixOS/nix-darwin module installs. `--store-paths` emits absolute `/nix/store/…` commands
instead (faster start-up, GC-able).

## Adding a server

1. Package it under `pkgs/mcp/`, named `mcp-<name>`, and add it to `pkgs/default.nix`.
2. Describe it in `pkgs/mcp/default.nix` (`package`, optional `args`/`env`, one-line
   description), with `strict = true` unless it is upstream code that cannot follow the rules.
3. List its name in the environment's `mcp = [ … ]` in `labs/catalogue.nix`, and add the package
   to that environment's shell in `labs/<env>/default.nix`.

`lib/mcp.nix` renders the rest. `checks/mcp-render.nix` fails the flake check if a claimed
server does not materialise or a format comes out malformed. `checks/mcp-smoke.nix` starts
every server we build and speaks MCP to it over stdio.

**How a server should behave is in [MCP-RULES.md](MCP-RULES.md)**: stdout belongs to the
protocol, unknown arguments are rejected, every tool is titled and annotated, files stay in
the workspace, and so on. A Python server we write depends on `labmcp` (`pkgs/mcp/labmcp`),
which implements the mechanical part. `mcp-soapysdr` and `mcp-cad` show the shape.

## mcp-cad

build123d scripts in, solids and pictures out. A script assigns its solid to `result` (or calls
`show_object()`), which is the same convention `cad-watch` uses, so the agent and the live
preview build models identically.

- `preview` renders the part with f3d offscreen from any of four camera directions and returns
  the PNGs as image content, so the model can check its own work instead of guessing from numbers.
- `measure` reads volume, area, centre of mass, bounding box and `is_valid` analytically from
  the kernel. A mesh-derived figure would be an approximation; this is not.
- `list_api` exists because the documented failure mode of LLM-written CAD is calling methods
  that do not exist. Point the agent at it before it invents an API.
- `openscad_render` covers the DSL half: source in, mesh plus a rendered PNG out. No STEP —
  OpenSCAD cannot produce one.

Exports land under `MCP_CAD_WORKDIR` (default: the working directory) and nowhere else. The
scripts themselves execute unsandboxed, as the user running the server, which is why every
tool that runs one is annotated as able to do anything.

## mcp-soapysdr

Written here because every existing SDR MCP server is RTL-SDR-specific, and the two that
support more hardware ship no licence. Going through SoapySDR means one server for the
LimeSDR-USB, RTL-SDR dongles and HackRF, on Linux and macOS.

- `psd`, `spectrogram` and `analyse_iq_file` return **PNG images**, so the model can look at the
  spectrum rather than parse numbers, plus a JSON summary listing the strongest peaks with SNR.
- `capture_iq` writes complex-float32 (`.cf32`) with a JSON sidecar; `analyse_iq_file` re-opens
  it later without a radio attached.
- Captures are bounded (`MCP_SOAPYSDR_MAX_SAMPLES`, default 32 Mi samples ≈ 256 MB), so an
  agent cannot fill the disk with a typo'd duration. Files are read and written only under
  `MCP_SOAPYSDR_WORKDIR` (default: the working directory).
- Gains default to the device AGC; pass `gain_db` for a fixed gain.

## mcp-photocraft

`photocraft-cli mcp` is upstream's stdio server over the same command engine as the app's menus.
Upstream fails closed on files. Without `--automation-read-root` / `--automation-write-root` it
can neither open nor save anything, which suits a shared install but leaves a project's agent
with in-memory documents only. The wrapper therefore grants both roots on the directory the
client starts it in, which is the project. `MCP_PHOTOCRAFT_ROOT` moves them. Paths outside the
root, `..` traversal and escaping symlinks are refused by PhotoCraft itself.

- `render_preview` returns a bounded PNG (≤ 2048 px a side), so the model checks its edit by
  looking at it.
- Before experimenting, run `image.duplicate` (or `history.newDocument`) and edit the copy.
  `command_batch` is not a transaction, and undo does not take back files already saved.
- To drive the app a person is watching, start it with
  `photocraft --control 7878 --control-token-file .private/control.token` and append
  `--bridge 127.0.0.1:7878 --control-token-file .private/control.token` to the server's
  arguments. The CLI takes the last occurrence of a flag, and in bridge mode the app's own
  roots apply. This adds `ui_inspect` and `ui_screenshot`.

Upstream's caveat applies: the token proves possession, and there are no per-tool scopes yet.
Do not put either transport behind anything remote.
