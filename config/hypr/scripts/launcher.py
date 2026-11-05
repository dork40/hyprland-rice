#!/usr/bin/env python3
# Super+R: app launcher that also calculates. Pick an app to open it; type a sum (12*7, 15% of 80, 5 km to mi)
# and press Enter to see the answer (Enter on the answer copies it); type a command to run it.
import json, os, re, shutil, subprocess, sys

H = os.path.expanduser("~")
DIRS = ["/usr/share/applications", f"{H}/.local/share/applications",
        f"{H}/.local/share/flatpak/exports/share/applications", "/var/lib/flatpak/exports/share/applications"]
CACHE = f"{H}/.cache/launcher-apps.json"
ICON_DIRS = [f"{H}/.local/share/icons/Papirus-Dark/{s}/apps" for s in ("48x48", "64x64", "32x32")] + \
            [f"/usr/share/icons/hicolor/{s}/apps" for s in ("48x48", "64x64", "128x128", "256x256", "scalable")] + ["/usr/share/pixmaps"]


def find_icon(name):
    if not name: return ""
    if os.path.isabs(name): return name if os.path.exists(name) else ""
    for d in ICON_DIRS:
        for ext in ("svg", "png", "xpm"):
            p = f"{d}/{name}.{ext}"
            if os.path.exists(p): return p
    return ""


def parse_desktop(path):
    ent, inside = {}, False
    try:
        for line in open(path, encoding="utf-8", errors="replace"):
            line = line.strip()
            if line.startswith("["): inside = line == "[Desktop Entry]"; continue
            if inside and "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                ent.setdefault(k, v)   # first (unlocalised) value wins
    except OSError:
        return None
    if ent.get("Type") != "Application" or ent.get("NoDisplay") == "true" or ent.get("Hidden") == "true": return None
    if "OnlyShowIn" in ent or not ent.get("Name"): return None
    return dict(name=ent["Name"], icon=find_icon(ent.get("Icon", "")), path=path)


def load_apps():
    stamp = max((os.path.getmtime(d) for d in DIRS if os.path.isdir(d)), default=0)
    try:
        c = json.load(open(CACHE))
        if c.get("stamp") == stamp: return c["apps"]
    except (OSError, ValueError):
        pass
    seen, apps = set(), []
    for d in DIRS:
        if not os.path.isdir(d): continue
        for f in sorted(os.listdir(d)):
            if not f.endswith(".desktop"): continue
            a = parse_desktop(os.path.join(d, f))
            if a and a["name"].lower() not in seen:
                seen.add(a["name"].lower()); apps.append(a)
    apps.sort(key=lambda a: a["name"].lower())
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    json.dump({"stamp": stamp, "apps": apps}, open(CACHE, "w"))
    return apps


def wofi(lines, prompt, n=14):
    r = subprocess.run(["wofi", "--dmenu", "--prompt", prompt, "--allow-images", "--insensitive", "--lines", str(n)],
                       input="\n".join(lines), capture_output=True, text=True)
    if r.returncode != 0 and not r.stdout.strip(): return None
    out = r.stdout.strip("\n")
    return re.sub(r"^img:.*?:text:", "", out)


def calc(text):
    """Evaluate with qalc; None if it isn't a sum."""
    if not re.search(r"\d", text): return None
    t = re.sub(r"(\d+(?:\.\d+)?)\s*%\s*of\s*(.+)", r"(\1/100)*(\2)", text.strip(), flags=re.I)
    r = subprocess.run(["qalc", "-t", t], capture_output=True, text=True)
    lines = [l for l in r.stdout.splitlines() if l.strip()]
    if r.returncode != 0 or not lines: return None
    res = lines[-1].strip()
    return None if re.search(r"error|unknown|undefined", res, re.I) else res


def calculator(first, res):
    lines = [f"= {res}", first]
    while True:
        inp = wofi(lines, "Calculate", 4)
        if not inp: return
        if inp.startswith("= "):
            subprocess.run(["wl-copy"], input=inp[2:], text=True)
            subprocess.run(["notify-send", "-t", "2000", f"Copied {inp[2:]}"])
            return
        r = calc(inp)
        lines = [f"= {r}" if r else "= ?", inp]


def main():
    apps = load_apps()
    by_name = {a["name"]: a for a in apps}
    pick = wofi([f"img:{a['icon']}:text:{a['name']}" if a["icon"] else a["name"] for a in apps], "Run or calculate")
    if not pick: return
    if pick in by_name:
        subprocess.Popen(["gio", "launch", by_name[pick]["path"]], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    first = pick.split()[0] if pick.split() else ""
    if first and shutil.which(first):   # a command: run it
        subprocess.Popen(["sh", "-c", pick], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    res = calc(pick)
    if res: calculator(pick, res)
    else: subprocess.run(["notify-send", "-t", "2500", "Nothing matches", pick])


if __name__ == "__main__":
    main()
