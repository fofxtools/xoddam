"""Cut a sprite out of its plain background: flood-fill from the border over pixels close to the border colour,
soften the edge, trim to the content. usage: python cutout.py in.png out.png [--key green] [--tol 28]"""
import argparse
import numpy as np
from collections import deque
from PIL import Image, ImageFilter

def cutout(img, tol=28, green=False):
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    h, w, _ = a.shape
    if green:
        dist = np.maximum(np.maximum(a[..., 0], a[..., 2]) - a[..., 1] + 160, 0)  # not used
        bg = (a[..., 1] - np.maximum(a[..., 0], a[..., 2])) > 70
        mask_bg = bg
    else:
        border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
        ref = np.median(border, axis=0)
        close = np.abs(a - ref).max(axis=2) <= tol
        seen = np.zeros((h, w), bool); q = deque()
        for x in range(w):
            for y in (0, h - 1):
                if close[y, x] and not seen[y, x]: seen[y, x] = True; q.append((y, x))
        for y in range(h):
            for x in (0, w - 1):
                if close[y, x] and not seen[y, x]: seen[y, x] = True; q.append((y, x))
        while q:
            y, x = q.popleft()
            for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and close[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True; q.append((ny, nx))
        mask_bg = seen
    alpha = Image.fromarray(((~mask_bg) * 255).astype(np.uint8))
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))  # shave the halo, soften
    out = img.convert("RGBA"); out.putalpha(alpha)
    bbox = alpha.point(lambda v: 255 if v > 40 else 0).getbbox()
    return out.crop(bbox) if bbox else out

if __name__ == "__main__":
    p = argparse.ArgumentParser(); p.add_argument("src"); p.add_argument("dst"); p.add_argument("--key"); p.add_argument("--tol", type=int, default=28)
    a = p.parse_args()
    r = cutout(Image.open(a.src), a.tol, a.key == "green"); r.save(a.dst); print(a.dst, r.size)
