# A pinned bench of AI coding agents and the tooling around them.
#
# Several agents are marked unfree in nixpkgs (their vendors' terms), so this
# environment — and only this environment — uses a package set with an
# allowUnfreePredicate naming exactly those packages. Nothing else in the flake
# evaluates unfree derivations.
#
# No credentials live here: every agent reads its own key from the environment
# or from its config under $HOME, which the shell leaves alone.
{
  pkgs,
  lib,
  aiPkgs,
  labPkgs,
  mcpServers,
}:
let
  mcpPackages = lib.mapAttrsToList (_: s: s.package) mcpServers;
in
{
  ai = {
    packages =
      (with aiPkgs; [
        # Agents
        opencode
        pi-coding-agent # `pi` — no built-in MCP, see docs/MCP.md
        claude-code
        codex
        gemini-cli
        qwen-code
        crush
        goose-cli
        aider-chat
      ])
      ++ (with pkgs; [
        # Context and prompting
        repomix # pack a repo into one prompt-sized file
        files-to-prompt
        llm # simonw's CLI, plugins via `llm install`
        mods
        aichat
        fabric-ai
        # Reading code faster than an agent can grep
        ast-grep
        ripgrep
        fd
        difftastic
        jq
        yq-go
        gh
        glab
        # Running the npx/uvx MCP servers everyone else publishes, and
        # `npx @modelcontextprotocol/inspector` for debugging one.
        nodejs
        uv
        bun
        mcphost
      ])
      ++ mcpPackages
      # Our own servers, so `lab ai` can drive the bench as well as the repo.
      ++ [
        labPkgs.mcp-sigrok
        labPkgs.mcp-soapysdr
      ]
      ++ lib.optional pkgs.stdenv.hostPlatform.isLinux labPkgs.mcp-kicad;

    shellHook = ''
      echo "  agents: opencode | pi | claude | codex | gemini | qwen | crush | goose | aider"
      echo "  mcp:    lab mcp ai --write     (adds nixos/github/fetch/playwright to this project)"
      echo "  keys:   read from the environment / \$HOME as usual —"
      echo "          ANTHROPIC_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY, GITHUB_PERSONAL_ACCESS_TOKEN;"
      echo "          ~/.claude ~/.config/opencode ~/.pi ~/.codex are used untouched."
    '';
  };
}
