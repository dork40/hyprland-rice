#!/usr/bin/env python3
"""Wardrobe: switch between whole-desktop rice styles.  wardrobe.py [pick|next|apply NAME|list|current]"""
import os, re, subprocess, sys, pathlib

H = pathlib.Path.home()
C = H / ".config"
R = C / "rices"
STATE = R / "current"

# Catppuccin Mocha names -> the hex used in the base files (case-insensitive match)
KEYS = dict(rosewater="f5e0dc", pink="f5c2e7", mauve="cba6f7", red="f38ba8", peach="fab387",
            yellow="f9e2af", green="a6e3a1", teal="94e2d5", sky="89dceb", blue="89b4fa",
            lavender="b4befe", text="cdd6f4", sub1="bac2de", sub0="a6adc8", ov2="9399b2",
            ov1="7f849c", ov0="6c7086", s2="585b70", s1="45475a", mantle="181825",
            crust="11111b", base="1e1e2e")

def pal(**kw):
    return {k: kw.get(k, KEYS[k]) for k in KEYS}

def mix(a, b, t):
    """Blend hex colour a toward b by t (0..1)."""
    x, y = [tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) for h in (a, b)]
    return "".join(f"{round(i + (j - i) * t):02x}" for i, j in zip(x, y))

def muted(accent, text="e2e2e2", red="c97a76", green="8fae8b", yellow="c9a96e", peach="c4926a", grey=None):
    """A restrained palette: one accent on neutral greys. Hues that used to be a rainbow all collapse to the accent;
    only red/green/yellow keep their meaning (battery, warnings, recording), desaturated."""
    g = grey or dict(sub1="bdbdbd", sub0="a2a2a2", ov2="8a8a8a", ov1="747474", ov0="5e5e5e", s2="3a3a3a", s1="262626",
                     mantle="0d0d0d", crust="000000", base="000000")
    return pal(rosewater=text, pink=mix(accent, text, 0.5), mauve=accent, lavender=accent, blue=accent, sky=accent,
               teal=accent, red=red, green=green, yellow=yellow, peach=peach, text=text, **g)

# natural, muted terminal colours (kitty ANSI), shared by the coloured rices
ANSI = dict(black="262626", red="c97a76", green="8fae8b", yellow="c9a96e", blue="7f9bb8", magenta="a08aa8", cyan="7fa9a6",
            white="bdbdbd", bblack="3a3a3a", bwhite="e2e2e2")

# bar_a: bar background alpha, anim: smooth|none, kitty_a: terminal opacity, radius: scale applied to every border-radius in the css
RICES = {
    "noir": dict(wall="~/Pictures/wallpapers/noir/orbital-sunrise.jpg", desc="Near-black, one cool grey-blue accent, small corners",
        pal=muted("8da2ba"), border=("8da2ba",), accent="8da2ba", inactive="2a2a2a",
        rounding=12, gaps_in=1, gaps_out=3, border_size=1, blur=(4, 2), bar_r=16, bar_a=0.92, anim="smooth", kitty_a=0.5, radius=0.9),
    "liquid": dict(wall="~/Pictures/wallpapers/liquid/liquid-plasma.jpg", desc="Frosted glass panels, soft but restrained, pale steel accent",
        pal=muted("a9b9cc", text="eef1f5", grey=dict(sub1="d3d8e0", sub0="b8bfca", ov2="9aa3b2", ov1="7f8999", ov0="667082",
                  s2="3d4555", s1="262c38", mantle="0a0c10", crust="000000", base="000000")),
        border=("c8d2de",), accent="a9b9cc", inactive="4a5262",
        rounding=16, gaps_in=3, gaps_out=6, border_size=1, blur=(10, 3), bar_r=18, bar_a=0.3, anim="smooth", kitty_a=0.35, radius=1.1,
        glass=0.35, layers=("waybar", "notifications", "logout_dialog", "swayosd")),
    "mono": dict(wall="~/Pictures/wallpapers/mono/saturn-grey.jpg", desc="Pure greyscale, flat and instant, no animations",
        pal=muted("d8d8d8", text="e6e6e6", red="d0d0d0", green="cfcfcf", yellow="dadada", peach="c8c8c8"),
        border=("d8d8d8",), accent="d8d8d8", inactive="2a2a2a",
        rounding=0, gaps_in=0, gaps_out=0, border_size=1, blur=(3, 1), bar_r=0, bar_a=1.0, anim="none", kitty_a=0.9, radius=0.0, mono_ansi=True),
}
RICES["aurora"] = dict(wall="~/Pictures/wallpapers/aurora/earth-limb.jpg", dynamic=True,
    desc="One muted accent taken from the wallpaper, on black",
    pal=muted("8da2ba"), border=("8da2ba",), accent="8da2ba", inactive="2a2a2a",
    rounding=14, gaps_in=2, gaps_out=5, border_size=1, blur=(6, 2), bar_r=16, bar_a=0.8, anim="smooth", kitty_a=0.45, radius=1.0)
ORDER = list(RICES)

