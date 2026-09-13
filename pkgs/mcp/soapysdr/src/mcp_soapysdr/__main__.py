"""MCP server exposing a SoapySDR radio (LimeSDR, RTL-SDR, HackRF, …).

Transport is stdio JSON-RPC, so **stdout belongs to the protocol**. SoapySDR's
C++ core and its driver modules write probe chatter straight to file descriptor
1, which would corrupt every message — so before anything else, fd 1 is pointed
at stderr and the real stdout is handed to Python as `sys.stdout` for the MCP
transport to use. Do not print() to stdout anywhere in this package.
"""

from __future__ import annotations

import io
import os
import sys


def _protect_stdout() -> None:
    real_stdout_fd = os.dup(1)
    os.dup2(2, 1)  # C-level writes to fd 1 now land on stderr
    sys.stdout = io.TextIOWrapper(
        io.FileIO(real_stdout_fd, "w", closefd=True),
        encoding="utf-8",
        line_buffering=True,
    )


_protect_stdout()

import json  # noqa: E402
from pathlib import Path  # noqa: E402
from typing import Annotated, Any  # noqa: E402

import numpy as np  # noqa: E402
from mcp.server.fastmcp import FastMCP  # noqa: E402
from mcp.server.fastmcp.utilities.types import Image  # noqa: E402
from pydantic import Field  # noqa: E402

from . import radio  # noqa: E402

mcp = FastMCP(
    "soapysdr",
    instructions=(
        "Controls a software-defined radio through SoapySDR. Start with list_devices, "
        "then probe_device to learn the legal sample rates, gains and antennas before "
        "tuning. psd and spectrogram return images you can look at; scan_band returns "
        "numbers. Frequencies and rates are in Hz unless a tool says otherwise."
    ),
)

# Captures are written under this directory unless a tool is given an absolute path.
WORKDIR = Path(os.environ.get("MCP_SOAPYSDR_WORKDIR", os.getcwd()))
MAX_SAMPLES = int(os.environ.get("MCP_SOAPYSDR_MAX_SAMPLES", "33554432"))  # 32 Mi ≈ 256 MB

Device = Annotated[
    str | None,
    Field(
        default=None,
        description='SoapySDR device string, e.g. "driver=lime" or "driver=rtlsdr,serial=1". Omit for the first device found.',
    ),
]
Gain = Annotated[
    float | None,
    Field(default=None, description="Overall RX gain in dB. Omit to use the device's AGC."),
]


def _resolve(path: str) -> Path:
    p = Path(path).expanduser()
    return p if p.is_absolute() else WORKDIR / p


def _plot_png(fig: Any) -> Image:
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=110, bbox_inches="tight")
    import matplotlib.pyplot as plt

    plt.close(fig)
    return Image(data=buf.getvalue(), format="png")


def _figure() -> Any:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    return plt


def _num_samples(sample_rate: float, seconds: float) -> int:
    n = int(sample_rate * seconds)
    if n > MAX_SAMPLES:
        raise radio.RadioError(
            f"{seconds} s at {sample_rate / 1e6:.3f} MS/s is {n} samples "
            f"(limit {MAX_SAMPLES}). Shorten the capture or lower the sample rate."
        )
    return max(1024, n)


@mcp.tool()
def list_devices(device: Device = None) -> list[dict[str, str]]:
    """List the SDRs SoapySDR can see, with the device strings to address them."""
    found = radio.enumerate_devices(device)
    if not found:
        return [
            {
                "error": "no devices found",
                "hint": "check the USB cable, that the nix-labs udev rules are installed "
                "(labs.enable on NixOS), and SOAPY_SDR_PLUGIN_PATH",
            }
        ]
    return found


@mcp.tool()
def probe_device(device: Device = None) -> dict[str, Any]:
    """Report a radio's driver, RX channels, tunable range, sample rates, gains and antennas."""
    return radio.describe(device)


