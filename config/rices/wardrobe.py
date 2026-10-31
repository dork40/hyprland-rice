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

# bar_a: bar background alpha, anim: bouncy|smooth|none, kitty_a: terminal opacity
RICES = {
    "noir": dict(wall="~/Pictures/wallpapers/noir/orbital-sunrise.jpg", desc="Catppuccin accents on black, floating rounded (original)",
        pal=pal(), border=("cba6f7", "f5c2e7", "89b4fa"), accent="b4befe", inactive="313244",
        rounding=6, gaps_in=2, gaps_out=6, border_size=0, blur=(5, 2), bar_r=18, bar_a=0.88, anim="bouncy", kitty_a=0.4),
    "liquid": dict(wall="~/Pictures/wallpapers/liquid/liquid-plasma.jpg", desc="Liquid glass: frosted see-through panels, heavy blur, big soft corners",
        pal=pal(rosewater="ffffff", pink="e6d6ff", mauve="c9b8ff", red="ff9bb3", peach="ffd2a8", yellow="fff1b8",
                green="b8f5d0", teal="a8f0ee", sky="bfe9ff", blue="9fd0ff", lavender="dbe9ff", text="f4f8ff",
                sub1="dbe3f2", sub0="c2cce0", ov2="a7b3cc", ov1="8f9bb5", ov0="7380a0", s2="4d587a", s1="2f3856",
                mantle="0b0e18", crust="000000", base="000000"),
        border=("ffffff", "bfe9ff", "e6d6ff"), accent="dbe9ff", inactive="5d6a8a",
        rounding=12, gaps_in=6, gaps_out=14, border_size=1, blur=(12, 4), bar_r=14, bar_a=0.25, anim="smooth", kitty_a=0.3,
        glass=0.35, layers=("waybar", "notifications", "logout_dialog", "swayosd")),
    "mono": dict(wall="~/Pictures/wallpapers/mono/saturn-grey.jpg", desc="Pure greyscale, flat and instant, no animations",
        pal=pal(rosewater="ffffff", pink="e0e0e0", mauve="d0d0d0", red="ffffff", peach="c8c8c8", yellow="f0f0f0",
                green="dcdcdc", teal="cccccc", sky="d8d8d8", blue="bcbcbc", lavender="ffffff", text="e6e6e6",
                sub1="cfcfcf", sub0="b5b5b5", ov2="9a9a9a", ov1="808080", ov0="666666", s2="444444", s1="2a2a2a",
                mantle="0c0c0c", crust="000000", base="000000"),
        border=("ffffff", "9a9a9a", "ffffff"), accent="ffffff", inactive="2a2a2a",
        rounding=0, gaps_in=0, gaps_out=0, border_size=1, blur=(3, 1), bar_r=0, bar_a=1.0, anim="none", kitty_a=0.9),
}
ORDER = list(RICES)

def recolor(text, p):
    text = text.replace("@HOME@", str(H))
    m = {v: p[k] for k, v in KEYS.items()}
    return re.sub(r"#([0-9a-fA-F]{6})", lambda x: "#" + m.get(x.group(1).lower(), x.group(1)), text)

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

def apply(name):
    r = RICES[name]; p = r["pal"]
    g = r.get("glass")
    base = lambda f: glassify((R / "base" / f).read_text(), g) if g else (R / "base" / f).read_text()
    write(C / "waybar/style.css", recolor(base("waybar.css"), p) + bar_overlay(r))
    write(C / "wofi/style.css", recolor(base("wofi.css"), p))
    write(C / "wlogout/style.css", recolor(base("wlogout.css"), p))
    write(C / "swayosd/style.css", recolor(base("swayosd.css"), p))
    write(C / "dunst/dunstrc", recolor(base("dunstrc"), p))
    write(C / "kitty/rice-colors.conf", kitty_colors(r))
    write(C / "hypr/rice.lua", lua(r))
    write(STATE, name + "\n")
    wp = os.path.expanduser(r["wall"])
    try:  # the wallpaper last picked with Super+W for this rice wins over its default
        last = (H / f".cache/wardrobe-wall-{name}").read_text().strip()
        if os.path.exists(last): wp = last
    except OSError: pass
    cur = H / ".cache/current-wallpaper"
    if os.path.exists(wp):
        cur.parent.mkdir(parents=True, exist_ok=True)
        if cur.is_symlink() or cur.exists(): cur.unlink()
        cur.symlink_to(wp)
        subprocess.Popen(["awww", "img", wp, "--transition-type", "grow", "--transition-pos", "0.5,0.5", "--transition-duration", "1.2"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
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
    elif a[0] == "next":
        apply(ORDER[(ORDER.index(current()) + 1) % len(ORDER)] if current() in ORDER else ORDER[0])
    else:
        if subprocess.run("pkill -f '^python3 .*rices/picker\\.py'", shell=True).returncode == 0: return
        env = dict(os.environ, LD_PRELOAD="/usr/lib/libgtk4-layer-shell.so")
        subprocess.Popen(["python3", str(R / "picker.py")], env=env, start_new_session=True)

if __name__ == "__main__":
    main()
