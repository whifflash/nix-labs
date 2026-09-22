#!/usr/bin/env python3
"""srdecode — protocol RE helper for sigrok .sr captures.

The sigrok MCP server's render_waveform turns captures into ASCII art and dies
on the multi-million-sample captures a 5 MHz+ analyzer produces; the UART
decoder needs the baud rate handed to it. This tool fills the gap between
"capture" and "understand": it measures the baud, decodes UART with stop-bit
validation, segments traffic into frames across idle gaps, and diffs two
captures so a button press shows up as "these frames, minus those".

Usage:
  srdecode CAPTURE.sr [--channels D6,D7] [--baud N] [--gap-ms 2]
          [--diff OTHER.sr] [--bits 8] [--verbose]

Channels are the probe names from the capture's metadata (D0..Dn); default is
every enabled probe. Baud is auto-estimated per channel from the shortest
run in active regions unless --baud forces it. 8N1 only — that covers the
desk controllers, motor drivers and badge readers these captures come from.
"""

import argparse
import re
import sys
import zipfile
from collections import defaultdict

import numpy as np

COMMON_BAUDS = [
    300, 600, 1200, 2400, 4800, 9600, 14400, 19200, 28800,
    38400, 57600, 76800, 115200, 230400, 460800, 921200,
]


def load_capture(path):
    """Return (samplerate, unitsize, {probe_name: bit_index}, uint8 array)."""
    z = zipfile.ZipFile(path)
    raw = b"".join(z.read(n) for n in sorted(
        n for n in z.namelist() if re.fullmatch(r"logic-\d+-\d+", n)))
    meta = z.read("metadata").decode()

    samplerate = None
    unitsize = 1
    probes = {}  # name -> channel index
    for line in meta.splitlines():
        if line.startswith("samplerate"):
            v = line.split("=", 1)[1].strip().replace(" ", "")
            for suf, mult in (("MHz", 1e6), ("kHz", 1e3), ("Hz", 1)):
                if v.endswith(suf):
                    samplerate = int(float(v[: -len(suf)]) * mult)
                    break
        elif line.startswith("unitsize"):
            unitsize = int(line.split("=", 1)[1])
        elif line.startswith("probe"):
            idx, name = line.split("=", 1)
            probes[name.strip()] = int(idx[len("probe"):]) - 1
    if samplerate is None:
        sys.exit(f"{path}: no samplerate in metadata")
    n = len(raw) // unitsize
    arr = np.frombuffer(raw, dtype=np.uint8, count=n * unitsize)
    return samplerate, unitsize, probes, arr


