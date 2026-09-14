#!/usr/bin/env python3
import gzip
import signal
import struct
import subprocess
import sys
import time
from pathlib import Path

ASSET = Path(__file__).resolve().with_name("badapple.bin.gz")
MAGIC = b"KBA1"
COLS = 220
ROWS = 32
FPS = 12
HDR = struct.Struct("<4sHHHHI")


def asset_path() -> Path:
    return ASSET


def find_video() -> Path | None:
    home = Path.home()
    names = ("bad_apple_h264.mp4", "bad_apple.mp4", "badapple.mp4")
    roots = (
        home / "Projects" / "kb-bad-apple",
        Path(__file__).resolve().parent,
        Path(__file__).resolve().parent.parent / "media",
    )
    for root in roots:
        for name in names:
            path = root / name
            if path.is_file():
                return path
    return None


def pack_bits(gray: bytes, n: int) -> bytes:
    out = bytearray((n + 7) // 8)
    for i in range(n):
        if gray[i] >= 70:
            out[i >> 3] |= 1 << (7 - (i & 7))
    return bytes(out)


def unpack_line(packed: bytes, n: int) -> str:
    chars = ["0"] * n
    for i in range(n):
        if packed[i >> 3] & (1 << (7 - (i & 7))):
            chars[i] = "f"
    return "".join(chars)


def load_tape(path: Path):
    with gzip.open(path, "rb") as f:
        data = f.read()
    if len(data) < HDR.size:
        raise ValueError("short tape")
    magic, cols, rows, fps, _pad, count = HDR.unpack_from(data, 0)
    if magic != MAGIC or cols < 1 or rows < 1 or fps < 1 or count < 1:
        raise ValueError("bad tape")
    stride = (cols * rows + 7) // 8
    need = HDR.size + stride * count
    if len(data) < need:
        raise ValueError("truncated tape")
    frames = []
    off = HDR.size
    for _ in range(count):
        frames.append(data[off : off + stride])
        off += stride
    return cols, rows, fps, frames


def pack_video(src: Path, dest: Path, cols: int = COLS, rows: int = ROWS, fps: int = FPS) -> None:
    vf = (
        f"fps={fps},"
        f"scale={cols}:{rows}:force_original_aspect_ratio=increase:flags=neighbor,"
        f"crop={cols}:{rows},eq=contrast=1.5:brightness=0.05"
    )
    raw = subprocess.check_output(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(src),
            "-an",
            "-vf",
            vf,
            "-f",
            "rawvideo",
            "-pix_fmt",
            "gray",
            "-",
        ]
    )
    px = cols * rows
    if len(raw) < px or len(raw) % px:
        raise RuntimeError("unexpected ffmpeg size")
    n = len(raw) // px
    body = bytearray()
    for i in range(n):
        body.extend(pack_bits(raw[i * px : (i + 1) * px], px))
    blob = HDR.pack(MAGIC, cols, rows, fps, 0, n) + bytes(body)
    dest.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(dest, "wb", compresslevel=9) as f:
        f.write(blob)
    print(f"wrote {dest} ({n} frames, {cols}x{rows} @{fps}fps, {dest.stat().st_size} bytes)")


def play(start: float) -> None:
    cols, rows, fps, frames = load_tape(asset_path())
    n = len(frames)
    pix = cols * rows
    print(f"OK {cols} {rows} {fps} {n}", flush=True)

    def die(*_):
        sys.exit(0)

    signal.signal(signal.SIGTERM, die)
    signal.signal(signal.SIGINT, die)

    t0 = time.monotonic()
    base = max(0.0, start)
    last = -1
    while True:
        now = time.monotonic()
        i = int((base + (now - t0)) * fps) % n
        if i != last:
            sys.stdout.write("F " + unpack_line(frames[i], pix) + "\n")
            sys.stdout.flush()
            last = i
        nxt = t0 + ((i + 1) / fps - base)
        delay = nxt - time.monotonic()
        if delay > 0.001:
            time.sleep(min(delay, 0.08))
        else:
            time.sleep(0.001)


def main() -> None:
    args = sys.argv[1:]
    if args and args[0] == "--probe":
        if not asset_path().is_file():
            print("ERR", flush=True)
            return
        try:
            cols, rows, fps, frames = load_tape(asset_path())
        except Exception:
            print("ERR", flush=True)
            return
        print(f"OK {cols} {rows} {fps} {len(frames)}", flush=True)
        return

    if args and args[0] == "--pack":
        src = Path(args[1]) if len(args) > 1 else find_video()
        dest = Path(args[2]) if len(args) > 2 else asset_path()
        if src is None or not Path(src).is_file():
            print("ERR no video", file=sys.stderr)
            sys.exit(1)
        pack_video(Path(src), dest)
        return

    start = float(args[0]) if args else 0.0
    if not asset_path().is_file():
        print("ERR", flush=True)
        sys.exit(1)
    play(start)


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