def dynamic_rice(r, wp):
    """Take ONE accent from the wallpaper with matugen, desaturate it, and put it on the neutral palette."""
    try:
        import json
        out = subprocess.run(["matugen", "image", wp, "--dry-run", "--json", "hex", "-m", "dark", "--prefer", "saturation"],
                             capture_output=True, text=True, timeout=20, check=True).stdout
        c = {k: v["dark"]["color"].lstrip("#") for k, v in json.loads(out)["colors"].items()}
        acc = mix(c["primary"], "9a9a9a", 0.42)          # pull most of the saturation out so it reads as natural, not neon
    except Exception:
        return r
    r = dict(r); r.update(pal=muted(acc), border=(acc,), accent=acc)
    return r
    q = dict(r["pal"])
    q.update(mauve=c["primary"], lavender=c["primary"], blue=c["secondary"], sky=c["secondary"], teal=c["tertiary"],
             pink=c["tertiary"], rosewater=c["on_primary_container"], text=c["on_surface"], sub1=c["on_surface_variant"],
             sub0=c["on_surface_variant"], ov2=c["outline"], ov1=c["outline"], ov0=c["outline_variant"],
             s2=c["surface_container_highest"], s1=c["surface_container_high"], mantle="0a0a0a", crust="000000", base="000000")
    r = dict(r)
    r.update(pal=q, border=(c["primary"], c["tertiary"], c["secondary"]), accent=c["primary"], inactive=c["outline_variant"])
    return r

def recolor(text, p):
    text = text.replace("@HOME@", str(H))
    m = {v: p[k] for k, v in KEYS.items()}
    text = re.sub(r"#([0-9a-fA-F]{6})", lambda x: "#" + m.get(x.group(1).lower(), x.group(1)), text)
    def rgba_sub(x):   # rgba(203, 166, 247, 0.3) style glows follow the palette too
        h = "%02x%02x%02x" % (int(x[1]), int(x[2]), int(x[3]))
        if h not in m: return x[0]
        r_, g_, b_ = hexrgb(m[h])
        return f"rgba({r_}, {g_}, {b_}, {x[4]})"
    return re.sub(r"rgba\(\s*(\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)", rgba_sub, text)

def restyle(text, r, bar=False):
    """Smaller corners: scale every border-radius (fonts are left alone, the Nerd Font stays)."""
    k = r.get("radius", 1.0)
    text = re.sub(r"(border-radius:\s*)(\d+)px", lambda x: f"{x[1]}{round(int(x[2]) * k)}px", text)
    text = re.sub(r"(corner_radius\s*=\s*)(\d+)", lambda x: f"{x[1]}{round(int(x[2]) * k)}", text)
    return text

def glassify(text, f):
    return re.sub(r"rgba\((\d+), (\d+), (\d+), ([\d.]+)\)",
                  lambda m: f"rgba({m[1]}, {m[2]}, {m[3]}, {round(float(m[4]) * f, 2)})" if int(m[1]) < 40 else m[0], text)

def rgba(hexs, a="ff"):
    return f"rgba({hexs}{a})"

def hexrgb(h):
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def write(path, text):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)

def lua(r):
    b = ", ".join(f'"{rgba(c)}"' for c in r["border"] + (r["border"][0],))
    anim = {
        "none": 'hl.config({ animations = { enabled = false } })',
        "bouncy": '''hl.config({ animations = { enabled = true } })
hl.curve("glide", { type = "spring", mass = 1, stiffness = 170, dampening = 20 })
hl.animation({ leaf = "windows",     enabled = true, speed = 5, spring = "glide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, spring = "glide" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 5, bezier = "overshot",  style = "popin 60%" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5, bezier = "easeOutQuint", style = "slide" })''',
        "smooth": '''hl.config({ animations = { enabled = true } })
hl.animation({ leaf = "windows",     enabled = true, speed = 4, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 4, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 3, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5, bezier = "easeOutQuint", style = "slide" })''',
    }[r["anim"]]
    layers = "".join(f'hl.layer_rule({{ name = "glass-{n}", match = {{ namespace = "^{n}$" }}, blur = true, ignore_alpha = 0 }})\n'
                     for n in r.get("layers", ()))
    return f'''-- generated by ~/.config/rices/wardrobe.py, do not edit
hl.config({{
    general = {{
        gaps_in = {r["gaps_in"]}, gaps_out = {r["gaps_out"]}, border_size = {r["border_size"]},
        col = {{
            active_border   = {{ colors = {{ {b} }}, angle = 45 }},
            inactive_border = "{rgba(r["inactive"], "88")}",
        }},
    }},
    decoration = {{
        rounding = {r["rounding"]},
        blur = {{ enabled = true, xray = true, new_optimizations = true, size = {r["blur"][0]}, passes = {r["blur"][1]}, vibrancy = {0.4 if r.get("glass") else 0.17} }},
    }},
}})
{layers}{anim}
'''

