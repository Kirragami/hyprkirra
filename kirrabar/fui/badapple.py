#!/usr/bin/env python3
import gzip
import signal
import struct
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
MAGIC = b"KBA1"
COLS = 220
ROWS = 32
FPS = 12
HDR = struct.Struct("<4sHHHHI")

# Drop in another .bin.gz and add a row. Duration windows are loose on purpose.
CUTS = (
    {"id": "pv", "file": "badapple.bin.gz", "min": 195, "max": 270},
    {"id": "full", "file": "badapple-full.bin.gz", "min": 300, "max": 345},
)
CUT_IDS = tuple(c["id"] for c in CUTS)


def cut_by_id(cid: str) -> dict | None:
    for c in CUTS:
        if c["id"] == cid:
            return c
    return None


def asset_path(cid: str = "pv") -> Path | None:
    c = cut_by_id(cid)
    if not c:
        return None
    path = HERE / c["file"]
    return path if path.is_file() else None


def present_cuts() -> list:
    return [c for c in CUTS if (HERE / c["file"]).is_file()]


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


def play(cid: str, start: float) -> None:
    path = asset_path(cid)
    if path is None:
        print("ERR", flush=True)
        return
    cols, rows, fps, frames = load_tape(path)
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
        have = present_cuts()
        if not have:
            print("ERR", flush=True)
            return
        bits = " ".join(f"{c['id']}:{c['min']}-{c['max']}" for c in have)
        print("HAVE " + bits, flush=True)
        return

    if args and args[0] == "--pack":
        rest = args[1:]
        cid = "pv"
        if rest and rest[0] in CUT_IDS:
            cid = rest[0]
            rest = rest[1:]
        spec = cut_by_id(cid)
        src = Path(rest[0]) if rest else find_video()
        dest = Path(rest[1]) if spec and len(rest) > 1 else (HERE / spec["file"] if spec else None)
        if spec is None or dest is None or src is None or not Path(src).is_file():
            print("ERR no video", file=sys.stderr)
            sys.exit(1)
        pack_video(Path(src), dest)
        return

    cid = "pv"
    start = 0.0
    if args and args[0] in CUT_IDS:
        cid = args[0]
        start = float(args[1]) if len(args) > 1 else 0.0
    elif args:
        start = float(args[0])
    if asset_path(cid) is None:
        print("ERR", flush=True)
        sys.exit(1)
    play(cid, start)


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
