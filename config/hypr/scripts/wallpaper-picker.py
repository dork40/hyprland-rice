#!/usr/bin/env python3
# Super+W wallpaper picker (shows only the current rice's wallpapers): a grid of big previews over a dimmed screen.
# Click a wallpaper (or arrows + Enter) to switch to it; Esc or a click outside closes it.
import os
import subprocess
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, Gtk, Gtk4LayerShell as LayerShell  # noqa: E402

RICE = open(os.path.expanduser("~/.config/rices/current")).read().strip() if os.path.exists(os.path.expanduser("~/.config/rices/current")) else "noir"
WALLS = os.path.expanduser("~/Pictures/wallpapers/" + RICE)  # each rice has its own wallpaper folder
if not os.path.isdir(WALLS):
    WALLS = os.path.expanduser("~/Pictures/wallpapers")
THUMBS = os.path.expanduser("~/.cache/wallpaper-thumbs")
CURRENT = os.path.expanduser("~/.cache/current-wallpaper")
EXTS = (".png", ".jpg", ".jpeg", ".webp", ".gif")
THUMB_W, THUMB_H = 400, 250

sys.path.insert(0, os.path.expanduser('~/.config/rices'))
import popup_anim  # noqa: E402
CSS = b"""
window { background: rgba(0, 0, 0, 0.7); }
.panel {
    background: #000000;
    border: 2px solid rgba(203, 166, 247, 0.45);
    border-radius: 22px;
    padding: 22px 26px 26px 26px;
}
.title { color: #cdd6f4; font-family: "JetBrainsMono Nerd Font"; font-size: 20px; font-weight: bold; }
.hint  { color: #6c7086; font-family: "JetBrainsMono Nerd Font"; font-size: 12px; }
flowbox { background: transparent; }
flowboxchild { padding: 0; border-radius: 16px; outline: none; }
.card {
    background: #0b0b10;
    border: 3px solid transparent;
    border-radius: 16px;
    padding: 8px 8px 10px 8px;
    transition: all 150ms ease;
}
.card picture { border-radius: 10px; }
.card label { color: #a6adc8; font-family: "JetBrainsMono Nerd Font"; font-size: 12px; margin-top: 8px; }
.card.current { border-color: rgba(137, 180, 250, 0.7); }
flowboxchild:hover .card, flowboxchild:selected .card, flowboxchild:focus .card {
    background: #16161f;
    border-color: #cba6f7;
}
flowboxchild:hover .card label, flowboxchild:selected .card label { color: #cba6f7; }
scrollbar { opacity: 0; }
"""


def pretty(name):
    label = os.path.splitext(name)[0].replace("_", " ").replace("-", " ")
    return label[2:] if label.startswith("a ") else label


def thumbnail(path):
    os.makedirs(THUMBS, exist_ok=True)
    thumb = os.path.join(THUMBS, os.path.splitext(os.path.basename(path))[0] + "-lg.png")
    if not os.path.exists(thumb) or os.path.getmtime(thumb) < os.path.getmtime(path):
        subprocess.run(
            ["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-frames:v", "1", "-vf",
             f"scale={THUMB_W * 2}:{THUMB_H * 2}:force_original_aspect_ratio=increase,"
             f"crop={THUMB_W * 2}:{THUMB_H * 2}", thumb],
            check=False,
        )
    return thumb


def set_wallpaper(path):
    subprocess.Popen(
        ["awww", "img", path, "--transition-type", "grow", "--transition-pos", "0.5,0.5",
         "--transition-duration", "1.2", "--transition-fps", "120"],
        start_new_session=True,
    )
    if os.path.lexists(CURRENT):
        os.remove(CURRENT)
    os.symlink(path, CURRENT)
    with open(os.path.expanduser(f"~/.cache/wardrobe-wall-{RICE}"), "w") as f:  # remembered per rice
        f.write(path)
    if RICE == "aurora":  # colours follow the wallpaper
        subprocess.Popen(["python3", os.path.expanduser("~/.config/rices/wardrobe.py"), "retheme"], start_new_session=True)


class Picker(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.rice.WallpaperPicker")

    def close_anim(self):
        if self._closing: return
        self._closing = True
        popup_anim.animate_out(self._win, self._panel, self.quit)

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        LayerShell.init_for_window(win)
        LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
        LayerShell.set_namespace(win, "wallpaper-picker")
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.EXCLUSIVE)
        for edge in (LayerShell.Edge.TOP, LayerShell.Edge.BOTTOM, LayerShell.Edge.LEFT, LayerShell.Edge.RIGHT):
            LayerShell.set_anchor(win, edge, True)

        css = Gtk.CssProvider()
        css.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_USER)

        current = os.path.realpath(CURRENT) if os.path.exists(CURRENT) else ""
        files = sorted(f for f in os.listdir(WALLS) if f.lower().endswith(EXTS))

        grid = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.SINGLE, homogeneous=True,
                           min_children_per_line=3, max_children_per_line=3,
                           row_spacing=14, column_spacing=14, activate_on_single_click=True)
        grid.connect("child-activated", self.on_pick, win)
        select_me = None
        for name in files:
            path = os.path.join(WALLS, name)
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, css_classes=["card"])
            pic = Gtk.Picture.new_for_filename(thumbnail(path))
            pic.set_content_fit(Gtk.ContentFit.COVER)
            pic.set_size_request(THUMB_W, THUMB_H)
            card.append(pic)
            card.append(Gtk.Label(label=pretty(name), ellipsize=3, max_width_chars=40))
            child = Gtk.FlowBoxChild(child=card)
            child.path = path
            if os.path.realpath(path) == current:
                card.add_css_class("current")
                select_me = child
            grid.append(child)

        scroll = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER, vexpand=True)
        scroll.set_child(grid)
        scroll.set_size_request(3 * (THUMB_W + 22) + 2 * 14 + 4, 2 * (THUMB_H + 50) + 14 + 40)

        header = Gtk.Box(spacing=12, margin_bottom=16)
        header.append(Gtk.Label(label="󰸉  Wallpapers", css_classes=["title"], hexpand=True, xalign=0))
        header.append(Gtk.Label(label="click or Enter to apply · Esc to close", css_classes=["hint"]))

        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, css_classes=["panel"],
                        halign=Gtk.Align.CENTER, valign=Gtk.Align.CENTER)
        panel.append(header)
        panel.append(scroll)
        win.set_child(panel)
        self._win, self._panel, self._closing = win, panel, False

        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", lambda _c, key, _code, _state: key == Gdk.KEY_Escape and (self.close_anim() or True))
        win.add_controller(keys)

        # a click on the dimmed area outside the panel closes the picker
        click = Gtk.GestureClick()
        def outside(_g, _n, x, y):
            ok, rect = panel.compute_bounds(win)
            if ok and not (rect.origin.x <= x <= rect.origin.x + rect.size.width
                           and rect.origin.y <= y <= rect.origin.y + rect.size.height):
                self.close_anim()
        click.connect("pressed", outside)
        win.add_controller(click)

        win.present()
        popup_anim.animate_in(win, panel)
        first = select_me or grid.get_child_at_index(0)
        if first:
            grid.select_child(first)
            first.grab_focus()

    def on_pick(self, _grid, child, _win):
        set_wallpaper(child.path)
        self.close_anim()


if __name__ == "__main__":
    sys.exit(Picker().run([]))
