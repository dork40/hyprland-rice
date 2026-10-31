#!/usr/bin/env python3
"""Displays: set resolution, refresh rate, scale, rotation and arrangement of one or many monitors.
Apply shows a 15 second "keep these settings?" countdown (reverts on its own, so you can never lock yourself out).
Keep saves to ~/.config/hypr/monitors.lua, which hyprland.lua loads at startup."""
import copy, json, os, pathlib, re, subprocess, sys

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

CONF = pathlib.Path.home() / ".config/hypr/monitors.lua"
SCALES = ["1", "1.25", "1.5", "1.75", "2", "2.5", "3"]
ROTATIONS = [("Normal", 0), ("90°", 1), ("180°", 2), ("270°", 3)]
CONFIRM_SECS = 15


# ---------- pure logic (no GTK), so it can be tested ----------
def parse_modes(modes):
    """['1920x1200@165.01Hz', ...] -> {(1920, 1200): ['165.01', ...]} with highest refresh first"""
    out = {}
    for m in modes:
        mm = re.match(r"(\d+)x(\d+)@([\d.]+)Hz", m)
        if mm:
            out.setdefault((int(mm[1]), int(mm[2])), []).append(mm[3])
    for k in out:
        out[k] = sorted(set(out[k]), key=lambda r: -float(r))
    return out


def load_monitors(raw=None):
    if raw is None:
        raw = json.loads(subprocess.run(["hyprctl", "monitors", "all", "-j"], capture_output=True, text=True).stdout or "[]")
    mons = []
    for m in raw:
        modes = parse_modes(m.get("availableModes", []))
        rate = f"{m['refreshRate']:.2f}"
        # snap the current rate to the matching listed mode ("165.015" -> "165.01")
        key = (m["width"], m["height"])
        if key in modes:
            rate = min(modes[key], key=lambda r: abs(float(r) - m["refreshRate"]))
        mons.append(dict(name=m["name"], desc=m.get("description", ""), modes=modes, w=m["width"], h=m["height"],
                         rate=rate, x=m["x"], y=m["y"], scale=("%g" % m["scale"]), transform=m.get("transform", 0),
                         enabled=not m.get("disabled", False),
                         mirror=(m.get("mirrorOf") if m.get("mirrorOf") not in (None, "none") else "")))
    return mons


def logical_size(m):
    w, h = m["w"], m["h"]
    if m["transform"] % 2:
        w, h = h, w
    s = float(m["scale"]) or 1.0
    return w / s, h / s


def monitor_lua(m):
    if not m["enabled"]:
        return f'hl.monitor({{ output = "{m["name"]}", disabled = true }})'
    parts = [f'output = "{m["name"]}"', f'mode = "{m["w"]}x{m["h"]}@{m["rate"]}"',
             f'position = "{int(m["x"])}x{int(m["y"])}"', f'scale = {float(m["scale"]):g}']
    if m["transform"]:
        parts.append(f'transform = {m["transform"]}')
    if m["mirror"]:
        parts.append(f'mirror = "{m["mirror"]}"')
    return "hl.monitor({ " + ", ".join(parts) + " })"


def build_lua(mons):
    return "\n".join(monitor_lua(m) for m in mons)


def snap(m, others, threshold=60):
    """Snap monitor m's position to touch the nearest edge of another monitor (in layout units)."""
    w, h = logical_size(m)
    best = None
    for o in others:
        if not o["enabled"]:
            continue
        ow, oh = logical_size(o)
        for nx in (o["x"] + ow, o["x"] - w, o["x"], o["x"] + ow - w):
            for ny in (o["y"], o["y"] + oh - h, o["y"] + oh, o["y"] - h):
                # only keep candidates that touch (share an edge) without overlapping
                touch_x = nx in (o["x"] + ow, o["x"] - w)
                touch_y = ny in (o["y"] + oh, o["y"] - h)
                if touch_x == touch_y:
                    continue
                d = abs(nx - m["x"]) + abs(ny - m["y"])
                if d < threshold * 2 and (best is None or d < best[0]):
                    best = (d, nx, ny)
    if best:
        m["x"], m["y"] = int(best[1]), int(best[2])


