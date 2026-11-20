#!/usr/bin/env python3
"""Creates dense timestamped contact-sheet PNGs from MP4 clips so every sub-second
phase of every animation can be visually inspected frame-by-frame alongside the MP4s.

Usage:
  python3 scripts/make-contact-sheet.py <video.mp4> <out.png> [--cols 6] [--step 4]
"""

import argparse
import math
import pathlib
import subprocess
import tempfile
from PIL import Image, ImageDraw


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("video", type=pathlib.Path)
    ap.add_argument("out", type=pathlib.Path)
    ap.add_argument("--cols", type=int, default=6)
    ap.add_argument("--step", type=int, default=4, help="Keep every Nth frame")
    ap.add_argument("--thumb-w", type=int, default=320)
    args = ap.parse_args()

    # Probe fps
    probe = subprocess.check_output(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=r_frame_rate", "-of", "csv=p=0", str(args.video)],
        text=True,
    ).strip()
    num, den = (probe.split("/") + ["1"])[:2]
    fps = float(num) / float(den)

    with tempfile.TemporaryDirectory() as td:
        subprocess.check_call(
            ["ffmpeg", "-y", "-i", str(args.video), f"{td}/f_%04d.png"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        frames = sorted(pathlib.Path(td).glob("f_*.png"))
        picked = [(i, frames[i]) for i in range(0, len(frames), max(1, args.step))]
        if not picked:
            return
        im0 = Image.open(picked[0][1])
        tw = args.thumb_w
        th = int(round(im0.height * tw / im0.width))
        cols = args.cols
        rows = math.ceil(len(picked) / cols)
        sheet = Image.new("RGB", (cols * tw, rows * th), (12, 12, 16))
        draw = ImageDraw.Draw(sheet)
        for idx, (frame_num, fp) in enumerate(picked):
            im = Image.open(fp).resize((tw, th), Image.Resampling.LANCZOS)
            r, c = divmod(idx, cols)
            x, y = c * tw, r * th
            sheet.paste(im, (x, y))
            t = frame_num / fps
            tag = f"f{frame_num:03d} ({t:.2f}s)"
            draw.rectangle([x + 2, y + th - 18, x + 110, y + th - 2], fill=(0, 0, 0))
            draw.text((x + 6, y + th - 16), tag, fill=(255, 224, 140))
        args.out.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(args.out)
        print(f"[sheet] {args.out} ({len(picked)} tiles, {cols}x{rows}, {fps:.1f}fps)")


if __name__ == "__main__":
    main()
