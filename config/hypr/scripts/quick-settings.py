#!/usr/bin/env python3
# Quick settings popup: Wi-Fi, Bluetooth, volume, mic, brightness. Esc or click outside to close.
import json, os, signal, subprocess, re, sys, threading
from concurrent.futures import ThreadPoolExecutor
import gi
gi.require_version("Gtk", "4.0"); gi.require_version("Gdk", "4.0"); gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, GLib, Gtk, Gtk4LayerShell as LayerShell  # noqa: E402

CSS = b"""
window { background: transparent; }
.panel { background: #000; border: 2px solid rgba(203,166,247,0.45); border-radius: 20px; padding: 18px; min-width: 360px; }
label { color: #cdd6f4; font-family: "JetBrainsMono Nerd Font"; font-size: 14px; }
.title { font-size: 16px; font-weight: bold; }
.sub { color: #7f849c; font-size: 11px; }
.tile { background: #0b0b10; border: 2px solid transparent; border-radius: 14px; padding: 12px; }
.tile.on { background: #16161f; border-color: #cba6f7; }
.tile:hover { border-color: #89b4fa; }
.icon { font-size: 22px; }
.mini { padding: 7px 10px; border-radius: 12px; }
.item { background: #0b0b10; border: 2px solid transparent; border-radius: 12px; padding: 8px 12px; }
.item.on { background: #16161f; border-color: #cba6f7; }
.item:hover { border-color: #89b4fa; }
.dim { color: #6c7086; }
scale trough { background: #1c1c26; min-height: 8px; border-radius: 8px; }
scale highlight { background: #cba6f7; border-radius: 8px; }
scale slider { background: #cdd6f4; min-width: 16px; min-height: 16px; border-radius: 16px; }
"""

ENV = {k: v for k, v in os.environ.items() if k != "LD_PRELOAD"}   # LD_PRELOAD makes every child load GTK (~0.1s each)

def sh(c):
    return subprocess.run(c, shell=True, capture_output=True, text=True, env=ENV).stdout.strip()

