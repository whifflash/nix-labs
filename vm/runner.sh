# lab-vm-@LAB@ — boot the nix-labs "@LAB@" guest and redirect host USB devices
# into it. Substituted at build time: @LAB@ @VM_RUN@ @USB_DEFAULT@ @SSH_PORT@.
#
# USB path: for every device one QEMU `usb-redir` device listens on a loopback
# chardev socket; `usbredirect --device VID:PID --to 127.0.0.1:PORT` (host side)
# claims the device and streams it in. Re-run automatically when the device is
# unplugged/replugged. On macOS a claim that fails with a permission error is
# retried with sudo (Apple's kernel owns the device otherwise).

lab="@LAB@"
vm_run="@VM_RUN@"
ssh_port="@SSH_PORT@"
default_usb=(@USB_DEFAULT@)

usb=()
use_defaults=1
share="${LAB_SHARE:-$HOME/lab}"
kbd="${LAB_KBD:-us}"
qemu_extra=()

usage() {
  cat <<EOF
Usage: lab-vm-$lab [--usb VID:PID]… [--no-usb] [--share DIR] [--kbd LAYOUT] [-- <qemu args>]

  --usb VID:PID   redirect this host USB device (repeatable; replaces the defaults:
                  ${default_usb[*]:-none})
  --no-usb        start without USB redirection
  --share DIR     host directory shown as /home/lab/work in the guest (default: \$HOME/lab)
  --kbd LAYOUT    XKB layout for the guest kiosk (default: us; env LAB_KBD)
  --              remaining arguments are passed to QEMU

Inside: user "lab", password "lab", passwordless sudo.  ssh -p $ssh_port lab@127.0.0.1
State (disk image, logs): \${XDG_STATE_HOME:-~/.local/state}/nix-labs/vm/$lab
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
  --usb)
    [ -n "${2:-}" ] || {
      echo "--usb needs VID:PID" >&2
      exit 2
    }
    usb+=("$2")
    use_defaults=0
    shift 2
    ;;
  --no-usb)
    use_defaults=0
    shift
    ;;
  --share)
    share="$2"
    shift 2
    ;;
  --kbd)
    kbd="$2"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --)
    shift
    qemu_extra=("$@")
    break
    ;;
  *)
    echo "unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
done
if [ "$use_defaults" = 1 ]; then usb=("${default_usb[@]}"); fi

state="${XDG_STATE_HOME:-$HOME/.local/state}/nix-labs/vm/$lab"
mkdir -p "$state" "$share"
cd "$state"

port_free() {
  ! (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}
port_open() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

# One usb-redir slot per device. Ports are picked at runtime so two lab VMs can
# coexist; the guest only carries the xHCI controller (vm/guest.nix).
qemu_opts=("-fw_cfg" "name=opt/nix-labs/xkb_layout,string=$kbd")
ports=()
next_port=45100
i=0
for _ in "${usb[@]}"; do
  while ! port_free "$next_port"; do next_port=$((next_port + 1)); done
  ports+=("$next_port")
  qemu_opts+=(
    "-chardev" "socket,id=usbr$i,host=127.0.0.1,port=$next_port,server=on,wait=off"
    "-device" "usb-redir,chardev=usbr$i,bus=xhci.0,id=usbredir$i"
  )
  next_port=$((next_port + 1))
  i=$((i + 1))
done

# The qemu-vm run script appends $QEMU_OPTS (word-split) and honours the share
# source we baked as "${LAB_SHARE:-$HOME/lab}".
export LAB_SHARE="$share"
export QEMU_OPTS="${QEMU_OPTS:-} ${qemu_opts[*]}"

echo "lab-vm-$lab: share $share -> /home/lab/work | ssh -p $ssh_port lab@127.0.0.1 (password: lab) | state: $state"
"$vm_run" "${qemu_extra[@]}" &
qemu_pid=$!

redir_pids=()
cleanup() {
  for p in "${redir_pids[@]}"; do kill "$p" 2>/dev/null || true; done
  kill "$qemu_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Keep one device attached to one slot for as long as QEMU runs.
redirect() {
  local dev="$1" port="$2" log="$state/usbredirect-$1.log" waited=0
  local -a sudo_prefix=()
  while kill -0 "$qemu_pid" 2>/dev/null; do
    if "${sudo_prefix[@]}" usbredirect --device "$dev" --to "127.0.0.1:$port" >"$log" 2>&1; then
      echo "lab-vm-$lab: $dev detached" >&2
      waited=0
    elif grep -qiE 'access|permission|not permitted' "$log" && [ "$(uname -s)" = Darwin ] && [ "${#sudo_prefix[@]}" -eq 0 ]; then
      echo "lab-vm-$lab: no permission to claim $dev — retrying with sudo (macOS needs root to detach a device from the system)" >&2
      sudo -v && sudo_prefix=(sudo)
      continue
    elif [ "$waited" = 0 ]; then
      echo "lab-vm-$lab: waiting for USB device $dev (plug it in; log: $log)" >&2
      waited=1
    fi
    sleep 2
  done
}

for idx in "${!usb[@]}"; do
  port="${ports[$idx]}"
  for _ in $(seq 1 120); do
    port_open "$port" && break
    kill -0 "$qemu_pid" 2>/dev/null || {
      echo "lab-vm-$lab: QEMU exited before the usb-redir socket came up" >&2
      exit 1
    }
    sleep 0.5
  done
  redirect "${usb[$idx]}" "$port" &
  redir_pids+=("$!")
done

wait "$qemu_pid"
