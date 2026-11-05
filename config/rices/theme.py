"""Make hard-coded Catppuccin colours / radii in GTK popup CSS follow the active rice (palette cached by wardrobe.py)."""
import json, os, re, sys

def _load():
    try:
        d = json.load(open(os.path.expanduser("~/.cache/rice-palette.json")))
        return d["pal"], d.get("radius", 1.0)
    except Exception:
        return None, 1.0

def css(data):
    raw = data.decode() if isinstance(data, bytes) else data
    pal, k = _load()
    if pal:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import wardrobe
        m = {v: pal[n] for n, v in wardrobe.KEYS.items()}
        raw = re.sub(r"#([0-9a-fA-F]{6})", lambda x: "#" + m.get(x.group(1).lower(), x.group(1)), raw)
        def rg(x):
            h = "%02x%02x%02x" % (int(x[1]), int(x[2]), int(x[3]))
            if h not in m: return x[0]
            n = m[h]; return f"rgba({int(n[0:2], 16)},{int(n[2:4], 16)},{int(n[4:6], 16)},{x[4]})"
        raw = re.sub(r"rgba\(\s*(\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)", rg, raw)
    raw = re.sub(r"(border-radius:\s*)(\d+)px", lambda x: f"{x[1]}{round(int(x[2]) * k)}px", raw)
    return raw.encode() if isinstance(data, bytes) else raw
