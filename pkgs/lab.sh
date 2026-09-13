# lab — enter, list, scaffold and virtualise nix-labs environments.
# Substituted at build time: @CATALOGUE@ (json), @FLAKE@ (default flake ref).

flake="${LAB_FLAKE:-@FLAKE@}"
catalogue="@CATALOGUE@"

usage() {
  cat <<EOF
Usage:
  lab list                       environments in the nix-labs catalogue
  lab <env> [-- cmd [args…]]     enter the environment (or run cmd inside it)
  lab init <env> [dir]           scaffold a project pinned to <env> (nix flake init -t)
  lab vm <env> [runner args…]    run the QEMU fallback VM for <env> (see: lab vm <env> --help)
  lab update [dir]               re-pin a project's nix-labs input (nix flake update nix-labs)

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
    | "\(.key)\t\(.value.description)\(if .value.vm then "  [vm]" else "" end)\(if .value.linuxOnly then "  [linux]" else "" end)"' "$catalogue" |
    while IFS=$'\t' read -r name desc; do
      printf '  %-14s %s\n' "$name" "$desc"
    done
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
