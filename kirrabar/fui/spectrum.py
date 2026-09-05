#!/usr/bin/env python3
import cmath
import math
import signal
import struct
import subprocess
import sys

BARS = max(8, min(96, int(sys.argv[1]) if len(sys.argv) > 1 else 36))
RATE = 44100
N = 1024
BYTES = N * 2
FMIN = 50.0
FMAX = 9000.0


def fft(vals):
    n = len(vals)
    if n <= 1:
        return vals
    even = fft(vals[0::2])
    odd = fft(vals[1::2])
    out = [0j] * n
    for k in range(n // 2):
        t = cmath.exp(-2j * math.pi * k / n) * odd[k]
        out[k] = even[k] + t
        out[k + n // 2] = even[k] - t
    return out


def band_edges():
    ratio = FMAX / FMIN
    return [FMIN * (ratio ** (i / BARS)) for i in range(BARS + 1)]


def main():
    cmd = [
        "pw-record",
        "-a",
        "--format", "s16",
        "--rate", str(RATE),
        "--channels", "1",
        "--latency", "20ms",
        "--media-type", "Audio",
        "-P", "stream.capture.sink=true",
        "-",
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if proc.stdout is None:
        return

    def die(*_):
        try:
            proc.kill()
        except Exception:
            pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, die)
    signal.signal(signal.SIGINT, die)

    edges = band_edges()
    bins = [min(N // 2 - 1, max(1, int(f * N / RATE))) for f in edges]
    hann = [0.5 - 0.5 * math.cos(2 * math.pi * i / (N - 1)) for i in range(N)]
    smooth = [0.0] * BARS
    buf = b""

    while True:
        chunk = proc.stdout.read(BYTES - len(buf))
        if not chunk:
            break
        buf += chunk
        if len(buf) < BYTES:
            continue
        samples = struct.unpack("<" + "h" * N, buf[:BYTES])
        buf = buf[BYTES:]
        windowed = [samples[i] / 32768.0 * hann[i] for i in range(N)]
        spec = fft(windowed)
        mags = [abs(spec[i]) / (N * 0.5) for i in range(N // 2)]
        out = []
        for i in range(BARS):
            a = bins[i]
            b = max(a + 1, bins[i + 1])
            peak = 0.0
            for k in range(a, b):
                if mags[k] > peak:
                    peak = mags[k]
            db = 20.0 * math.log10(peak * 3.6 + 1e-8)
            v = (db + 38.0) / 42.0
            if v < 0:
                v = 0.0
            elif v > 1:
                v = 1.0
            v = v ** 0.72
            if v > smooth[i]:
                smooth[i] = smooth[i] * 0.12 + v * 0.88
            else:
                smooth[i] = smooth[i] * 0.62 + v * 0.38
            out.append(str(int(smooth[i] * 100)))
        sys.stdout.write(";".join(out) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
