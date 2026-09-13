"""SoapySDR access: device handling, IQ capture and the DSP the tools expose.

Kept free of MCP concepts so it can be exercised from a plain Python REPL.
"""

from __future__ import annotations

import math
import time
import wave
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import numpy as np

# SoapySDR is imported lazily: the module pulls in the C++ library and probes
# for driver modules, which is slow and noisy, and the server must be able to
# start (and answer tools/list) on a machine with no radio attached.
_soapy: Any = None


def soapy() -> Any:
    global _soapy
    if _soapy is None:
        import SoapySDR  # noqa: N813  (upstream's capitalisation)

        _soapy = SoapySDR
    return _soapy


class RadioError(RuntimeError):
    """A device could not be opened, tuned or read — reported to the model as text."""


def _kwargs(device: str | None) -> dict[str, str]:
    """Parse a Soapy device string ("driver=lime,serial=0009…") into kwargs."""
    if not device:
        return {}
    out: dict[str, str] = {}
    for part in device.split(","):
        part = part.strip()
        if not part:
            continue
        if "=" not in part:
            raise RadioError(f"device argument {part!r} is not key=value (e.g. driver=lime)")
        key, value = part.split("=", 1)
        out[key.strip()] = value.strip()
    return out


def enumerate_devices(device: str | None = None) -> list[dict[str, str]]:
    results = soapy().Device.enumerate(_kwargs(device))
    return [{str(k): str(v) for k, v in r.items()} for r in results]


@dataclass
class Capture:
    """One block of complex samples plus the settings it was taken with."""

    samples: np.ndarray
    sample_rate: float
    center_freq: float
    device: dict[str, str] = field(default_factory=dict)

    @property
    def duration(self) -> float:
        return len(self.samples) / self.sample_rate


def _open(device: str | None) -> Any:
    try:
        return soapy().Device(_kwargs(device))
    except Exception as exc:  # SoapySDR raises bare RuntimeError
        found = enumerate_devices()
        hint = (
            "no SoapySDR device found — check the cable, the udev rules "
            "(nix-labs `labs.enable`) and SOAPY_SDR_PLUGIN_PATH"
            if not found
            else f"available: {found}"
        )
        raise RadioError(f"could not open device {device or '(default)'}: {exc}. {hint}") from exc


def describe(device: str | None = None) -> dict[str, Any]:
    """Everything worth knowing before tuning: rates, ranges, gains, antennas."""
    sdr = _open(device)
    rx = soapy().SOAPY_SDR_RX

    def _ranges(items: Any) -> list[dict[str, float]]:
        out = []
        for r in items:
            entry = {"min": r.minimum(), "max": r.maximum()}
            if r.step():
                entry["step"] = r.step()
            out.append(entry)
        return out

    channels = []
    for ch in range(sdr.getNumChannels(rx)):
        channels.append(
            {
                "channel": ch,
                "antennas": list(sdr.listAntennas(rx, ch)),
                "antenna": sdr.getAntenna(rx, ch),
                "sample_rates_hz": _ranges(sdr.getSampleRateRange(rx, ch)),
                "frequency_hz": _ranges(sdr.getFrequencyRange(rx, ch)),
                "bandwidth_hz": _ranges(sdr.getBandwidthRange(rx, ch)),
                "gains": {
                    name: {
                        "min": sdr.getGainRange(rx, ch, name).minimum(),
                        "max": sdr.getGainRange(rx, ch, name).maximum(),
                    }
                    for name in sdr.listGains(rx, ch)
                },
                "overall_gain_db": {
                    "min": sdr.getGainRange(rx, ch).minimum(),
                    "max": sdr.getGainRange(rx, ch).maximum(),
                },
                "has_agc": sdr.hasGainMode(rx, ch),
            }
        )

    return {
        "driver": sdr.getDriverKey(),
        "hardware": sdr.getHardwareKey(),
        "hardware_info": {str(k): str(v) for k, v in sdr.getHardwareInfo().items()},
        "rx_channels": channels,
    }


def capture(
    *,
    center_freq: float,
    sample_rate: float,
    num_samples: int,
    device: str | None = None,
    gain_db: float | None = None,
    antenna: str | None = None,
    bandwidth: float | None = None,
    channel: int = 0,
    settle: float = 0.1,
) -> Capture:
    """Tune and read `num_samples` complex samples from the RX stream."""
    if num_samples <= 0:
        raise RadioError("num_samples must be positive")
    if num_samples > 64_000_000:
        raise RadioError(
            f"{num_samples} samples is {num_samples * 8 / 1e9:.1f} GB in memory — "
            "capture to a file in chunks instead (capture_iq with a longer duration "
            "is still bounded by max_samples)"
        )

    sdr = _open(device)
    rx = soapy().SOAPY_SDR_RX
    sdr.setSampleRate(rx, channel, sample_rate)
    sdr.setFrequency(rx, channel, center_freq)
    if bandwidth is not None:
        sdr.setBandwidth(rx, channel, bandwidth)
    if antenna is not None:
        sdr.setAntenna(rx, channel, antenna)
    if gain_db is None:
        if sdr.hasGainMode(rx, channel):
            sdr.setGainMode(rx, channel, True)  # AGC
    else:
        if sdr.hasGainMode(rx, channel):
            sdr.setGainMode(rx, channel, False)
        sdr.setGain(rx, channel, gain_db)

    stream = sdr.setupStream(rx, soapy().SOAPY_SDR_CF32, [channel])
    try:
        sdr.activateStream(stream)
        # Let the PLL and AGC settle, then throw the transient away.
        time.sleep(settle)
        mtu = max(1024, sdr.getStreamMTU(stream))
        buf = np.empty(mtu, dtype=np.complex64)
        out = np.empty(num_samples, dtype=np.complex64)
        filled = 0
        deadline = time.monotonic() + 10.0 + 4.0 * num_samples / sample_rate
        while filled < num_samples:
            if time.monotonic() > deadline:
                raise RadioError(
                    f"timed out after {filled} of {num_samples} samples — "
                    "the device stopped streaming (USB 3 port? sample rate too high?)"
                )
            sr = sdr.readStream(stream, [buf], min(mtu, num_samples - filled), timeoutUs=2_000_000)
            if sr.ret > 0:
                out[filled : filled + sr.ret] = buf[: sr.ret]
                filled += sr.ret
            elif sr.ret == soapy().SOAPY_SDR_TIMEOUT:
                continue
            elif sr.ret == soapy().SOAPY_SDR_OVERFLOW:
                continue  # dropped samples; fine for spectra, noted by the caller
            else:
                raise RadioError(f"readStream failed: {soapy().errToStr(sr.ret)} ({sr.ret})")
    finally:
        try:
            sdr.deactivateStream(stream)
            sdr.closeStream(stream)
        except Exception:  # noqa: BLE001 — teardown must not mask the real error
            pass

    return Capture(
        samples=out,
        sample_rate=sample_rate,
        center_freq=center_freq,
        device={"requested": device or "(default)", "driver": sdr.getDriverKey()},
    )


