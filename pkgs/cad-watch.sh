# cad-watch — edit a model in your own editor, see it update.
#
# Re-runs the script whenever it changes and leaves f3d watching the exported
# file, which reloads it by itself. Deliberately editor-agnostic: nothing here
# knows or cares what you type in.
# Substituted at build time: @PYTHON@ @F3D@ @WATCHEXEC@ @RUNNER@

usage() {
  cat <<EOF
Usage: cad-watch [options] <model.py>

  --format FMT   glb (default), step, stl, 3mf or brep — what to hand the viewer.
                 glb is fastest to reload; step keeps the exact surfaces.
  --out DIR      where to write the preview (default: build/)
  --name NAME    base filename (default: preview)
  --no-viewer    rebuild on change but do not open f3d (useful over ssh)

The script should assign its solid to \`result\`, or pass it to show_object().
Ctrl-C stops both the watcher and the viewer.
EOF
}

format=glb
out=build
name=preview
viewer=1

while [ $# -gt 0 ]; do
  case "$1" in
  --format)
    format="${2:-}"
    shift 2
    ;;
  --out)
    out="${2:-}"
    shift 2
    ;;
  --name)
    name="${2:-}"
    shift 2
    ;;
  --no-viewer)
    viewer=0
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  -*)
    echo "cad-watch: unknown option $1" >&2
    usage >&2
    exit 2
    ;;
  *)
    model="$1"
    shift
    ;;
  esac
done

if [ -z "${model:-}" ]; then
  usage >&2
  exit 2
fi
if [ ! -f "$model" ]; then
  echo "cad-watch: $model does not exist" >&2
  exit 1
fi

mkdir -p "$out"
target="$out/$name.$format"

build() {
  if @PYTHON@ @RUNNER@ "$model" "$out" "$name" "$format"; then
    printf '\033[32m[cad-watch]\033[0m %s\n' "$(date +%H:%M:%S) → $target"
  else
    printf '\033[31m[cad-watch]\033[0m build failed — the viewer keeps the last good model\n' >&2
  fi
}

build

if [ "$viewer" = 1 ]; then
  if [ ! -f "$target" ]; then
    echo "cad-watch: nothing to show yet; fix the script and rerun" >&2
    exit 1
  fi
  # f3d reloads the file itself when its mtime changes.
  @F3D@ --watch --up "+Z" --grid --ambient-occlusion "$target" &
  viewer_pid=$!
  # shellcheck disable=SC2064  # expand the pid now, not at trap time
  trap "kill $viewer_pid 2>/dev/null || true" EXIT INT TERM
fi

echo "cad-watch: watching $model (Ctrl-C to stop)"
@WATCHEXEC@ --quiet --no-vcs-ignore --watch "$model" --debounce 200ms -- \
  @PYTHON@ @RUNNER@ "$model" "$out" "$name" "$format"
