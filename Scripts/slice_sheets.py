#!/usr/bin/env python3
"""
Slice the two character sheets into the poses the app expects.

    pip3 install pillow
    python3 Scripts/slice_sheets.py Artwork/standing.png Artwork/sitting.png

standing.png  – 4 figures, left → right:
    pose-peek        sleepy, peeking around the door
    pose-talk        pointing / talking
    pose-frustrated  scribble cloud, arms down
    pose-walk        walking away, zzz

sitting.png   – 3 figures, left → right:
    sit-happy        eyes closed, smiling, ♡
    sit-neutral      "..."
    sit-annoyed      scribble cloud

Each figure is found automatically by looking for gaps of background
between them, cropped, given a transparent background (flood-filled from
the edges so her white sweater survives), and written into
Shared/Character.xcassets/<name>.imageset/ at 1x/2x/3x.
"""
import json
import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow is missing – run:  pip3 install pillow")

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "Shared", "Character.xcassets")

STANDING = ["pose-peek", "pose-talk", "pose-frustrated", "pose-walk"]
SITTING = ["sit-happy", "sit-neutral", "sit-annoyed"]

INK_THRESHOLD = 40      # how different from the background a pixel must be to count as "her"
MIN_GAP = 24            # px of pure background that separates two figures
PADDING = 24            # px of breathing room around each crop
MAX_HEIGHT_3X = 1200    # 3x asset height; 2x and 1x are derived


def background_colour(im):
    """Median colour of the outer 2 px border."""
    w, h = im.size
    px = im.load()
    samples = []
    for x in range(w):
        samples += [px[x, 0], px[x, 1], px[x, h - 1], px[x, h - 2]]
    for y in range(h):
        samples += [px[0, y], px[1, y], px[w - 1, y], px[w - 2, y]]
    chans = list(zip(*[s[:3] for s in samples]))
    return tuple(sorted(c)[len(c) // 2] for c in chans)


def ink_mask(im, bg):
    """1-bit image: 255 where the pixel differs from the background."""
    r, g, b = im.split()[:3]
    def diff(chan, ref):
        return chan.point(lambda v, ref=ref: 255 if abs(v - ref) > INK_THRESHOLD else 0)
    m = diff(r, bg[0])
    m = Image.eval(Image.merge("RGB", (m, diff(g, bg[1]), diff(b, bg[2]))).convert("L"),
                   lambda v: 255 if v > 0 else 0)
    return m


def column_segments(mask, expected):
    """Split the sheet into `expected` horizontal spans, one per figure."""
    w, h = mask.size
    px = mask.load()
    ink_cols = [any(px[x, y] for y in range(0, h, 2)) for x in range(w)]

    spans, start, gap = [], None, 0
    for x, ink in enumerate(ink_cols + [False] * (MIN_GAP + 1)):
        if ink:
            if start is None:
                start = x
            gap = 0
        elif start is not None:
            gap += 1
            if gap >= MIN_GAP:
                spans.append((start, x - gap + 1))
                start, gap = None, 0

    # Emotion marks (zzz, scribbles) can float off on their own; glue the
    # narrowest spans onto their nearest neighbour until the count matches.
    while len(spans) > expected:
        i = min(range(len(spans)), key=lambda k: spans[k][1] - spans[k][0])
        if i == 0:
            j = 1
        elif i == len(spans) - 1:
            j = i - 1
        else:
            j = i - 1 if spans[i][0] - spans[i - 1][1] <= spans[i + 1][0] - spans[i][1] else i + 1
        lo, hi = min(i, j), max(i, j)
        spans[lo:hi + 1] = [(spans[lo][0], spans[hi][1])]

    if len(spans) < expected:
        sys.exit(f"found only {len(spans)} figures, expected {expected}. "
                 f"Try lowering MIN_GAP or INK_THRESHOLD in this script.")
    return spans


def crop_figure(im, mask, span):
    x0, x1 = span
    strip = mask.crop((x0, 0, x1, mask.size[1]))
    bbox = strip.getbbox()
    if bbox is None:
        return None
    left = max(0, x0 + bbox[0] - PADDING)
    top = max(0, bbox[1] - PADDING)
    right = min(im.size[0], x0 + bbox[2] + PADDING)
    bottom = min(im.size[1], bbox[3] + PADDING)
    return im.crop((left, top, right, bottom))


def make_transparent(im, bg):
    """Flood-fill the background from every edge so enclosed whites stay."""
    im = im.convert("RGBA")
    w, h = im.size
    fill = (0, 0, 0, 0)
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    seeds += [(x, 0) for x in range(0, w, 16)] + [(x, h - 1) for x in range(0, w, 16)]
    seeds += [(0, y) for y in range(0, h, 16)] + [(w - 1, y) for y in range(0, h, 16)]
    px = im.load()
    for s in seeds:
        if px[s][3] != 0:
            ImageDraw.floodfill(im, s, fill, thresh=INK_THRESHOLD)
    return im


def write_imageset(name, im):
    folder = os.path.join(ASSETS, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    for f in os.listdir(folder):
        if f.endswith(".png"):
            os.remove(os.path.join(folder, f))

    w, h = im.size
    scale = min(1.0, MAX_HEIGHT_3X / h)
    base3 = im.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
    images = []
    for factor, suffix in ((3, "@3x"), (2, "@2x"), (1, "")):
        s = factor / 3
        out = base3.resize((max(1, round(base3.size[0] * s)), max(1, round(base3.size[1] * s))),
                           Image.LANCZOS)
        fname = f"{name}{suffix}.png"
        out.save(os.path.join(folder, fname))
        images.append({"filename": fname, "idiom": "universal", "scale": f"{factor}x"})

    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": images[::-1], "info": {"author": "xcode", "version": 1}}, f, indent=2)
    print(f"  ✓ {name}  ({base3.size[0]}×{base3.size[1]} @3x)")


def slice_sheet(path, names):
    print(f"→ {path}")
    im = Image.open(path).convert("RGB")
    bg = background_colour(im)
    mask = ink_mask(im, bg)
    spans = column_segments(mask, len(names))
    for name, span in zip(names, spans):
        fig = crop_figure(im, mask, span)
        if fig is None:
            print(f"  ✗ {name}: nothing found in its column")
            continue
        write_imageset(name, make_transparent(fig, bg))


def main(argv):
    if len(argv) != 3:
        sys.exit(__doc__)
    slice_sheet(argv[1], STANDING)
    slice_sheet(argv[2], SITTING)
    print("done – rebuild the app and she'll show up.")


if __name__ == "__main__":
    main(sys.argv)