def welch_psd(cap: Capture, nfft: int = 4096) -> tuple[np.ndarray, np.ndarray]:
    """Power spectral density in dBFS against absolute frequency in Hz."""
    from scipy import signal

    nfft = min(nfft, len(cap.samples))
    freqs, psd = signal.welch(
        cap.samples,
        fs=cap.sample_rate,
        nperseg=nfft,
        return_onesided=False,
        detrend=False,
        scaling="density",
    )
    freqs = np.fft.fftshift(freqs) + cap.center_freq
    psd = np.fft.fftshift(psd)
    return freqs, 10.0 * np.log10(np.maximum(psd, 1e-20))


def peaks(freqs: np.ndarray, power_db: np.ndarray, count: int = 5, min_db: float = 6.0) -> list[dict[str, float]]:
    """The strongest signals above the noise floor — what a model actually wants."""
    floor = float(np.median(power_db))
    order = np.argsort(power_db)[::-1]
    found: list[dict[str, float]] = []
    guard = max(1, len(freqs) // 200)
    for idx in order:
        if len(found) >= count:
            break
        if power_db[idx] - floor < min_db:
            break
        if any(abs(float(freqs[idx]) - f["frequency_hz"]) < guard * abs(freqs[1] - freqs[0]) for f in found):
            continue
        found.append(
            {
                "frequency_hz": float(freqs[idx]),
                "power_db": float(power_db[idx]),
                "snr_db": float(power_db[idx] - floor),
            }
        )
    return found


def scan(
    *,
    start_hz: float,
    stop_hz: float,
    sample_rate: float,
    device: str | None = None,
    gain_db: float | None = None,
    dwell_samples: int = 262_144,
    bins: int = 1024,
) -> list[dict[str, float]]:
    """Step the tuner across a span and report power per step (rtl_power-style)."""
    if stop_hz <= start_hz:
        raise RadioError("stop_hz must be greater than start_hz")
    span = stop_hz - start_hz
    # Use the middle 80% of each capture: the band edges are filter roll-off.
    usable = sample_rate * 0.8
    steps = max(1, math.ceil(span / usable))
    if steps > 200:
        raise RadioError(
            f"{span / 1e6:.1f} MHz at {sample_rate / 1e6:.1f} MS/s needs {steps} tuner steps — "
            "raise sample_rate or narrow the span"
        )

    rows: list[dict[str, float]] = []
    for i in range(steps):
        center = start_hz + usable * (i + 0.5)
        cap = capture(
            center_freq=center,
            sample_rate=sample_rate,
            num_samples=dwell_samples,
            device=device,
            gain_db=gain_db,
        )
        freqs, power = welch_psd(cap, nfft=bins)
        keep = (freqs >= start_hz) & (freqs <= stop_hz)
        for f, p in zip(freqs[keep], power[keep], strict=True):
            rows.append({"frequency_hz": float(f), "power_db": float(p)})
    rows.sort(key=lambda r: r["frequency_hz"])
    return rows


def demod_fm(cap: Capture, audio_rate: int = 48_000, deemphasis_us: float = 50.0) -> tuple[np.ndarray, int]:
    """Quadrature FM demodulation to mono audio."""
    from scipy import signal

    decim = max(1, int(round(cap.sample_rate / audio_rate)))
    baseband = signal.decimate(cap.samples, decim, ftype="fir") if decim > 1 else cap.samples
    rate = cap.sample_rate / decim
    demod = np.angle(baseband[1:] * np.conj(baseband[:-1]))
    # De-emphasis: a one-pole low-pass with the region's time constant.
    alpha = 1.0 / (1.0 + rate * deemphasis_us * 1e-6)
    audio = signal.lfilter([alpha], [1.0, -(1.0 - alpha)], demod)
    peak = float(np.max(np.abs(audio))) or 1.0
    return (audio / peak * 0.9).astype(np.float32), int(rate)


def write_wav(path: Path, audio: np.ndarray, rate: int) -> None:
    pcm = np.clip(audio, -1.0, 1.0)
    with wave.open(str(path), "wb") as fh:
        fh.setnchannels(1)
        fh.setsampwidth(2)
        fh.setframerate(rate)
        fh.writeframes((pcm * 32767).astype("<i2").tobytes())
