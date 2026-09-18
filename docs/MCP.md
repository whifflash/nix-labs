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
| `ai` | `mcp-nixos`, `mcp-github`, `mcp-fetch`, `mcp-playwright` | nixpkgs/NixOS/home-manager option search, GitHub, URL→markdown, browser automation |

`mcp-sigrok` is upstream's [KenosInc/sigrok-mcp-server](https://github.com/KenosInc/sigrok-mcp-server)
wrapped so that `SIGROK_CLI_PATH` points at **our** `sigrok-cli-sipeed` — that is what makes it
see a Sipeed SLogic, which the stock build cannot. `mcp-kicad` is
[lamaalrajih/kicad-mcp](https://github.com/lamaalrajih/kicad-mcp) with `KICAD_CLI_PATH` pre-set.
`mcp-soapysdr` and `mcp-cad` are ours (see below).

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
2. Describe it in `pkgs/mcp/default.nix` (`package`, optional `args`/`env`, one-line description).
3. List its name in the environment's `mcp = [ … ]` in `labs/catalogue.nix`, and add the package
   to that environment's shell in `labs/<env>/default.nix`.

`lib/mcp.nix` renders the rest; `checks/mcp-render.nix` will fail the flake check if a claimed
server does not materialise or a format comes out malformed.

**The one rule for a stdio server: never write to stdout.** It carries JSON-RPC; one stray
`print()` or a chatty C++ library corrupts the stream. `mcp-soapysdr` shows the fix — dup the
real stdout aside, point file descriptor 1 at stderr, and hand the saved descriptor to the MCP
transport (`pkgs/mcp/soapysdr/src/mcp_soapysdr/__main__.py`).

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

Scripts execute unsandboxed, as the user running the server.

## mcp-soapysdr

Written here because every existing SDR MCP server is RTL-SDR-specific, and the two that
support more hardware ship no licence. Going through SoapySDR means one server for the
LimeSDR-USB, RTL-SDR dongles and HackRF, on Linux and macOS.

- `psd`, `spectrogram` and `analyse_iq_file` return **PNG images**, so the model can look at the
  spectrum rather than parse numbers, plus a JSON summary listing the strongest peaks with SNR.
- `capture_iq` writes complex-float32 (`.cf32`) with a JSON sidecar; `analyse_iq_file` re-opens
  it later without a radio attached.
- Captures are bounded (`MCP_SOAPYSDR_MAX_SAMPLES`, default 32 Mi samples ≈ 256 MB) and written
  under `MCP_SOAPYSDR_WORKDIR` (default: the working directory) so an agent cannot fill the disk
  with a typo'd duration.
- Gains default to the device AGC; pass `gain_db` for a fixed gain.
