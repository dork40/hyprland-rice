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

# bar_a: bar background alpha, anim: bouncy|smooth|none, kitty_a: terminal opacity, radius: scale for the css border-radii
RICES = {
    "noir": dict(wall="~/Pictures/wallpapers/noir/orbital-sunrise.jpg", desc="Catppuccin accents on black, floating rounded (original)",
        pal=pal(), border=("cba6f7", "f5c2e7", "89b4fa"), accent="b4befe", inactive="313244",
        rounding=11, gaps_in=1, gaps_out=3, border_size=0, blur=(5, 2), bar_r=16, bar_a=0.45, anim="bouncy", kitty_a=0.4,
        radius=0.9, layers=("waybar",), blur_alpha=0.2),
    "liquid": dict(wall="~/Pictures/wallpapers/liquid/liquid-plasma.jpg", desc="Liquid glass: frosted see-through panels, heavy blur, big soft corners",
        pal=pal(rosewater="ffffff", pink="e6d6ff", mauve="c9b8ff", red="ff9bb3", peach="ffd2a8", yellow="fff1b8",
                green="b8f5d0", teal="a8f0ee", sky="bfe9ff", blue="9fd0ff", lavender="dbe9ff", text="f4f8ff",
                sub1="dbe3f2", sub0="c2cce0", ov2="a7b3cc", ov1="8f9bb5", ov0="7380a0", s2="4d587a", s1="2f3856",
                mantle="0b0e18", crust="000000", base="000000"),
        border=("ffffff", "bfe9ff", "e6d6ff"), accent="dbe9ff", inactive="5d6a8a",
        rounding=15, gaps_in=3, gaps_out=7, border_size=1, blur=(12, 4), bar_r=15, bar_a=0.25, anim="smooth", kitty_a=0.3,
        radius=1.15, glass=0.35, layers=("waybar", "notifications", "logout_dialog", "swayosd")),
    "mono": dict(wall="~/Pictures/wallpapers/mono/saturn-grey.jpg", desc="Pure greyscale, flat and instant, no animations",
        pal=pal(rosewater="ffffff", pink="e0e0e0", mauve="d0d0d0", red="ffffff", peach="c8c8c8", yellow="f0f0f0",
                green="dcdcdc", teal="cccccc", sky="d8d8d8", blue="bcbcbc", lavender="ffffff", text="e6e6e6",
                sub1="cfcfcf", sub0="b5b5b5", ov2="9a9a9a", ov1="808080", ov0="666666", s2="444444", s1="2a2a2a",
                mantle="0c0c0c", crust="000000", base="000000"),
        border=("ffffff", "9a9a9a", "ffffff"), accent="ffffff", inactive="2a2a2a",
        rounding=0, gaps_in=0, gaps_out=0, border_size=1, blur=(3, 1), bar_r=0, bar_a=1.0, anim="none", kitty_a=0.9, radius=0),
}
RICES["aurora"] = dict(wall="~/Pictures/wallpapers/aurora/earth-limb.jpg", dynamic=True,
    desc="Colours pulled from the wallpaper (matugen) on a black base",
    pal=pal(), border=("cba6f7", "f5c2e7", "89b4fa"), accent="b4befe", inactive="313244",
    rounding=9, gaps_in=2, gaps_out=6, border_size=2, blur=(8, 3), bar_r=11, bar_a=0.6, anim="smooth", kitty_a=0.4, radius=0.8)
RICES["ml4w"] = dict(wall="~/Pictures/wallpapers/aurora/earth-limb.jpg",
    desc="ML4W look: teal Material You colours, soft gradient border, roomy gaps",
    pal=pal(mauve="81d5cd", lavender="81d5cd", blue="b0ccc8", sky="b0ccc8", teal="afc9e7", pink="afc9e7", rosewater="9df2e9",
            text="dde4e2", sub1="bec9c6", sub0="bec9c6", ov2="899391", ov1="899391", ov0="3f4947",
            s2="2f3736", s1="232b2a", mantle="0a0f0e", crust="000000", base="0e1514"),
    border=("81d5cd", "003734"), accent="81d5cd", inactive="3f4947", angle=90,
    rounding=10, gaps_in=10, gaps_out=16, border_size=2, blur=(4, 4), bar_r=16, bar_a=0.8, anim="ml4w", kitty_a=0.85, radius=1.0)
ORDER = list(RICES)

def dynamic_rice(r, wp):
    """Derive the palette, borders and accent from the wallpaper with matugen."""
    try:
        out = subprocess.run(["matugen", "image", wp, "--dry-run", "--json", "hex", "-m", "dark", "--prefer", "saturation"],
                             capture_output=True, text=True, timeout=20, check=True).stdout
        import json
        c = {k: v["dark"]["color"].lstrip("#") for k, v in json.loads(out)["colors"].items()}
    except Exception:
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
    return re.sub(r"#([0-9a-fA-F]{6})", lambda x: "#" + m.get(x.group(1).lower(), x.group(1)), text)

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
        "ml4w": '''hl.config({ animations = { enabled = true } })
hl.curve("md3_decel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("md3_accel", { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
hl.curve("menu_decel", { type = "bezier", points = { {0.1, 1}, {0, 1} } })
hl.curve("menu_accel", { type = "bezier", points = { {0.38, 0.04}, {1, 0.07} } })
hl.animation({ leaf = "windows",     enabled = true, speed = 3, bezier = "md3_decel", style = "popin 60%" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 3, bezier = "md3_decel", style = "popin 60%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3, bezier = "md3_accel", style = "popin 60%" })
hl.animation({ leaf = "fade",        enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 3, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 1.6, bezier = "menu_accel" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 7, bezier = "menu_decel", style = "slide" })''',
        "smooth": '''hl.config({ animations = { enabled = true } })
hl.animation({ leaf = "windows",     enabled = true, speed = 4, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 4, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 3, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5, bezier = "easeOutQuint", style = "slide" })''',
    }[r["anim"]]
    ia = r.get("blur_alpha", 0)
    layers = "".join(f'hl.layer_rule({{ name = "glass-{n}", match = {{ namespace = "^{n}$" }}, blur = true, ignore_alpha = {ia} }})\n'
                     for n in r.get("layers", ()))
    return f'''-- generated by ~/.config/rices/wardrobe.py, do not edit
hl.config({{
    general = {{
        gaps_in = {r["gaps_in"]}, gaps_out = {r["gaps_out"]}, border_size = {r["border_size"]},
        col = {{
            active_border   = {{ colors = {{ {b} }}, angle = {r.get('angle', 45)} }},
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
    return f"""# generated by ~/.config/rices/wardrobe.py
background_opacity {r["kitty_a"]}
foreground {c("text")}
selection_background {c("rosewater")}
cursor {c("rosewater")}
url_color {c("rosewater")}
active_border_color {c("lavender")}
inactive_border_color {c("ov0")}
active_tab_background {c("mauve")}
inactive_tab_foreground {c("text")}
inactive_tab_background {c("mantle")}
tab_bar_background {c("crust")}
mark1_background {c("lavender")}
mark2_background {c("mauve")}
mark3_background {c("sky")}
color0 {c("s1")}
color8 {c("s2")}
color1 {c("red")}
color9 {c("red")}
color2 {c("green")}
color10 {c("green")}
color3 {c("yellow")}
color11 {c("yellow")}
color4 {c("blue")}
color12 {c("blue")}
color5 {c("pink")}
color13 {c("pink")}
color6 {c("teal")}
color14 {c("teal")}
color7 {c("sub1")}
color15 {c("sub0")}
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