def bg(c):
    subprocess.Popen(c, shell=True, env=ENV, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

def wifi_on(): return sh("nmcli radio wifi") == "enabled"
def wifi_name(): return sh("nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | head -1 | cut -d: -f2") or "Not connected"
def bt_on(): return "Powered: yes" in sh("bluetoothctl show")
def bt_name():
    n = sh("bluetoothctl devices Connected | head -1 | cut -d' ' -f3-")
    return n or ("On" if bt_on() else "Off")
def vol():
    m = re.search(r"([\d.]+)", sh("wpctl get-volume @DEFAULT_AUDIO_SINK@")); return float(m[1]) * 100 if m else 0
def mic_muted(): return "MUTED" in sh("wpctl get-volume @DEFAULT_AUDIO_SOURCE@")
def bright():
    try: return int(sh("brightnessctl -m").split(",")[3].rstrip("%"))
    except Exception: return 50


def shq(x):
    import shlex; return shlex.quote(x)

def wifi_list():
    out = sh("nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list")
    saved = {l.rsplit(":", 1)[0] for l in sh("nmcli -t -f NAME,TYPE connection show").splitlines() if l.endswith("802-11-wireless")}
    nets = {}
    for line in out.splitlines():
        f = re.split(r"(?<!\\):", line)
        if len(f) < 4 or not f[1]: continue
        ssid = f[1].replace("\\:", ":")
        n = dict(ssid=ssid, signal=int(f[2] or 0), secure=bool(f[3].strip()), active=f[0] == "*", saved=ssid in saved)
        if ssid not in nets or n["active"] or (not nets[ssid]["active"] and n["signal"] > nets[ssid]["signal"]): nets[ssid] = n
    bg("nmcli device wifi rescan")
    return sorted(nets.values(), key=lambda n: (not n["active"], -n["signal"]))

def bt_list():
    conn = {l.split()[1] for l in sh("bluetoothctl devices Connected").splitlines() if len(l.split()) > 1}
    out = []
    for l in sh("bluetoothctl devices").splitlines():
        p = l.split(" ", 2)
        if len(p) == 3 and p[0] == "Device": out.append(dict(mac=p[1], name=p[2], connected=p[1] in conn))
    return sorted(out, key=lambda d: (not d["connected"], d["name"].lower()))

def app_list():
    try: items = json.loads(sh("pactl -f json list sink-inputs") or "[]")
    except ValueError: return []
    res = []
    for i in items:
        pr = i.get("properties", {})
        vols = [int(v["value_percent"].rstrip("%")) for v in i.get("volume", {}).values()]
        res.append(dict(id=i["index"], name=pr.get("application.name") or pr.get("media.name") or "App", vol=max(vols) if vols else 0))
    return res

class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.rice.QuickSettings")
        self.win = None

    def do_activate(self):
        if getattr(self, "started", False): return
        self.started = True
        css = Gtk.CssProvider(); css.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_USER)
        self.hold()   # stay resident (no Python/GTK startup cost); SIGUSR1 toggles the panel
        GLib.unix_signal_add(GLib.PRIORITY_HIGH, signal.SIGUSR1, self.toggle)
        if "--hidden" not in sys.argv: self.show()

    def toggle(self):
        if self.closing: return True
        self.hide() if self.win else self.show()
        return True

    closing = False

    def hide(self):
        if not self.win or self.closing: return
        self.closing = True
        def finish():
            if self.win: self.win.destroy(); self.win = None
            self.closing = False
        self.animate(opening=False, done=finish)

    def show(self):
        win = self.win = Gtk.ApplicationWindow(application=self)
        LayerShell.init_for_window(win)
        LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
        LayerShell.set_namespace(win, "quick-settings")
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.EXCLUSIVE)
        for e in (LayerShell.Edge.TOP, LayerShell.Edge.BOTTOM, LayerShell.Edge.LEFT, LayerShell.Edge.RIGHT):
            LayerShell.set_anchor(win, e, True)
        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", lambda _c, k, *_: self.hide() if k == Gdk.KEY_Escape else None)
        win.add_controller(keys)
        self.t0 = GLib.get_monotonic_time()
        click = Gtk.GestureClick()
        def outside(_g, _n, x, y):   # close only for a real click outside the panel, not in its first 0.5s
            if GLib.get_monotonic_time() - self.t0 < 500000: return
            ok, b = self.panel.compute_bounds(win)
            if not ok or not (b.get_x() <= x <= b.get_x() + b.get_width() and b.get_y() <= y <= b.get_y() + b.get_height()):
                self.hide()
        click.connect("pressed", outside); win.add_controller(click)

        panel = self.panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, css_classes=["panel"])
        panel.append(Gtk.Label(label="󰒓  Quick settings", css_classes=["title"], xalign=0))
        row = Gtk.Box(spacing=10, homogeneous=True)
        self.wifi = self.tile("󰤨", "Wi-Fi", self.toggle_wifi); self.bt = self.tile("󰂯", "Bluetooth", self.toggle_bt)
        row.append(self.wifi[0]); row.append(self.bt[0]); panel.append(row)
        row2 = Gtk.Box(spacing=10, homogeneous=True)
        self.mic = self.tile("󰍬", "Microphone", self.toggle_mic)
        self.dnd = self.tile("󰂛", "Do not disturb", self.toggle_dnd)
        row2.append(self.mic[0]); row2.append(self.dnd[0]); panel.append(row2)
        self.snd = self.tile("󰎇", "Sound effects (this rice)", self.toggle_snd); panel.append(self.snd[0])
        self.vol = self.slider("󰕾", lambda v: bg(f"wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ {int(v)}%"))
        self.bri = self.slider("󰃠", lambda v: bg(f"brightnessctl -q set {max(int(v), 1)}%"))
        panel.append(self.vol[0]); panel.append(self.bri[0])
        self.build_pages(panel)
        self.fixed = Gtk.Fixed(); self.fixed.put(panel, 4, -2000)   # off-screen until the first frame is measured
        win.set_child(self.fixed)
        win.present()      # show instantly; real states are filled in below, off the UI thread
        self.refresh()
        self.animate(opening=True)

    GAP = 2   # px below the bar when open

    def animate(self, opening, done=None):
        """Slide the panel down out of the waybar (and back up into it), easing out, with a fade."""
        win, panel = self.win, self.panel
        dur = 220000 if opening else 150000   # microseconds
        state = {"t0": None}
        def tick(widget, clock):
            if win is not self.win: return False
            h = panel.get_height() or 330
            t = clock.get_frame_time()
            if state["t0"] is None: state["t0"] = t
            k = min((t - state["t0"]) / dur, 1.0)
            e = 1 - (1 - k) ** 3 if opening else k ** 2          # out: cubic ease-out, in: ease-in
            f = e if opening else 1 - e                          # 0 = hidden, 1 = open
            self.fixed.move(panel, 4, -h + (h + self.GAP) * f)
            panel.set_opacity(min(1.0, f * 1.6))
            if k >= 1.0:
                if done: done()
                return False
            return True
        win.add_tick_callback(tick)


    # ---- expandable pages: Wi-Fi networks, Bluetooth devices, per-app volume ----
    page = None

    def build_pages(self, panel):
        self.page = None; self.page_btns = {}
        bar = Gtk.Box(spacing=8, homogeneous=True)
        for key, icon, label in (("wifi", "󰖩", "Networks"), ("bt", "󰂯", "Devices"), ("apps", "󰕾", "Apps")):
            b = Gtk.Box(spacing=8, css_classes=["tile", "mini"], halign=Gtk.Align.FILL)
            b.append(Gtk.Label(label=icon, css_classes=["icon"])); b.append(Gtk.Label(label=label, hexpand=True))
            g = Gtk.GestureClick(); g.connect("pressed", lambda *_a, k=key: self.open_page(k)); b.add_controller(g)
            self.page_btns[key] = b; bar.append(b)
        panel.append(bar)
        self.list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        sc = self.sc = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER)
        sc.set_child(self.list)
        self.rev = Gtk.Revealer(transition_type=Gtk.RevealerTransitionType.SLIDE_DOWN, transition_duration=180)
        self.rev.set_child(sc); panel.append(self.rev)

    def open_page(self, key):
        for k, b in self.page_btns.items(): b.remove_css_class("on")
        if self.page == key:
            self.page = None; self.rev.set_reveal_child(False); return
        self.page = key; self.page_btns[key].add_css_class("on")
        self.fill(None)
        self.rev.set_reveal_child(True)
        self.load_page()

    def fill(self, rows, empty="Nothing found"):
        c = self.list.get_first_child()
        while c: n = c.get_next_sibling(); self.list.remove(c); c = n
        if rows is None: rows = [Gtk.Label(label="Loading…", css_classes=["dim"], xalign=0, margin_start=6)]
        elif not rows: rows = [Gtk.Label(label=empty, css_classes=["dim"], xalign=0, margin_start=6)]
        for r in rows: self.list.append(r)
        self.sc.set_size_request(-1, min(250, len(rows) * 66))

    def item(self, icon, text, sub, on, cb):
        row = Gtk.Box(spacing=10, css_classes=["item"] + (["on"] if on else []))
        row.append(Gtk.Label(label=icon, css_classes=["icon"]))
        col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, hexpand=True)
        col.append(Gtk.Label(label=text, xalign=0, ellipsize=3, max_width_chars=26))
        if sub: col.append(Gtk.Label(label=sub, css_classes=["sub"], xalign=0))
        row.append(col)
        g = Gtk.GestureClick(); g.connect("pressed", lambda *_a: cb()); row.add_controller(g)
        return row

    def load_page(self, delay=0):
        key, win = self.page, self.win
        def work():
            data = {"wifi": wifi_list, "bt": bt_list, "apps": app_list}[key]()
            GLib.idle_add(lambda: self.show_page(win, key, data))
        threading.Thread(target=work, daemon=True).start()
        return False

    def show_page(self, win, key, data):
        if win is not self.win or key != self.page: return False
        if key == "wifi":
            rows = [self.item("󰤨" if n["signal"] > 60 else "󰤥" if n["signal"] > 30 else "󰤢", n["ssid"],
                              ("Connected · " if n["active"] else "") + f"{n['signal']}%" + ("  " if n["secure"] else ""),
                              n["active"], lambda n=n: self.wifi_click(n)) for n in data]
            self.fill(rows, "No networks (is Wi-Fi off?)")
        elif key == "bt":
            rows = [self.item("󰂱" if d["connected"] else "󰂯", d["name"], "Connected" if d["connected"] else "Paired",
                              d["connected"], lambda d=d: self.bt_click(d)) for d in data]
            self.fill(rows, "No paired devices")
        else:
            rows = [self.app_row(a) for a in data]
            self.fill(rows, "Nothing is playing audio")
        return False

    def wifi_click(self, n):
        if n["active"]:
            bg(f"nmcli connection down id {shq(n['ssid'])} && notify-send -t 2000 'Wi-Fi' 'Disconnected from '{shq(n['ssid'])}")
        elif n["saved"] or not n["secure"]:
            bg(f"notify-send -t 1500 'Wi-Fi' 'Connecting to '{shq(n['ssid'])}; nmcli device wifi connect {shq(n['ssid'])} "
               f"&& notify-send -t 2500 'Wi-Fi' 'Connected to '{shq(n['ssid'])} || notify-send 'Wi-Fi' 'Could not connect'")
        else:   # new secured network: close the panel, ask for the password
            self.hide()
            bg(f"pw=$(wofi --dmenu --password --prompt {shq('Password for ' + n['ssid'])} </dev/null) && [ -n \"$pw\" ] && "
               f"(nmcli device wifi connect {shq(n['ssid'])} password \"$pw\" && notify-send 'Wi-Fi' 'Connected to '{shq(n['ssid'])} "
               f"|| notify-send 'Wi-Fi' 'Wrong password or no connection')")
            return
        GLib.timeout_add(2500, self.load_page); GLib.timeout_add(2600, self.refresh)

    def bt_click(self, d):
        bg(f"bluetoothctl {'disconnect' if d['connected'] else 'connect'} {d['mac']}")
        GLib.timeout_add(2500, self.load_page); GLib.timeout_add(2600, self.refresh)

    def app_row(self, a):
        row = Gtk.Box(spacing=10, css_classes=["item"])
        row.append(Gtk.Label(label="󰎆", css_classes=["icon"]))
        col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, hexpand=True)
        col.append(Gtk.Label(label=a["name"], xalign=0, ellipsize=3, max_width_chars=26))
        sc = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1); sc.set_value(a["vol"]); sc.set_hexpand(True)
        sc.connect("value-changed", lambda w, i=a["id"]: bg(f"pactl set-sink-input-volume {i} {int(w.get_value())}%"))
        col.append(sc); row.append(col)
        return row

    def tile(self, icon, name, cb):
        box = Gtk.Box(spacing=10, css_classes=["tile"])
        box.append(Gtk.Label(label=icon, css_classes=["icon"]))
        col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        col.append(Gtk.Label(label=name, xalign=0)); sub = Gtk.Label(label="…", css_classes=["sub"], xalign=0, ellipsize=3, max_width_chars=14)
        col.append(sub); box.append(col)
        g = Gtk.GestureClick(); g.connect("pressed", lambda *_: cb()); box.add_controller(g)
        return box, sub

    def slider(self, icon, cb):
        b = Gtk.Box(spacing=12, css_classes=["tile"])
        b.append(Gtk.Label(label=icon, css_classes=["icon"]))
        s = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1); s.set_hexpand(True)
        s.connect("value-changed", lambda w: None if self.loading else cb(w.get_value())); b.append(s)
        return b, s

    def set_tile(self, t, on, text):
        t[1].set_text(text); (t[0].add_css_class if on else t[0].remove_css_class)("on")

    def refresh(self):
        """Query everything in parallel on worker threads, then apply on the UI thread."""
        win = self.win
        if not win: return False
        def work():
            with ThreadPoolExecutor(8) as ex:
                f = dict(wifi=ex.submit(wifi_on), ssid=ex.submit(wifi_name), bt=ex.submit(bt_on), btn=ex.submit(bt_name),
                         mic=ex.submit(mic_muted), dnd=ex.submit(lambda: sh("dunstctl is-paused") == "true"),
                         vol=ex.submit(vol), bri=ex.submit(bright), snd=ex.submit(lambda: sh("~/.config/hypr/scripts/sounds.sh status") == "on"))
                GLib.idle_add(lambda r={k: v.result() for k, v in f.items()}: self.apply(win, r))
        threading.Thread(target=work, daemon=True).start()
        return False

    def apply(self, win, r):
        if win is not self.win: return False
        self.state = r
        self.set_tile(self.wifi, r["wifi"], r["ssid"] if r["wifi"] else "Off")
        self.set_tile(self.bt, r["bt"], r["btn"])
        self.set_tile(self.mic, not r["mic"], "Muted" if r["mic"] else "Live")
        self.set_tile(self.dnd, r["dnd"], "On" if r["dnd"] else "Off")
        self.set_tile(self.snd, r["snd"], "On" if r["snd"] else "Off")
        self.loading = True
        self.vol[1].set_value(r["vol"]); self.bri[1].set_value(r["bri"])
        self.loading = False
        return False

    state = {}
    loading = True
    def toggle_wifi(self):
        on = not self.state.get("wifi"); self.state["wifi"] = on
        bg("nmcli radio wifi " + ("on" if on else "off"))
        self.set_tile(self.wifi, on, "…" if on else "Off"); GLib.timeout_add(2000, self.refresh)

    def toggle_bt(self):
        on = not self.state.get("bt"); self.state["bt"] = on
        bg("bluetoothctl power " + ("on" if on else "off"))
        self.set_tile(self.bt, on, "…" if on else "Off"); GLib.timeout_add(2000, self.refresh)
    def toggle_snd(self):
        on = not self.state.get("snd"); self.state["snd"] = on
        bg("~/.config/hypr/scripts/sounds.sh " + ("on" if on else "off"))
        self.set_tile(self.snd, on, "On" if on else "Off")

    def toggle_mic(self): bg("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
    def toggle_dnd(self): bg("dunstctl set-paused toggle")

App().run()