def place(m, ref, where):
    w, h = logical_size(m)
    rw, rh = logical_size(ref)
    if where == "right":
        m["x"], m["y"] = int(ref["x"] + rw), int(ref["y"])
    elif where == "left":
        m["x"], m["y"] = int(ref["x"] - w), int(ref["y"])
    elif where == "above":
        m["x"], m["y"] = int(ref["x"]), int(ref["y"] - h)
    elif where == "below":
        m["x"], m["y"] = int(ref["x"]), int(ref["y"] + rh)


def normalise(mons):
    """Shift so the top-left of the enabled monitors is 0x0 (keeps relative layout)."""
    en = [m for m in mons if m["enabled"]]
    if not en:
        return
    dx, dy = min(m["x"] for m in en), min(m["y"] for m in en)
    for m in en:
        m["x"], m["y"] = int(m["x"] - dx), int(m["y"] - dy)


def apply_live(mons):
    code = build_lua(mons)
    r = subprocess.run(["hyprctl", "eval", code], capture_output=True, text=True)
    return r.returncode == 0 and "error" not in (r.stdout + r.stderr).lower()


def save(mons):
    CONF.parent.mkdir(parents=True, exist_ok=True)
    CONF.write_text("-- written by the Displays app (~/.config/rices/displays.py), do not edit by hand\n" + build_lua(mons) + "\n")


# ---------- GTK app ----------
CSS = b"""
window { background: #000000; color: #cdd6f4; font-family: "JetBrainsMono Nerd Font", sans-serif; }
.title { font-size: 20px; font-weight: bold; }
.hint { color: #6c7086; font-size: 12px; }
.panel { background: #0b0b10; border-radius: 14px; padding: 16px; }
button { background: #16161f; color: #cdd6f4; border: 1px solid #313244; border-radius: 8px; padding: 6px 12px; }
button:hover { border-color: #cba6f7; }
button.suggested-action { background: #cba6f7; color: #11111b; border-color: #cba6f7; font-weight: bold; }
dropdown, dropdown button { background: #16161f; color: #cdd6f4; }
label.name { font-weight: bold; color: #b4befe; font-size: 15px; }
"""


