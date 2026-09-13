# lab — enter, list, scaffold and virtualise nix-labs environments, and wire
# their MCP servers into a project.
# Substituted at build time: @CATALOGUE@ (json), @MCPCONFIGS@ (dir), @FLAKE@.

flake="${LAB_FLAKE:-@FLAKE@}"
catalogue="@CATALOGUE@"
mcp_configs="@MCPCONFIGS@"

usage() {
  cat <<EOF
Usage:
  lab list                       environments in the nix-labs catalogue
  lab <env> [-- cmd [args…]]     enter the environment (or run cmd inside it)
  lab init <env> [dir]           scaffold a project pinned to <env> (nix flake init -t)
  lab vm <env> [runner args…]    run the QEMU fallback VM for <env> (see: lab vm <env> --help)
  lab mcp <env> [opts]           MCP server config for <env> (entries marked [mcp])
  lab update [dir]               re-pin a project's nix-labs input (nix flake update nix-labs)

lab mcp options:
  --client NAME   claude (default) | opencode | codex | gemini | qwen | pi
  --write [DIR]   merge into the client's config file under DIR (default: .)
                  — codex writes to \$HOME/.codex/config.toml
  --force         overwrite server entries that already exist
  --store-paths   emit absolute /nix/store paths instead of 'nix run $flake#…'

Flake: $flake   (override: LAB_FLAKE=path:/…/nix-labs, or the home-manager option labs.flakeRef)
EOF
}

die() {
  printf 'lab: %s\n' "$*" >&2
  exit 1
}

have_env() {
  jq -e --arg e "$1" 'has($e)' "$catalogue" >/dev/null 2>&1
}

require_env() {
  [ -n "${1:-}" ] || die "missing environment name (try: lab list)"
  have_env "$1" || die "unknown environment '$1' (try: lab list)"
}

list() {
  jq -r 'to_entries[]
    | "\(.key)\t\(.value.description)\(if .value.vm then "  [vm]" else "" end)\(if (.value.mcp // []) | length > 0 then "  [mcp]" else "" end)\(if .value.linuxOnly then "  [linux]" else "" end)"' "$catalogue" |
    while IFS=$'\t' read -r name desc; do
      printf '  %-14s %s\n' "$name" "$desc"
    done
}

# --- lab mcp ---------------------------------------------------------------
# The configs themselves are rendered at build time (pkgs/mcp-config.nix), one
# directory per environment; this only picks a file and, with --write, merges it
# into the client's own config.

mcp_source() { # <env> <format> <store-paths?>
  case "$2" in
  canonical) [ "$3" = 1 ] && echo "$mcp_configs/$1/store.json" || echo "$mcp_configs/$1/canonical.json" ;;
  opencode) echo "$mcp_configs/$1/opencode.json" ;;
  codex) echo "$mcp_configs/$1/codex.toml" ;;
  esac
}

