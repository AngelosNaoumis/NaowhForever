"""Compress the Dungeon Journal's map pictures into BLP files. Needs Pillow 11.2 or later.

    python Tools/media/compress_maps.py            every .tga and .png in Media/Maps
    python Tools/media/compress_maps.py a.tga b.png  just those

Each picture becomes a 1024x1024 DXT1 BLP with mipmaps beside it, and the original is deleted.
Data/Maps.lua names the pictures without an extension, so nothing else changes.
"""
import io
import struct
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402

MAPS = paths.ROOT / "NaowhForever_DungeonJournal" / "Media" / "Maps"
SIZE = 1024
DDS_HEADER = 128
BLP_TYPE_DIRECT = 1
BLP_DXT = 2
BLP_MIP_SLOTS = 16
BLP_PALETTE = 256 * 4
BLP_HEADER = 4 + 4 + 4 + 8 + BLP_MIP_SLOTS * 4 * 2 + BLP_PALETTE


def levels(image):
    level = image
    while True:
        out = io.BytesIO()
        level.save(out, "DDS", pixel_format="DXT1")
        yield out.getvalue()[DDS_HEADER:]
        if level.size == (1, 1):
            return
        level = level.resize((max(1, level.width // 2), max(1, level.height // 2)), Image.LANCZOS)


def blp(image):
    data = list(levels(image))
    offsets, sizes, at = [], [], BLP_HEADER
    for level in data:
        offsets.append(at)
        sizes.append(len(level))
        at += len(level)
    pad = [0] * (BLP_MIP_SLOTS - len(data))
    header = (b"BLP2" + struct.pack("<I", BLP_TYPE_DIRECT) + bytes([BLP_DXT, 0, 0, 1])
              + struct.pack("<II", *image.size)
              + struct.pack("<16I", *offsets, *pad) + struct.pack("<16I", *sizes, *pad))
    return header + bytes(BLP_PALETTE) + b"".join(data)


def compress(path):
    image = Image.open(path).convert("RGB")
    if image.size != (SIZE, SIZE):
        image = image.resize((SIZE, SIZE), Image.LANCZOS)
    out = path.with_suffix(".blp")
    out.write_bytes(blp(image))
    path.unlink()
    print(f"{path.name} -> {out.name} ({out.stat().st_size // 1024} KB)")


def main(args):
    files = [Path(a) for a in args] or sorted(p for p in MAPS.iterdir() if p.suffix.lower() in (".tga", ".png"))
    for path in files:
        compress(path)


if __name__ == "__main__":
    main(sys.argv[1:])
