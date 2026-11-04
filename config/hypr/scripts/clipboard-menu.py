#!/usr/bin/env python3
# stdin: `cliphist list`; stdout: wofi dmenu lines (images become img:<thumb>:text:<label>). argv[1]: thumbnail cache dir.
import os, re, shutil, subprocess, sys
cache = sys.argv[1]
os.makedirs(cache, exist_ok=True)
for line in sys.stdin.read().splitlines():
    id_, _, body = line.partition("\t")
    m = re.match(r"\[\[ binary data (.*?) (png|jpe?g|bmp|gif|webp) (\d+x\d+) \]\]", body)
    if not (m and id_.isdigit()):
        print(line); continue
    thumb = os.path.join(cache, id_ + ".png")
    if not os.path.exists(thumb):
        data = subprocess.run(["cliphist", "decode", id_], capture_output=True).stdout
        cmd = (["magick", "-", "-thumbnail", "160x160>", thumb] if shutil.which("magick") else
               ["ffmpeg", "-loglevel", "error", "-y", "-i", "-", "-vf", "scale=160:160:force_original_aspect_ratio=decrease", thumb])
        subprocess.run(cmd, input=data, capture_output=True)
    print(f"img:{thumb}:text:{id_}\t󰋩 image {m[3]}" if os.path.exists(thumb) else line)
