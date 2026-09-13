# AI agent workspace

Pinned to the `ai` environment of [nix-labs](https://github.com/whifflash/nix-labs):
opencode, pi, claude-code, codex, gemini-cli, qwen-code, crush, goose and aider, plus
context tooling (repomix, files-to-prompt, llm, ast-grep) and the MCP servers wired up in
`.mcp.json` / `opencode.json` (nixpkgs/NixOS option search, GitHub, fetch, Playwright).

```sh
direnv allow            # or: nix develop
opencode                # reads opencode.json
claude                  # reads .mcp.json
pi                      # no built-in MCP — see below

# Add another environment's servers to this project, e.g. the logic analyzer:
lab mcp slogic --write
```

Credentials are never part of the environment: each agent reads its own key from the
environment (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`,
`GITHUB_PERSONAL_ACCESS_TOKEN`, …) or its config under `$HOME` (`~/.claude`,
`~/.config/opencode`, `~/.pi`, `~/.codex`), which this shell leaves untouched.

**pi and MCP**: pi ships without MCP support on purpose. Install its adapter
(`npm i -g @earendil-works/pi-mcp-adapter && pi-mcp-adapter init`) and run
`lab mcp <env> --client pi` — it reads the same Claude-style `mcpServers` shape from
`.pi/mcp.json`.

Re-pin: `nix flake update nix-labs`.