@mcp.tool()
def capture_iq(
    center_freq_hz: Annotated[float, Field(description="Tuner centre frequency in Hz")],
    sample_rate_hz: Annotated[float, Field(description="Sample rate in Hz (see probe_device)")],
    seconds: Annotated[float, Field(gt=0, le=60, description="Capture length in seconds")] = 1.0,
    path: Annotated[
        str, Field(description="Output file, complex float32 interleaved (.cf32)")
    ] = "capture.cf32",
    device: Device = None,
    gain_db: Gain = None,
    antenna: Annotated[str | None, Field(default=None, description="RX antenna name")] = None,
) -> dict[str, Any]:
    """Record raw IQ to a .cf32 file (plus a .json sidecar) for later analysis."""
    cap = radio.capture(
        center_freq=center_freq_hz,
        sample_rate=sample_rate_hz,
        num_samples=_num_samples(sample_rate_hz, seconds),
        device=device,
        gain_db=gain_db,
        antenna=antenna,
    )
    out = _resolve(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    cap.samples.astype(np.complex64).tofile(out)
    meta = {
        "path": str(out),
        "format": "complex float32 (interleaved I,Q)",
        "samples": int(len(cap.samples)),
        "sample_rate_hz": cap.sample_rate,
        "center_freq_hz": cap.center_freq,
        "duration_s": round(cap.duration, 6),
        "bytes": out.stat().st_size,
        "device": cap.device,
    }
    out.with_suffix(out.suffix + ".json").write_text(json.dumps(meta, indent=2))
    return meta


# structured_output=False: the result is an image plus a JSON blob, which is
# content, not a schema-able return value.
@mcp.tool(structured_output=False)
def psd(
    center_freq_hz: Annotated[float, Field(description="Tuner centre frequency in Hz")],
    sample_rate_hz: Annotated[float, Field(description="Sample rate in Hz")],
    seconds: Annotated[float, Field(gt=0, le=10)] = 0.25,
    device: Device = None,
    gain_db: Gain = None,
    nfft: Annotated[int, Field(ge=256, le=65536)] = 4096,
) -> list:
    """Capture briefly and return the power spectrum as a PNG plus the strongest peaks."""
    cap = radio.capture(
        center_freq=center_freq_hz,
        sample_rate=sample_rate_hz,
        num_samples=_num_samples(sample_rate_hz, seconds),
        device=device,
        gain_db=gain_db,
    )
    freqs, power = radio.welch_psd(cap, nfft=nfft)
    plt = _figure()
    fig, ax = plt.subplots(figsize=(9, 4))
    ax.plot(freqs / 1e6, power, linewidth=0.8)
    ax.set_xlabel("MHz")
    ax.set_ylabel("dBFS/Hz")
    ax.set_title(f"PSD @ {center_freq_hz / 1e6:.4f} MHz, {sample_rate_hz / 1e6:.3f} MS/s")
    ax.grid(alpha=0.3)
    found = radio.peaks(freqs, power)
    return [
        _plot_png(fig),
        json.dumps(
            {
                "noise_floor_db": round(float(np.median(power)), 2),
                "peaks": [
                    {k: round(v, 2) if k != "frequency_hz" else round(v, 1) for k, v in p.items()}
                    for p in found
                ],
            },
            indent=2,
        ),
    ]


@mcp.tool(structured_output=False)
def spectrogram(
    center_freq_hz: Annotated[float, Field(description="Tuner centre frequency in Hz")],
    sample_rate_hz: Annotated[float, Field(description="Sample rate in Hz")],
    seconds: Annotated[float, Field(gt=0, le=10)] = 1.0,
    device: Device = None,
    gain_db: Gain = None,
    nfft: Annotated[int, Field(ge=128, le=8192)] = 1024,
) -> Image:
    """Capture and return a waterfall (time vs frequency) PNG — bursts and hopping show up here."""
    from scipy import signal

    cap = radio.capture(
        center_freq=center_freq_hz,
        sample_rate=sample_rate_hz,
        num_samples=_num_samples(sample_rate_hz, seconds),
        device=device,
        gain_db=gain_db,
    )
    freqs, times, sxx = signal.spectrogram(
        cap.samples,
        fs=cap.sample_rate,
        nperseg=nfft,
        noverlap=nfft // 4,
        return_onesided=False,
        detrend=False,
        mode="psd",
    )
    order = np.argsort(np.fft.fftshift(freqs))
    freqs = np.fft.fftshift(freqs) + cap.center_freq
    sxx = 10.0 * np.log10(np.maximum(sxx[order, :], 1e-20))

    plt = _figure()
    fig, ax = plt.subplots(figsize=(9, 5))
    mesh = ax.pcolormesh(freqs / 1e6, times, sxx.T, shading="auto", cmap="viridis")
    fig.colorbar(mesh, ax=ax, label="dBFS/Hz")
    ax.set_xlabel("MHz")
    ax.set_ylabel("seconds")
    ax.set_title(f"Spectrogram @ {center_freq_hz / 1e6:.4f} MHz")
    return _plot_png(fig)


@mcp.tool()
def scan_band(
    start_hz: Annotated[float, Field(description="Lower edge of the span in Hz")],
    stop_hz: Annotated[float, Field(description="Upper edge of the span in Hz")],
    sample_rate_hz: Annotated[float, Field(description="Sample rate per tuner step in Hz")] = 2.4e6,
    device: Device = None,
    gain_db: Gain = None,
    top: Annotated[int, Field(ge=1, le=50, description="How many peaks to report")] = 10,
) -> dict[str, Any]:
    """Sweep the tuner across a span and report the strongest signals found."""
    rows = radio.scan(
        start_hz=start_hz,
        stop_hz=stop_hz,
        sample_rate=sample_rate_hz,
        device=device,
        gain_db=gain_db,
    )
    freqs = np.array([r["frequency_hz"] for r in rows])
    power = np.array([r["power_db"] for r in rows])
    return {
        "span_mhz": [start_hz / 1e6, stop_hz / 1e6],
        "bins": len(rows),
        "noise_floor_db": round(float(np.median(power)), 2),
        "peaks": [
            {
                "frequency_mhz": round(p["frequency_hz"] / 1e6, 4),
                "power_db": round(p["power_db"], 2),
                "snr_db": round(p["snr_db"], 2),
            }
            for p in radio.peaks(freqs, power, count=top)
        ],
    }


@mcp.tool()
def demod_fm(
    center_freq_hz: Annotated[float, Field(description="Station frequency in Hz, e.g. 100.1e6")],
    seconds: Annotated[float, Field(gt=0, le=60)] = 5.0,
    path: Annotated[str, Field(description="Output WAV file")] = "audio.wav",
    sample_rate_hz: Annotated[float, Field(description="Sample rate in Hz")] = 2.4e6,
    device: Device = None,
    gain_db: Gain = None,
) -> dict[str, Any]:
    """Demodulate narrow/wide FM to a mono WAV file (broadcast radio, NFM voice)."""
    cap = radio.capture(
        center_freq=center_freq_hz,
        sample_rate=sample_rate_hz,
        num_samples=_num_samples(sample_rate_hz, seconds),
        device=device,
        gain_db=gain_db,
    )
    audio, rate = radio.demod_fm(cap)
    out = _resolve(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    radio.write_wav(out, audio, rate)
    return {
        "path": str(out),
        "audio_rate_hz": rate,
        "duration_s": round(len(audio) / rate, 3),
        "center_freq_hz": center_freq_hz,
    }


@mcp.tool(structured_output=False)
def analyse_iq_file(
    path: Annotated[str, Field(description="A .cf32 file written by capture_iq")],
    nfft: Annotated[int, Field(ge=256, le=65536)] = 4096,
) -> list:
    """Plot the spectrum of a previously captured IQ file — no radio needed."""
    src = _resolve(path)
    meta_path = src.with_suffix(src.suffix + ".json")
    if not meta_path.exists():
        raise radio.RadioError(f"{meta_path} is missing — capture_iq writes it alongside the samples")
    meta = json.loads(meta_path.read_text())
    cap = radio.Capture(
        samples=np.fromfile(src, dtype=np.complex64),
        sample_rate=float(meta["sample_rate_hz"]),
        center_freq=float(meta["center_freq_hz"]),
    )
    freqs, power = radio.welch_psd(cap, nfft=nfft)
    plt = _figure()
    fig, ax = plt.subplots(figsize=(9, 4))
    ax.plot(freqs / 1e6, power, linewidth=0.8)
    ax.set_xlabel("MHz")
    ax.set_ylabel("dBFS/Hz")
    ax.set_title(f"{src.name}: {cap.duration:.3f} s @ {cap.sample_rate / 1e6:.3f} MS/s")
    ax.grid(alpha=0.3)
    return [_plot_png(fig), json.dumps({"peaks": radio.peaks(freqs, power)}, indent=2)]


def main() -> None:
    """Entry point: serve MCP over stdio."""
    # Route SoapySDR's own logging to stderr as well (it uses its own sink).
    try:
        soapy = radio.soapy()
        soapy.registerLogHandler(lambda level, message: print(f"[soapy:{level}] {message}", file=sys.stderr))
    except Exception:  # noqa: BLE001 — a missing SoapySDR must not stop tools/list
        print("mcp-soapysdr: SoapySDR unavailable; tools will report errors when called", file=sys.stderr)
    mcp.run()


if __name__ == "__main__":
    main()