mcp_cmd() {
  local env client="claude" write="" force=0 store=0 dir="." fmt target src
  require_env "${1:-}"
  env="$1"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
    --client)
      client="${2:-}"
      shift 2
      ;;
    --write)
      write=1
      case "${2:-}" in
      "" | -*) shift ;;
      *)
        dir="$2"
        shift 2
        ;;
      esac
      ;;
    --force)
      force=1
      shift
      ;;
    --store-paths)
      store=1
      shift
      ;;
    *) die "unknown option for lab mcp: $1" ;;
    esac
  done

  case "$client" in
  claude | gemini | qwen | pi) fmt=canonical ;;
  opencode) fmt=opencode ;;
  codex) fmt=codex ;;
  *) die "unknown client '$client' (claude, opencode, codex, gemini, qwen, pi)" ;;
  esac

  src=$(mcp_source "$env" "$fmt" "$store")
  [ -f "$src" ] ||
    die "environment '$env' provides no MCP servers (see: lab list — entries marked [mcp])"

  if [ -z "$write" ]; then
    cat "$src"
    return
  fi

  case "$client" in
  claude) target="$dir/.mcp.json" ;;
  gemini) target="$dir/.gemini/settings.json" ;;
  qwen) target="$dir/.qwen/settings.json" ;;
  pi) target="$dir/.pi/mcp.json" ;;
  opencode) target="$dir/opencode.json" ;;
  codex) target="$HOME/.codex/config.toml" ;;
  esac
  mkdir -p "$(dirname "$target")"

  if [ "$fmt" = codex ]; then
    # TOML: append the tables, refusing to duplicate an existing one.
    if [ -f "$target" ]; then
      while read -r name; do
        if grep -q "^\[mcp_servers\.$name\]" "$target"; then
          [ "$force" = 1 ] ||
            die "[mcp_servers.$name] already in $target (use --force to append anyway)"
        fi
      done < <(jq -r --arg e "$env" '.[$e].mcp[]' "$catalogue")
      printf '\n' >>"$target"
    fi
    cat "$src" >>"$target"
  else
    local key merged
    [ "$fmt" = opencode ] && key=mcp || key=mcpServers
    if [ -f "$target" ]; then
      if [ "$force" != 1 ]; then
        while read -r name; do
          jq -e --arg k "$key" --arg n "$name" '.[$k][$n] // empty' "$target" >/dev/null 2>&1 &&
            die "server '$name' already in $target (use --force to replace it)"
        done < <(jq -r --arg e "$env" '.[$e].mcp[]' "$catalogue")
      fi
      merged=$(jq -s '.[0] * .[1]' "$target" "$src")
    else
      merged=$(cat "$src")
    fi
    printf '%s\n' "$merged" >"$target"
  fi
  printf 'lab: wrote %s MCP config for %s to %s\n' "$client" "$env" "$target"
}

case "${1:-}" in
"" | -h | --help | help)
  usage
  ;;

list | ls)
  list
  ;;

init)
  require_env "${2:-}"
  env="$2"
  dir="${3:-.}"
  template=$(jq -r --arg e "$env" '.[$e].template // empty' "$catalogue")
  [ -n "$template" ] || die "environment '$env' has no project template"
  mkdir -p "$dir"
  # `nix flake init` always writes into the current directory (unlike
  # `nix flake update`, it has no --flake), so run it from there.
  (cd "$dir" && nix flake init -t "$flake#$template")
  # Templates are written for one representative environment; point the
  # project's flake at the one that was asked for.
  if [ -f "$dir/flake.nix" ]; then
    sed -i.bak -E "s/shells\.[a-z0-9-]+;/shells.${env};/" "$dir/flake.nix" && rm -f "$dir/flake.nix.bak"
  fi
  # Hand the project its MCP servers too, generated from the catalogue rather
  # than shipped in the template (which would drift).
  if [ -f "$(mcp_source "$env" canonical 0)" ]; then
    mcp_cmd "$env" --client claude --write "$dir" >/dev/null
    mcp_cmd "$env" --client opencode --write "$dir" >/dev/null
    printf 'lab: wrote .mcp.json and opencode.json (MCP servers for %s)\n' "$env"
  fi
  printf 'lab: scaffolded %s in %s — next: cd %s && direnv allow   (or: nix develop)\n' "$env" "$dir" "$dir"
  ;;

vm)
  require_env "${2:-}"
  env="$2"
  shift 2
  jq -e --arg e "$env" '.[$e].vm' "$catalogue" >/dev/null 2>&1 ||
    die "environment '$env' has no VM runner (see: lab list — entries marked [vm])"
  exec nix run "$flake#lab-vm-$env" -- "$@"
  ;;

mcp)
  shift
  mcp_cmd "$@"
  ;;

update)
  exec nix flake update nix-labs --flake "${2:-.}"
  ;;

*)
  require_env "$1"
  env="$1"
  shift
  if [ "${1:-}" = "--" ]; then
    shift
    [ $# -gt 0 ] || die "nothing to run after --"
    exec nix develop "$flake#$env" -c "$@"
  fi
  [ $# -eq 0 ] || die "unexpected arguments: $* (use -- to run a command)"
  exec nix develop "$flake#$env"
  ;;
esac
