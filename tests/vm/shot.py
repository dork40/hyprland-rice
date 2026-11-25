#!/usr/bin/env python3
# shot.py <distro> <out.png>: screenshot a running test VM's screen through its QMP socket
import json, os, socket, subprocess, sys
d, out = sys.argv[1], os.path.abspath(sys.argv[2])
W = os.environ.get("WIRE_VMTEST", os.path.expanduser("~/Projects/wire-vmtest"))
s = socket.socket(socket.AF_UNIX); s.connect(f"{W}/run/{d}.qmp"); f = s.makefile("rw")
def cmd(c, **a):
    f.write(json.dumps({"execute": c, "arguments": a} if a else {"execute": c}) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r: return r
f.readline(); cmd("qmp_capabilities")
ppm = out.rsplit(".", 1)[0] + ".ppm"
r = cmd("screendump", filename=ppm)
if "error" in r: sys.exit(r["error"])
subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", ppm, out], check=True); os.remove(ppm); print(out)
