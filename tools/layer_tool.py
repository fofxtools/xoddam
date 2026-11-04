"""Turn generated strips into game-ready parallax layers: key out the magenta background, trim, make them tile.

usage:
  python layer_tool.py <in.png> <out.png> [--key] [--tile OVERLAP_FRACTION] [--trim-bottom PX] [--crop-top FRACTION]
"""
import argparse

import numpy as np
from PIL import Image


def key_color(img: Image.Image, color: str = "green", lo: float = 70.0, hi: float = 200.0) -> Image.Image:
    """Alpha from how close a pixel is to the key color (green: green far above red and blue; magenta: the reverse)."""
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    if color == "green":
        magenta = g - np.maximum(r, b)  # about 255 for the key color
        r, g, b = r, g, b
    else:
        magenta = np.minimum(r, b) - g
    alpha = 1.0 - np.clip((magenta - lo) / (hi - lo), 0.0, 1.0)
    # A key color that is not perfectly even leaves a faint see-through haze (alpha 4-25%) over the empty parts of a
    # layer; its rectangle edges showed as horizontal bands across the sky in game. Anything this faint is nothing.
    alpha = np.where(alpha < 0.27, 0.0, alpha)
    # despill: bring red and blue down to green's level wherever they stick out above it a lot
    spill = np.clip(np.minimum(r, b) - g, 0, None) * (1.0 - alpha) * 0.0
    out = a.copy()
    soft = alpha < 1.0
    if color == "green":
        ceiling = np.maximum(r, b) + 30.0
        out[..., 1] = np.where(soft, np.minimum(g, ceiling), g)
    else:
        ceiling = g + 40.0
        out[..., 0] = np.where(soft, np.minimum(r, ceiling), r)
        out[..., 2] = np.where(soft, np.minimum(b, ceiling), b)
    rgba = np.dstack([out, alpha * 255.0]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def make_tileable(img: Image.Image, overlap_fraction: float) -> Image.Image:
    """Cross-fade the right edge into the left edge so the picture repeats with no visible seam (it gets narrower)."""
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    h, w, _ = a.shape
    o = int(w * overlap_fraction)
    t = np.linspace(0.0, 1.0, o, dtype=np.float32)[None, :, None]
    tail = a[:, w - o:, :]
    head = a[:, :o, :]
    # premultiply so transparent pixels do not bleed color
    def pre(x): return np.dstack([x[..., :3] * (x[..., 3:4] / 255.0), x[..., 3:4]])
    mixed = pre(tail) * (1.0 - t) + pre(head) * t
    alpha = mixed[..., 3:4]
    rgb = np.where(alpha > 0.5, mixed[..., :3] / np.maximum(alpha / 255.0, 1e-3), 0.0)
    blended = np.dstack([rgb, alpha])
    out = np.concatenate([blended, a[:, o:w - o, :]], axis=1)
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--key", choices=["green", "magenta"])
    p.add_argument("--tile", type=float, default=0.0)
    p.add_argument("--mirror", action="store_true", help="append a mirrored copy, so the picture tiles without a seam")
    p.add_argument("--trim-bottom", type=int, default=0)
    p.add_argument("--crop-top", type=float, default=0.0, help="drop this fraction of empty rows from the top")
    args = p.parse_args()
    img = Image.open(args.src).convert("RGBA")
    if args.key:
        img = key_color(img, args.key)
    if args.trim_bottom:
        img = img.crop((0, 0, img.width, img.height - args.trim_bottom))
    if args.crop_top:
        img = img.crop((0, int(img.height * args.crop_top), img.width, img.height))
    if args.key:  # trim fully transparent rows from the top
        alpha = np.asarray(img)[..., 3]
        rows = np.where((alpha > 128).sum(axis=1) > 4)[0]  # ignore stray specks
        if len(rows):  # and from the bottom, so the picture's bottom edge is where its content ends
            img = img.crop((0, int(rows[0]), img.width, int(rows[-1]) + 1))
    if args.mirror:
        img = Image.fromarray(np.concatenate([np.asarray(img), np.asarray(img)[:, ::-1]], axis=1), "RGBA")
    if args.tile:
        img = make_tileable(img, args.tile)
    img.save(args.dst)
    print(args.dst, img.size)


main()
