#!/usr/bin/env python3
# Wardrobe picker (Super+Shift+R): one big wallpaper card per rice. Click / Enter applies the rice and its wallpaper.
import os, subprocess, sys
import gi
gi.require_version("Gtk", "4.0"); gi.require_version("Gdk", "4.0"); gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, Gtk, Gtk4LayerShell as LayerShell  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wardrobe  # noqa: E402

THUMBS = os.path.expanduser("~/.cache/wallpaper-thumbs")
TW, TH = 380, 240
import popup_anim  # noqa: E402
CSS = b"""
window { background: rgba(0, 0, 0, 0.7); }
.panel { background: #000; border: 2px solid rgba(203,166,247,0.45); border-radius: 22px; padding: 22px 26px 26px 26px; }
.title { color: #cdd6f4; font-family: "JetBrainsMono Nerd Font"; font-size: 20px; font-weight: bold; }
.hint  { color: #6c7086; font-family: "JetBrainsMono Nerd Font"; font-size: 12px; }
flowbox, flowboxchild { background: transparent; outline: none; }
.card { background: #0b0b10; border: 3px solid transparent; border-radius: 16px; padding: 8px 8px 10px 8px; transition: all 150ms ease; }
.card picture { border-radius: 10px; }
.card .name { color: #cdd6f4; font-family: "JetBrainsMono Nerd Font"; font-size: 15px; font-weight: bold; margin-top: 8px; }
.card .desc { color: #7f849c; font-family: "JetBrainsMono Nerd Font"; font-size: 11px; }
.card.current { border-color: rgba(137,180,250,0.7); }
flowboxchild:hover .card, flowboxchild:selected .card, flowboxchild:focus .card { background: #16161f; border-color: #cba6f7; }
"""

def thumb(path):
    os.makedirs(THUMBS, exist_ok=True)
    t = os.path.join(THUMBS, os.path.splitext(os.path.basename(path))[0] + "-lg.png")
    if not os.path.exists(t):
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-frames:v", "1", "-vf",
                        "scale=800:500:force_original_aspect_ratio=increase,crop=800:500", t], check=False)
    return t

class Picker(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.rice.WardrobePicker")

    def close_anim(self):
        if self._closing: return
        self._closing = True
        popup_anim.animate_out(self._win, self._panel, self.quit)

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        LayerShell.init_for_window(win)
        LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
        LayerShell.set_namespace(win, "wardrobe-picker")
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.EXCLUSIVE)
        for e in (LayerShell.Edge.TOP, LayerShell.Edge.BOTTOM, LayerShell.Edge.LEFT, LayerShell.Edge.RIGHT):
            LayerShell.set_anchor(win, e, True)
        css = Gtk.CssProvider(); css.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_USER)

        grid = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.SINGLE, homogeneous=True, min_children_per_line=3,
                           max_children_per_line=3, row_spacing=14, column_spacing=14, activate_on_single_click=True)
        grid.connect("child-activated", lambda _g, c: (wardrobe.apply(c.rice), self.close_anim()))
        cur = wardrobe.current(); sel = None
        for name in wardrobe.ORDER:
            r = wardrobe.RICES[name]
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, css_classes=["card"])
            pic = Gtk.Picture.new_for_filename(thumb(os.path.expanduser(r["wall"])))
            pic.set_content_fit(Gtk.ContentFit.COVER); pic.set_size_request(TW, TH)
            card.append(pic)
            card.append(Gtk.Label(label=name, css_classes=["name"], xalign=0))
            card.append(Gtk.Label(label=r["desc"], css_classes=["desc"], xalign=0, wrap=True, max_width_chars=44))
            child = Gtk.FlowBoxChild(child=card); child.rice = name
            if name == cur: card.add_css_class("current"); sel = child
            grid.append(child)

        header = Gtk.Box(spacing=12, margin_bottom=16)
        header.append(Gtk.Label(label="󰃟  Wardrobe", css_classes=["title"], hexpand=True, xalign=0))
        header.append(Gtk.Label(label="click or Enter to apply · Esc to close", css_classes=["hint"]))
        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, css_classes=["panel"], halign=Gtk.Align.CENTER, valign=Gtk.Align.CENTER)
        panel.append(header); panel.append(grid)
        win.set_child(panel)
        self._win, self._panel, self._closing = win, panel, False

        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", lambda _c, k, _cd, _s: k == Gdk.KEY_Escape and (self.close_anim() or True))
        win.add_controller(keys)
        click = Gtk.GestureClick()
        def outside(_g, _n, x, y):
            ok, b = panel.compute_bounds(win)
            if ok and not (b.origin.x <= x <= b.origin.x + b.size.width and b.origin.y <= y <= b.origin.y + b.size.height):
                self.close_anim()
        click.connect("pressed", outside); win.add_controller(click)
        win.present()
        popup_anim.animate_in(win, panel)
        first = sel or grid.get_child_at_index(0)
        grid.select_child(first); first.grab_focus()

if __name__ == "__main__":
    sys.exit(Picker().run([]))