def kitty_colors(r):
    p = r["pal"]
    c = lambda k: "#" + p[k]
    if r.get("mono_ansi"):
        A = dict(black="262626", red="d0d0d0", green="cfcfcf", yellow="dadada", blue="bcbcbc", magenta="c8c8c8", cyan="cccccc",
                 white="bdbdbd", bblack="444444", bwhite="ffffff")
    else:
        A = ANSI
    a = lambda k: "#" + A[k]
    return f"""# generated by ~/.config/rices/wardrobe.py
background_opacity {r["kitty_a"]}
foreground {c("text")}
selection_background {c("mauve")}
selection_foreground #000000
cursor {c("text")}
url_color {c("mauve")}
active_border_color {c("mauve")}
inactive_border_color {c("ov0")}
active_tab_background {c("mauve")}
active_tab_foreground #000000
inactive_tab_foreground {c("text")}
inactive_tab_background {c("mantle")}
tab_bar_background {c("crust")}
mark1_background {c("mauve")}
mark2_background {c("sub0")}
mark3_background {c("ov1")}
color0 {a("black")}
color8 {a("bblack")}
color1 {a("red")}
color9 {a("red")}
color2 {a("green")}
color10 {a("green")}
color3 {a("yellow")}
color11 {a("yellow")}
color4 {a("blue")}
color12 {a("blue")}
color5 {a("magenta")}
color13 {a("magenta")}
color6 {a("cyan")}
color14 {a("cyan")}
color7 {a("white")}
color15 {a("bwhite")}
"""

def bar_overlay(r):
    return f"""
/* wardrobe overlay */
.modules-left, .modules-center, .modules-right {{
    background: rgba(0, 0, 0, {r["bar_a"]});
    border-radius: {r["bar_r"]}px;
}}
#workspaces button {{ border-radius: {max(r["bar_r"] - 6, 0)}px; }}
{r.get("css", "")}"""

def pick_wall(name):
    wp = os.path.expanduser(RICES[name]["wall"])
    try:  # the wallpaper last picked with Super+W for this rice wins over its default
        last = (H / f".cache/wardrobe-wall-{name}").read_text().strip()
        if os.path.exists(last): wp = last
    except OSError: pass
    return wp

def apply(name, set_wall=True):
    wp = pick_wall(name)
    r = RICES[name]
    if r.get("dynamic"): r = dynamic_rice(r, wp)
    p = r["pal"]
    g = r.get("glass")
    base = lambda f: glassify((R / "base" / f).read_text(), g) if g else (R / "base" / f).read_text()
    write(C / "waybar/style.css", restyle(recolor(base("waybar.css"), p), r, bar=True) + bar_overlay(r))
    write(C / "wofi/style.css", restyle(recolor(base("wofi.css"), p), r))
    write(C / "wlogout/style.css", restyle(recolor(base("wlogout.css"), p), r))
    write(C / "swayosd/style.css", restyle(recolor(base("swayosd.css"), p), r))
    write(C / "dunst/dunstrc", restyle(recolor(base("dunstrc"), p), r))
    import json
    write(H / ".cache/rice-palette.json", json.dumps({"pal": p, "radius": r.get("radius", 1.0), "name": name}))
    write(C / "kitty/rice-colors.conf", kitty_colors(r))
    write(C / "hypr/rice.lua", lua(r))
    write(STATE, name + "\n")
    cur = H / ".cache/current-wallpaper"
    if set_wall and os.path.exists(wp):
        cur.parent.mkdir(parents=True, exist_ok=True)
        if cur.is_symlink() or cur.exists(): cur.unlink()
        cur.symlink_to(wp)
        try:
            subprocess.Popen(["awww", "img", wp, "--transition-type", "grow", "--transition-pos", "0.5,0.5", "--transition-duration", "1.2"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except FileNotFoundError:
            pass   # awww (the wallpaper tool) is not installed yet
    sh = lambda c: subprocess.run(c, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    sh("hyprctl reload")
    sh("pkill -USR1 -x kitty")
    sh("dunstctl reload")
    sh("pkill -x waybar")  # restart loop brings it back (never SIGUSR2, it crashes with mpris)
    sh(f"notify-send -t 2500 'Wardrobe' '{name}: {r['desc']}'")

def current():
    try: return STATE.read_text().strip()
    except OSError: return "noir"

def main():
    a = sys.argv[1:] or ["pick"]
    if a[0] == "list":
        for n in ORDER: print(("* " if n == current() else "  ") + f"{n:8} {RICES[n]['desc']}")
    elif a[0] == "current": print(current())
    elif a[0] == "apply": apply(a[1])
    elif a[0] == "retheme": apply(current(), set_wall=False)   # same rice, keep wallpaper (aurora re-derives colours)
    elif a[0] == "next":
        apply(ORDER[(ORDER.index(current()) + 1) % len(ORDER)] if current() in ORDER else ORDER[0])
    else:
        if subprocess.run("pkill -f '^python3 .*rices/picker\\.py'", shell=True).returncode == 0: return
        env = dict(os.environ, LD_PRELOAD="/usr/lib/libgtk4-layer-shell.so")
        subprocess.Popen(["python3", str(R / "picker.py")], env=env, start_new_session=True)

if __name__ == "__main__":
    main()
