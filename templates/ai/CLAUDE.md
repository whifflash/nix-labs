# Agent notes — the `ai` environment

A pinned bench of coding agents (opencode, pi, claude-code, codex, gemini-cli,
qwen-code, crush, goose, aider) plus context tooling (repomix, files-to-prompt,
llm, mods, aichat, fabric-ai, ast-grep, ripgrep, fd, difftastic, gh, glab).

- Entering shadows any globally installed agent for the duration of the shell —
  a version different from the everyday one is the point, not a bug.
  `claude-code` and `crush` are unfree; this is the **only** nix-labs
  environment that evaluates unfree derivations.
- **No credentials live in the environment.** Each agent reads its own key from
  env vars (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`,
  `GITHUB_PERSONAL_ACCESS_TOKEN`, …) or its config under `$HOME` (`~/.claude`,
  `~/.config/opencode`, `~/.pi`, `~/.codex`) — all untouched by the shell.
- MCP servers of every lab are in this shell (mcp-nixos, mcp-github, mcp-fetch,
  mcp-playwright register on entry; mcp-sigrok and mcp-soapysdr are here so the
  bench can drive the hardware labs too). Unlike the hardware labs, `npx -y …`
  and `uvx …` are the intended way to run third-party MCP servers here — nodejs,
  uv and bun are in the shell for exactly that; `npx @modelcontextprotocol/
  inspector` is the debugger.
- Other environments' servers can be added to a project:
  `lab mcp <env> --write` (e.g. the logic analyzer into this workspace).
- **pi ships without MCP on purpose** — install `@earendil-works/pi-mcp-adapter`
  (`pi-mcp-adapter init`), then `lab mcp <env> --client pi`; the adapter reads
  the same `mcpServers` shape from `.pi/mcp.json`.
