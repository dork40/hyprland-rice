#!/usr/bin/env python3
"""Welcome: a one-page "how do I use this?" for the rice. Opens once at first login (--first-run), any time with Super+F1."""
import pathlib, subprocess, sys

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, Gtk  # noqa: E402

MARKER = pathlib.Path.home() / ".local/state/rice-welcome-done"
HOME = pathlib.Path.home()

SECTIONS = [
    ("Open things", [
        ("Super + R", "App launcher: type a name, press Enter"),
        ("Super + Enter", "Terminal"),
        ("Super + `", "Drop-down terminal (press again to hide)"),
        ("Super + E", "Files"),
        ("Super + B", "Web browser"),
    ]),
    ("Windows", [
        ("Super + C", "Close the window"),
        ("Super + F", "Fullscreen"),
        ("Super + V", "Float / unfloat"),
        ("Super + Tab", "Window switcher"),
        ("Super + drag", "Left button moves, right button resizes"),
    ]),
    ("Workspaces", [
        ("Super + 1 to 9", "Go to workspace"),
        ("Super + Shift + 1 to 9", "Send the window there"),
        ("Super + scroll", "Next / previous workspace"),
    ]),
    ("AI assistants", [
        ("Super + Shift + Ctrl + 1 to 0", "Jump to Claude, Codex, Gemini, OpenCode, Aider, Ollama or the web chats"),
        ("Super + Shift + Ctrl + A", "Menu of every AI (opens it, or switches to it if it is already open)"),
    ]),
    ("Handy", [
        ("Print", "Screenshot an area (Shift: window, Ctrl: whole screen)"),
        ("Super + Shift + V", "Clipboard history"),
        ("Super + .", "Emoji picker"),
        ("Super + N", "Do not disturb"),
        ("Super + M", "Log out"),
    ]),
]

ACTIONS = [
    ("󰃟  Change style", "Super + Shift + R", [str(HOME / ".config/rices/wardrobe.py"), "pick"]),
    ("󰸉  Wallpapers", "Super + W", [str(HOME / ".config/hypr/scripts/wallpaper.sh")]),
    ("󰍹  Displays", "Super + Shift + D", [str(HOME / ".config/rices/displays.py")]),
    ("󰌌  All shortcuts", "Super + /", [str(HOME / ".config/hypr/scripts/keybinds.sh")]),
]

CSS = b"""
window { background: #000000; color: #cdd6f4; font-family: "JetBrainsMono Nerd Font", sans-serif; }
.title { font-size: 26px; font-weight: bold; }
.sub { color: #7f849c; font-size: 13px; }
.card { background: #0b0b10; border-radius: 14px; padding: 14px 16px; }
.card .head { color: #b4befe; font-weight: bold; font-size: 14px; margin-bottom: 4px; }
.key { background: #16161f; border: 1px solid #313244; border-radius: 6px; padding: 1px 8px; color: #cba6f7; font-size: 12px; }
.desc { color: #a6adc8; font-size: 12px; }
button { background: #16161f; color: #cdd6f4; border: 1px solid #313244; border-radius: 10px; padding: 8px 14px; }
button:hover { border-color: #cba6f7; }
button.suggested-action { background: #cba6f7; color: #11111b; border-color: #cba6f7; font-weight: bold; }
.small { color: #6c7086; font-size: 11px; }
"""


def launch(cmd):
    subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class Welcome(Gtk.Application):
    def __init__(self, first_run):
        super().__init__(application_id="dev.rice.Welcome")
        self.first_run = first_run

    def do_activate(self):
        if self.first_run and MARKER.exists():
            self.quit(); return
        css = Gtk.CssProvider(); css.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_USER)
        win = Gtk.ApplicationWindow(application=self, title="Welcome", default_width=860, default_height=700)
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14, margin_top=22, margin_bottom=18, margin_start=24, margin_end=24)
        root.append(Gtk.Label(label="Welcome", css_classes=["title"], xalign=0))
        root.append(Gtk.Label(label="The Super key is the Windows key. Everything below starts with it.", css_classes=["sub"], xalign=0))

        grid = Gtk.Grid(column_spacing=14, row_spacing=14, column_homogeneous=True)
        for i, (head, rows) in enumerate(SECTIONS):
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, css_classes=["card"])
            card.append(Gtk.Label(label=head, css_classes=["head"], xalign=0))
            for key, text in rows:
                r = Gtk.Box(spacing=10)
                k = Gtk.Label(label=key, css_classes=["key"], xalign=0, halign=Gtk.Align.START); k.set_size_request(150, -1)
                r.append(k)
                r.append(Gtk.Label(label=text, css_classes=["desc"], xalign=0, wrap=True, hexpand=True))
                card.append(r)
            grid.attach(card, i % 2, i // 2, 1, 1)
        root.append(grid)

        root.append(Gtk.Label(label="Make it yours", css_classes=["sub"], xalign=0, margin_top=4))
        bar = Gtk.Box(spacing=10, homogeneous=True)
        for label, hint, cmd in ACTIONS:
            b = Gtk.Button(); inner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            inner.append(Gtk.Label(label=label)); inner.append(Gtk.Label(label=hint, css_classes=["small"]))
            b.set_child(inner); b.connect("clicked", lambda _b, c=cmd: launch(c)); bar.append(b)
        root.append(bar)

        foot = Gtk.Box(spacing=10, margin_top=6)
        foot.append(Gtk.Label(label="Open this again any time with Super + F1", css_classes=["small"], hexpand=True, xalign=0))
        close = Gtk.Button(label="Got it", css_classes=["suggested-action"]); close.connect("clicked", lambda *_: win.close())
        foot.append(close); root.append(foot)

        win.set_child(root)
        win.present()
        MARKER.parent.mkdir(parents=True, exist_ok=True)
        MARKER.touch()   # first-run window shows once; Super+F1 always works


if __name__ == "__main__":
    sys.exit(Welcome("--first-run" in sys.argv).run([]))
