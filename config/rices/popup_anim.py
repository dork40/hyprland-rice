"""Shared open/close animation for the full-screen GTK popups: the panel fades and slides in, and back out on close."""
def _run(win, panel, opening, dur_us, done=None):
    st = {"t0": None}
    def tick(_w, clock):
        t = clock.get_frame_time()
        if st["t0"] is None: st["t0"] = t
        k = min((t - st["t0"]) / dur_us, 1.0)
        e = 1 - (1 - k) ** 3 if opening else k ** 2
        f = e if opening else 1 - e                 # 0 = hidden, 1 = shown
        panel.set_opacity(f)
        panel.set_margin_top(int(36 * (1 - f)))     # rises into place / sinks away
        if k >= 1.0:
            if done: done()
            return False
        return True
    win.add_tick_callback(tick)

def animate_in(win, panel):
    panel.set_opacity(0)
    _run(win, panel, True, 220000)

def animate_out(win, panel, done):
    _run(win, panel, False, 140000, done)