def channel_levels(arr, unitsize, ch):
    """Level per sample (uint8 0/1) for channel index ch."""
    n = len(arr) // unitsize
    cols = arr[: n * unitsize].reshape(n, unitsize)
    return (cols[:, ch // 8] >> (ch % 8)) & 1


def transitions(levels):
    """Edges as (sample, level_after); empty if the line never changes."""
    d = np.diff(levels.astype(np.int8))
    idx = np.flatnonzero(d)
    return list(zip((idx + 1).tolist(), levels[idx + 1].tolist()))


def baud_candidates(levels, samplerate):
    """Bauds implied by the shortest recurring runs, shortest-first.

    A single sub-bit glitch makes the absolute shortest run a lie, so runs are
    bucketed (±2%) and only buckets with >= 2 members count; jitter then
    cannot suppress the real 1-bit run the way a lone outlier sets a half-bit
    candidate. Callers validate candidates by decoding (stop-bit score)."""
    tr = transitions(levels)
    if not tr:
        return []
    edges = [0] + [s for s, _ in tr] + [len(levels)]
    runs = np.diff(edges)
    runs = runs[runs > 0]
    buckets = defaultdict(int)
    for r in runs:
        buckets[max(1, round(r * 1.02 / 4) * 4)] += 1  # 4-sample jitter window
    seen, out = set(), []
    for r in sorted(buckets):
        if buckets[r] < 2:
            continue
        baud = min(COMMON_BAUDS, key=lambda b: abs(b - samplerate / r) / b)
        if baud not in seen:
            seen.add(baud)
            out.append(baud)
    return out


def level_at(tl, pos):
    """Binary-search the transition timeline for the level at sample pos."""
    lo, hi = 0, len(tl) - 1
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if tl[mid][0] <= pos:
            lo = mid
        else:
            hi = mid - 1
    return tl[lo][1]


def uart_decode(trans, n, samplerate, baud):
    """8N1 decode from an edge list. Returns [(t_start_s, byte, stop_ok)]."""
    idle = 1  # UART idles high on every device we care about
    bit_t = samplerate / baud
    res = []
    if not trans:
        return res
    # Level before the first transition is the inverse of trans[0]'s level.
    first = (0, trans[0][1]) if trans[0][0] == 0 else (0, 1 - trans[0][1])
    tl = [first] + list(trans)
    j = 1
    while j < len(tl):
        t_s, lvl = tl[j]
        if tl[j - 1][1] == idle and lvl != idle:
            t0 = t_s + bit_t / 2
            if level_at(tl, t0) == idle:  # glitch, not a start bit
                j += 1
                continue
            byte = 0
            for b in range(8):
                if level_at(tl, t0 + (b + 1) * bit_t) == 1:
                    byte |= 1 << b
            stop_ok = level_at(tl, t0 + 9 * bit_t) == idle
            res.append((t_s / samplerate, byte, stop_ok))
            nxt = t_s + 9.5 * bit_t  # skip past our own data edges
            while j < len(tl) and tl[j][0] < nxt:
                j += 1
        else:
            j += 1
    return res


def frames_from_bytes(bytelist, gap_s):
    frames, cur, t0, last = [], [], None, None
    for t, b, _ok in bytelist:
        if last is not None and t - last > gap_s:
            frames.append((t0, cur))
            cur = []
        if not cur:
            t0 = t
        cur.append(b)
        last = t
    if cur:
        frames.append((t0, cur))
    return frames


def checksum_note(f):
    """Name the checksum rule if a common one fits (helps frame RE)."""
    rules = {
        "sum(b[1:-1])%256": lambda f: sum(f[1:-1]) & 0xFF,
        "sum(b[:-1])%256": lambda f: sum(f[:-1]) & 0xFF,
        "xor(b[:-1])": lambda f: __import__("functools").reduce(
            lambda a, c: a ^ c, f[:-1], 0),
        "(0x100-sum(b[:-1]))%256": lambda f: (0x100 - sum(f[:-1])) & 0xFF,
    }
    if len(f) < 3:
        return ""
    for name, fn in rules.items():
        if fn(f) == f[-1]:
            return f"   [checksum={name}]"
    return ""


def analyze(path, channels_arg, baud_arg, gap_ms, verbose=False):
    samplerate, unitsize, probes, arr = load_capture(path)
    names = (
        [c.strip() for c in channels_arg.split(",")]
        if channels_arg else sorted(probes, key=probes.get)
    )
    per_channel = {}
    print(f"# {path}: {len(arr) // unitsize:,} samples @"
          f" {samplerate / 1e6} MHz = {len(arr) / unitsize / samplerate:.2f}s")
    for name in names:
        if name not in probes:
            sys.exit(f"{path}: no probe '{name}' (have: {', '.join(probes)})")
        levels = channel_levels(arr, unitsize, probes[name])
        tr = transitions(levels)
        ch_frames = []
        if tr:
            n_levels = len(levels)
            if baud_arg:
                bauds = [baud_arg]
            else:
                bauds = baud_candidates(levels, samplerate)
                if not bauds:
                    print(f"## {name}: transitions but no recurring run length")
                    continue
            # Pick the fastest candidate whose decode is actually UART:
            # >=90% clean stop bits. A half-bit glitch baud decodes garbage
            # stop bits, so it eliminates itself.
            baud, by = None, []
            for cand in bauds:
                decoded = uart_decode(tr, n_levels, samplerate, cand)
                clean = sum(1 for _, _, ok in decoded if ok)
                if decoded and clean / len(decoded) >= 0.9:
                    baud, by = cand, decoded
                    break
            if baud is None:  # nothing validated — show the best attempt
                baud, by = bauds[0], uart_decode(tr, n_levels, samplerate, bauds[0])
            clean = sum(1 for _, _, ok in by if ok)
            ch_frames = frames_from_bytes(by, gap_ms / 1000.0)
            print(f"## {name}: {len(tr)} transitions, {len(by)} bytes"
                  f" ({clean} clean stop bits) @ {baud} baud")
        else:
            print(f"## {name}: no transitions (idle {levels[0]})")
            continue
        uniq = defaultdict(list)
        for t, f in ch_frames:
            uniq[tuple(f)].append(t)
        for payload, times in sorted(uniq.items(), key=lambda kv: -len(kv[1])):
            f = list(payload)
            print(f"  {len(times):5d}x  {(times[-1] - times[0]):7.2f}s span"
                  f"  first@{times[0]:7.2f}s  "
                  + " ".join(f"{x:02X}" for x in f) + checksum_note(f))
        per_channel[name] = {tuple(k): v for k, v in uniq.items()}
        if verbose:
            for t, f in ch_frames:
                print(f"    {t:9.4f}s  " + " ".join(f"{x:02X}" for x in f))
    return per_channel


def diff(main, other, main_path, other_path):
    for ch in main:
        if ch not in other:
            continue
        a, b = main[ch], other[ch]
        only_a = {k: v for k, v in a.items() if k not in b}
        only_b = {k: v for k, v in b.items() if k not in a}
        if not only_a and not only_b:
            print(f"## {ch}: identical frame sets")
            continue
        for tag, d, p in (("only in " + main_path, only_a, main_path),
                          ("only in " + other_path, only_b, other_path)):
            for payload, times in sorted(d.items(), key=lambda kv: -len(kv[1])):
                f = list(payload)
                print(f"  {ch} {tag}: {len(times):4d}x  "
                      f"first@{times[0]:7.2f}s  "
                      + " ".join(f"{x:02X}" for x in f) + checksum_note(f))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("capture", help=".sr file to analyze")
    ap.add_argument("--channels", help="probe names, comma-separated (default: all)")
    ap.add_argument("--baud", type=int, help="force baud rate (default: estimate)")
    ap.add_argument("--gap-ms", type=float, default=2.0,
                    help="inter-frame gap in ms (default 2)")
    ap.add_argument("--diff", metavar="BASELINE.sr",
                    help="also analyze this file and print frame-set differences")
    ap.add_argument("--verbose", action="store_true", help="print every frame")
    args = ap.parse_args()

    main_frames = analyze(args.capture, args.channels, args.baud,
                          args.gap_ms, args.verbose)
    if args.diff:
        print(f"\n# diff vs {args.diff}")
        base_frames = analyze(args.diff, args.channels, args.baud,
                              args.gap_ms, False)
        diff(main_frames, base_frames, args.capture, args.diff)


if __name__ == "__main__":
    main()
