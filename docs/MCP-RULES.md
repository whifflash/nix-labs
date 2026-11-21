# MCP design rules

How the MCP servers in this flake should behave, and why. This is a living document. When we
adopt something, learn something, or a server changes, update the rule, the status table and
the changelog at the bottom. Never renumber; a dropped rule stays as "retired".

Where a rule can be code, it lives in `labmcp` (`pkgs/mcp/labmcp`), which every Python server
we write depends on. Where it can be checked, `checks/mcp-smoke.nix` checks it. Servers marked
`strict = true` in `pkgs/mcp/default.nix` are held to every checked rule. The others are only
held to rule 1.

## The rules

**1. stdout belongs to the protocol.** Over stdio, stdout carries JSON-RPC, and one stray line
corrupts the session. Native libraries (OpenCASCADE, SoapySDR modules) print to file descriptor
1 on their own, below anything Python can redirect. *How:* call `labmcp.protect_stdout()` before
importing anything that loads native code, and never `print()` to stdout. *Checked:* every
server.

**2. Tell the model how to use the server.** Send `instructions` at initialize: where to
start, which tools return images, units, and the one mistake models usually make. *Checked:*
strict servers.

**3. Offer discovery before action.** Give the model a tool that says what exists and what is
legal before it acts: `list_api`, `probe_device`, `command_list`. Point at it from the
instructions. The usual failure of generated code and settings is inventing an API or a
value. *Review.*

**4. Show, don't only tell.** Where a picture is the truth (a part, a spectrum, an edited
image), return it as image content, with a compact JSON summary next to it, so the model checks
its work by looking. *Review.*

**5. Reject unknown arguments, by name.** A misspelt key must fail and say which key it was.
If it is silently dropped, `gain_db` quietly falls back to automatic gain, and the model
believes it set it. FastMCP drops unknown keys by default. *How:* create the server with
`labmcp.server()`. *Checked:* strict servers (an unknown key sent to a read-only tool without
required arguments).

**6. Title and annotate every tool.** Give each tool a title and all four hints (`readOnlyHint`,
`destructiveHint`, `idempotentHint`, `openWorldHint`), so clients can let lookups run and ask
before writes. Pick from the `labmcp` presets so the same behaviour is always described the
same way: `READ_ONLY`, `OBSERVES`, `WRITES_FILES`, `RECORDS`, `RUNS_CODE`. A tool that executes
code the caller supplied is `RUNS_CODE`, whatever it is for. When in doubt, pick the more
cautious preset. *Checked:* strict servers (presence; the choice is review).

**7. Touch files only inside the workspace.** The workspace root is `MCP_<SERVER>_WORKDIR`, or
else the working directory, which is the project, because clients start stdio servers there.
Paths are relative to the root or absolute beneath it, and symlinks are resolved before the
check. *How:* `labmcp.Workspace`. This guards against mistakes and injected paths. It does not
sandbox code a server executes for the model; rule 6 says so instead. *Review.*

**8. Bound every call.** Limit samples, time, image size and reply size, and refuse with what
to change ("shorten the capture or lower the sample rate"), never by running out of memory.
Make limits overridable by `MCP_<SERVER>_*` variables. *Review.*

**9. A slow or crashing job must not take the server with it.** Run work that can hang or
crash (a model script, a long capture) away from the server loop: in a subprocess with a
timeout, or at least off the event loop. A failure then becomes a tool error, and ping and
cancellation keep working. FastMCP calls synchronous tools on its event loop. *Not yet adopted*
in cad and soapysdr; see `TODO.md`. *Review.*

**10. Errors are for the model.** Say what to do next: which tool to call, which setting to
change, what is probably unplugged. A bare stack trace makes the model guess. *Review.*

**11. Wrap upstream servers, don't fork them.** Point their dependencies at our builds with
default-only environment variables in the wrapper (`SIGROK_CLI_PATH`, `KICAD_CLI_PATH`,
`MCP_PHOTOCRAFT_ROOT`), so users can still override them. Push fixes upstream. *Review.*

**12. Every server is smoke-tested.** Every server this flake builds is started and spoken to
over stdio in `nix flake check` (`checks/mcp-smoke.nix`). A new server is `strict` unless it
is upstream code that cannot be. *Checked:* by existing.

## Status

✓ follows, ✗ does not, ~ partly, ? not reviewed. "Checked" rows are what `mcp-smoke`
enforces for strict servers.

| rule | cad | soapysdr | photocraft | sigrok | kicad |
|---|---|---|---|---|---|
| 1 stdout (checked) | ✓ | ✓ | ✓ | ✓ | ✓ |
| 2 instructions (checked) | ✓ | ✓ | ✓ | ✓ | ✗ |
| 3 discovery | ✓ `list_api` | ✓ `probe_device` | ✓ `command_list` | ✓ `scan_devices` | ✓ `list_projects` |
| 4 images | ✓ | ✓ | ✓ | ~ ASCII waveforms | ? |
| 5 unknown arguments (checked) | ✓ | ✓ | ✓ | ✗ | ? |
| 6 annotations (checked) | ✓ | ✓ | ✓ | ~ hints present, no titles, no tool marked read-only | ✗ |
| 7 workspace | ~ exports only; scripts run unconfined | ✓ | ✓ | ? | ? |
| 8 bounds | ~ no limit on script time | ✓ | ✓ | ? | ? |
| 9 isolation | ✗ in-process `exec`, process-wide `chdir` | ✗ blocks during captures | ✓ | ? | ? |
| strict | yes | yes | yes | no | no |

## Changelog

- 2026-10-15: First version, written while comparing our servers with PhotoCraft's (rules 5,
  6, 7 and 9 come from it). Added `labmcp` and `checks/mcp-smoke`. cad and soapysdr adopt
  rules 5, 6 and 7; rule 9 is recorded as not yet adopted. sigrok and kicad were probed but not
  changed.