class Displays(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.rice.Displays")
        self.mons = []
        self.sel = 0
        self.committed = []     # last state known to be good (for revert)
        self.updating = False

    def do_activate(self):
        css = Gtk.CssProvider(); css.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_USER)
        self.win = Gtk.ApplicationWindow(application=self, title="Displays", default_width=980, default_height=620)
        self.win.set_child(self.build())
        self.reload()
        self.win.present()

    # --- layout ---
    def build(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14, margin_top=18, margin_bottom=18, margin_start=20, margin_end=20)
        head = Gtk.Box(spacing=10)
        head.append(Gtk.Label(label="󰍹  Displays", css_classes=["title"], hexpand=True, xalign=0))
        head.append(Gtk.Label(label="drag a screen to arrange · Apply asks you to confirm", css_classes=["hint"]))
        root.append(head)

        body = Gtk.Box(spacing=16, vexpand=True)
        self.canvas = Gtk.DrawingArea(hexpand=True, vexpand=True, css_classes=["panel"])
        self.canvas.set_draw_func(self.draw)
        drag = Gtk.GestureDrag()
        drag.connect("drag-begin", self.on_drag_begin); drag.connect("drag-update", self.on_drag_update)
        drag.connect("drag-end", self.on_drag_end)
        self.canvas.add_controller(drag)
        body.append(self.canvas)

        side = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, css_classes=["panel"], width_request=300)
        self.lbl_name = Gtk.Label(label="", css_classes=["name"], xalign=0)
        self.lbl_desc = Gtk.Label(label="", css_classes=["hint"], xalign=0, wrap=True)
        side.append(self.lbl_name); side.append(self.lbl_desc)
        self.sw_enabled = Gtk.Switch(halign=Gtk.Align.START)
        self.sw_enabled.connect("notify::active", self.on_enabled)
        self.dd_res = self.row(side, "Resolution", self.on_res)
        self.dd_rate = self.row(side, "Refresh rate", self.on_rate)
        self.dd_scale = self.row(side, "Scale", self.on_scale)
        self.dd_rot = self.row(side, "Rotation", self.on_rot)
        self.dd_mirror = self.row(side, "Mirror of", self.on_mirror)
        r = Gtk.Box(spacing=8); r.append(Gtk.Label(label="Enabled", hexpand=True, xalign=0)); r.append(self.sw_enabled); side.append(r)

        side.append(Gtk.Label(label="Place next to", css_classes=["hint"], xalign=0, margin_top=6))
        self.dd_ref = Gtk.DropDown.new_from_strings([""]); side.append(self.dd_ref)
        pb = Gtk.Box(spacing=6, homogeneous=True)
        for label, where in (("◀", "left"), ("▶", "right"), ("▲", "above"), ("▼", "below")):
            b = Gtk.Button(label=label); b.connect("clicked", self.on_place, where); pb.append(b)
        side.append(pb)
        body.append(side)
        root.append(body)

        foot = Gtk.Box(spacing=8)
        foot.append(Gtk.Box(hexpand=True))
        b_reset = Gtk.Button(label="Reset"); b_reset.connect("clicked", lambda *_: self.reload()); foot.append(b_reset)
        b_apply = Gtk.Button(label="Apply", css_classes=["suggested-action"]); b_apply.connect("clicked", self.on_apply); foot.append(b_apply)
        root.append(foot)
        return root

    def row(self, parent, text, cb):
        parent.append(Gtk.Label(label=text, css_classes=["hint"], xalign=0))
        dd = Gtk.DropDown.new_from_strings([""])
        dd.connect("notify::selected", cb)
        parent.append(dd)
        return dd

    def strings(self, dd, items, selected=0):
        self.updating = True
        dd.set_model(Gtk.StringList.new(items))
        dd.set_selected(max(0, min(selected, len(items) - 1)))
        self.updating = False

    # --- state ---
    def reload(self):
        self.mons = load_monitors()
        self.committed = copy.deepcopy(self.mons)
        self.sel = 0
        self.refresh_side()
        self.canvas.queue_draw()

    def cur(self):
        return self.mons[self.sel] if self.mons else None

    def refresh_side(self):
        m = self.cur()
        if not m:
            return
        self.lbl_name.set_label(m["name"]); self.lbl_desc.set_label(m["desc"])
        self.updating = True; self.sw_enabled.set_active(m["enabled"]); self.updating = False
        resl = sorted(m["modes"], key=lambda k: -(k[0] * k[1]))
        if (m["w"], m["h"]) not in resl:
            resl.insert(0, (m["w"], m["h"]))
        self.res_list = resl
        self.strings(self.dd_res, [f"{w} × {h}" for w, h in resl], resl.index((m["w"], m["h"])))
        self.fill_rates()
        sc = SCALES if m["scale"] in SCALES else [m["scale"]] + SCALES
        self.scale_list = sc
        self.strings(self.dd_scale, sc, sc.index(m["scale"]))
        self.strings(self.dd_rot, [n for n, _ in ROTATIONS], m["transform"] if m["transform"] < 4 else 0)
        others = [o["name"] for i, o in enumerate(self.mons) if i != self.sel]
        self.mirror_list = [""] + others
        self.strings(self.dd_mirror, ["Off"] + others, self.mirror_list.index(m["mirror"]) if m["mirror"] in self.mirror_list else 0)
        self.ref_list = others
        self.strings(self.dd_ref, others or ["(only one screen)"], 0)

    def fill_rates(self):
        m = self.cur()
        rates = m["modes"].get((m["w"], m["h"]), [m["rate"]])
        if m["rate"] not in rates:
            rates = [m["rate"]] + rates
        self.rate_list = rates
        self.strings(self.dd_rate, [f"{float(r):g} Hz" for r in rates], rates.index(m["rate"]))

    # --- callbacks ---
    def on_enabled(self, sw, _p):
        if self.updating or not self.cur():
            return
        self.cur()["enabled"] = sw.get_active(); self.canvas.queue_draw()

    def on_res(self, dd, _p):
        if self.updating or not self.cur():
            return
        m = self.cur(); m["w"], m["h"] = self.res_list[dd.get_selected()]
        rates = m["modes"].get((m["w"], m["h"]))
        if rates:
            m["rate"] = rates[0]
        self.fill_rates(); self.canvas.queue_draw()

    def on_rate(self, dd, _p):
        if self.updating or not self.cur():
            return
        self.cur()["rate"] = self.rate_list[dd.get_selected()]

    def on_scale(self, dd, _p):
        if self.updating or not self.cur():
            return
        self.cur()["scale"] = self.scale_list[dd.get_selected()]; self.canvas.queue_draw()

    def on_rot(self, dd, _p):
        if self.updating or not self.cur():
            return
        self.cur()["transform"] = ROTATIONS[dd.get_selected()][1]; self.canvas.queue_draw()

    def on_mirror(self, dd, _p):
        if self.updating or not self.cur():
            return
        self.cur()["mirror"] = self.mirror_list[dd.get_selected()]; self.canvas.queue_draw()

    def on_place(self, _b, where):
        if not self.cur() or not self.ref_list:
            return
        ref = next(o for o in self.mons if o["name"] == self.ref_list[self.dd_ref.get_selected()])
        place(self.cur(), ref, where); self.canvas.queue_draw()

    # --- canvas ---
    def geometry(self, width, height):
        en = [m for m in self.mons if m["enabled"] and not m["mirror"]] or self.mons
        if not en:
            return 1, 0, 0
        x0 = min(m["x"] for m in en); y0 = min(m["y"] for m in en)
        x1 = max(m["x"] + logical_size(m)[0] for m in en); y1 = max(m["y"] + logical_size(m)[1] for m in en)
        pad = 50
        s = min((width - 2 * pad) / max(x1 - x0, 1), (height - 2 * pad) / max(y1 - y0, 1), 0.5)
        ox = (width - (x1 - x0) * s) / 2 - x0 * s
        oy = (height - (y1 - y0) * s) / 2 - y0 * s
        return s, ox, oy

    def draw(self, _area, cr, width, height):
        s, ox, oy = self.geometry(width, height)
        for i, m in enumerate(self.mons):
            if not m["enabled"]:
                continue
            w, h = logical_size(m)
            x, y = ox + m["x"] * s, oy + m["y"] * s
            cr.rectangle(x, y, w * s, h * s)
            cr.set_source_rgba(0.80, 0.65, 0.97, 0.22 if i == self.sel else 0.10); cr.fill_preserve()
            cr.set_source_rgb(*( (0.80, 0.65, 0.97) if i == self.sel else (0.42, 0.44, 0.53) )); cr.set_line_width(2.5 if i == self.sel else 1.5); cr.stroke()
            cr.set_source_rgb(0.8, 0.84, 0.96); cr.select_font_face("JetBrainsMono Nerd Font"); cr.set_font_size(14)
            cr.move_to(x + 10, y + 22); cr.show_text(m["name"])
            cr.set_font_size(11); cr.set_source_rgb(0.65, 0.68, 0.78)
            cr.move_to(x + 10, y + 40); cr.show_text(f'{m["w"]}×{m["h"]} · {float(m["rate"]):g}Hz')
            if m["mirror"]:
                cr.move_to(x + 10, y + 56); cr.show_text(f'mirrors {m["mirror"]}')

    def hit(self, px, py):
        s, ox, oy = self.geometry(self.canvas.get_width(), self.canvas.get_height())
        for i in reversed(range(len(self.mons))):
            m = self.mons[i]
            if not m["enabled"]:
                continue
            w, h = logical_size(m)
            if ox + m["x"] * s <= px <= ox + (m["x"] + w) * s and oy + m["y"] * s <= py <= oy + (m["y"] + h) * s:
                return i
        return None

    def on_drag_begin(self, _g, x, y):
        i = self.hit(x, y)
        self.dragging = i
        if i is not None:
            self.sel = i
            self.start = (self.mons[i]["x"], self.mons[i]["y"])
            self.refresh_side(); self.canvas.queue_draw()

    def on_drag_update(self, _g, dx, dy):
        if getattr(self, "dragging", None) is None:
            return
        s, _, _ = self.geometry(self.canvas.get_width(), self.canvas.get_height())
        m = self.mons[self.dragging]
        m["x"], m["y"] = int(self.start[0] + dx / s), int(self.start[1] + dy / s)
        self.canvas.queue_draw()

    def on_drag_end(self, _g, dx, dy):
        if getattr(self, "dragging", None) is None:
            return
        m = self.mons[self.dragging]
        snap(m, [o for o in self.mons if o is not m])
        self.dragging = None; self.canvas.queue_draw()

    # --- apply / confirm / revert ---
    def on_apply(self, _b):
        normalise(self.mons)
        if not apply_live(self.mons):
            self.toast("Hyprland refused that layout. Nothing was saved.")
            apply_live(self.committed)
            return
        self.confirm()

    def toast(self, text):
        d = Gtk.AlertDialog(); d.set_message(text); d.show(self.win)

    def confirm(self):
        self.left = CONFIRM_SECS
        self.dlg = Gtk.Window(title="Keep these settings?", transient_for=self.win, modal=True, resizable=False)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14, margin_top=20, margin_bottom=20, margin_start=24, margin_end=24)
        self.lbl_left = Gtk.Label(label=f"Reverting in {self.left} seconds", css_classes=["title"])
        box.append(self.lbl_left)
        box.append(Gtk.Label(label="If you can see this, the new settings work.", css_classes=["hint"]))
        row = Gtk.Box(spacing=8, homogeneous=True)
        b_rev = Gtk.Button(label="Revert"); b_rev.connect("clicked", lambda *_: self.finish(False))
        b_keep = Gtk.Button(label="Keep", css_classes=["suggested-action"]); b_keep.connect("clicked", lambda *_: self.finish(True))
        row.append(b_rev); row.append(b_keep); box.append(row)
        self.dlg.set_child(box); self.dlg.connect("close-request", lambda *_: (self.finish(False), True)[1])
        self.dlg.present()
        self.timer = GLib.timeout_add_seconds(1, self.tick)

    def tick(self):
        self.left -= 1
        if self.left <= 0:
            self.finish(False); return False
        self.lbl_left.set_label(f"Reverting in {self.left} seconds")
        return True

    def finish(self, keep):
        if getattr(self, "timer", None):
            GLib.source_remove(self.timer); self.timer = None
        if getattr(self, "dlg", None):
            d, self.dlg = self.dlg, None; d.destroy()
        else:
            return
        if keep:
            save(self.mons); self.committed = copy.deepcopy(self.mons)
        else:
            apply_live(self.committed); self.mons = copy.deepcopy(self.committed)
            self.refresh_side(); self.canvas.queue_draw()


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--print":   # headless: show the Lua for the current layout
        print(build_lua(load_monitors()))
    else:
        sys.exit(Displays().run([]))
