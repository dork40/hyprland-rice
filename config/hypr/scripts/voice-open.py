#!/usr/bin/env python3
"""Voice commands: press the key and say "open steam", "close chrome", "close this", "workspace 3", "fullscreen", "float".
Usage: voice-open.py [--text "open steam"] [--dry]"""
import configparser
import difflib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
ALIASES = HOME / ".config/voxtype/voice-apps.conf"
OUT = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "voxtype-cmd.txt"
APP_DIRS = [
    HOME / ".local/share/applications",
    Path("/usr/share/applications"),
    HOME / ".local/share/flatpak/exports/share/applications",
    Path("/var/lib/flatpak/exports/share/applications"),
]
WAIT_SECS = 25


def notify(msg):
    subprocess.run(["notify-send", "-a", "voice", "-t", "2500", "-h", "string:x-dunst-stack-tag:voice", "Voice", msg])


def norm(s):
    s = re.sub(r"[^a-z0-9+ ]", " ", s.lower())
    return re.sub(r"\b(the|a|an|up)\b", " ", s).split()


def load_aliases():
    out = {}
    for line in ALIASES.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            name, cmd = line.split("=", 1)
            out[" ".join(norm(name))] = ("cmd", cmd.strip())
    return out


def load_desktop_apps():
    out = {}
    for d in APP_DIRS:
        for f in sorted(d.glob("*.desktop")):
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(f, encoding="utf-8")
                e = cp["Desktop Entry"]
            except (configparser.Error, KeyError, UnicodeDecodeError):
                continue
            if e.get("NoDisplay") == "true" or e.get("Hidden") == "true" or e.get("Type") != "Application":
                continue
            name = " ".join(norm(e.get("Name", "")))
            if name:
                out.setdefault(name, ("desktop", f.name))
    return out


def best_match(heard, table):
    words = norm(heard)
    key = " ".join(words)
    if not words:
        return None
    if key in table:
        return key
    scored = []
    for name in table:
        nw = name.split()
        if name.startswith(key) or all(w in nw for w in words):
            scored.append((0.95 - 0.01 * len(nw), name))  # prefer shorter, closer names
        else:
            scored.append((difflib.SequenceMatcher(None, key, name).ratio(), name))
    score, name = max(scored)
    return name if score >= 0.7 else None


def run(kind, target, dry):
    argv = ["gtk-launch", target] if kind == "desktop" else ["sh", "-c", target]
    if dry:
        print("would run:", argv)
        return
    subprocess.Popen(argv, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


NUMBERS = {w: i for i, w in enumerate("zero one two three four five six seven eight nine ten".split())}
GENERIC = {"org", "kde", "com", "app", "io", "stable", "the", "window"}
THIS = {"", "this", "it", "that", "window", "this window", "that window", "the window", "current window"}


def hypr(expr, dry):
    if dry:
        print("would dispatch:", expr)
    else:
        subprocess.run(["hyprctl", "dispatch", expr], stdout=subprocess.DEVNULL)


def class_tokens(c):
    return {t for t in re.split(r"[^a-z0-9]+", c.lower()) if t and t not in GENERIC}


def window_keys(spoken, table):
    """Words that identify the app named by `spoken`: what was said, plus its alias command / app name."""
    keys = set(norm(spoken)) - GENERIC
    name = best_match(spoken, table)
    if name:
        kind, target = table[name]
        ident = target.removesuffix(".desktop") if kind == "desktop" else target.split()[0]  # flatpak ids like org.nickvision.tubeconverter are the window class
        keys |= {t for t in re.split(r"[^a-z0-9]+", f"{name} {ident}".lower()) if t} - GENERIC
        keys |= set(name.split()) - GENERIC
    return keys


def close_app(spoken, dry):
    keys = window_keys(spoken, {**load_desktop_apps(), **load_aliases()})
    clients = json.loads(subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True).stdout)
    hits = [c for c in clients if keys & class_tokens(c["class"])]
    if not hits:  # some apps use a generic class; fall back to the window title
        hits = [c for c in clients if keys & class_tokens(c["title"])]
    if not hits:
        say(f"No open window for '{spoken.strip(' .')}'")
        return 1
    say(f"Closing {spoken.strip(' .')}" + (f" ({len(hits)} windows)" if len(hits) > 1 else ""))
    for c in hits:
        hypr(f'hl.dsp.window.close({{ window = "address:{c["address"]}" }})', dry)
    return 0


def handle_one(text, dry=False):
    t = text.lower()
    m = re.search(r"\bwork ?space\s+(\w+)", t)
    if m:
        n = m.group(1)
        n = int(n) if n.isdigit() else NUMBERS.get(n)
        if n is None:
            say(f"Which workspace? Heard: {text.strip()}")
            return 1
        say(f"Workspace {n}")
        hypr(f"hl.dsp.focus({{ workspace = {n} }})", dry)
        return 0
    if re.search(r"\bfull ?screen\b", t):
        say("Fullscreen")
        hypr("hl.dsp.window.fullscreen()", dry)
        return 0
    if re.search(r"\bfloat(?:ing)?\b", t):
        say("Toggle floating")
        hypr('hl.dsp.window.float({ action = "toggle" })', dry)
        return 0
    m = re.search(r"\b(?:close|quit|kill)\b\s*(.*)", t)
    if m:
        rest = " ".join(norm(m.group(1)))
        if rest in THIS:
            say("Closing window")
            hypr("hl.dsp.window.close()", dry)
            return 0
        return close_app(m.group(1), dry)
    m = re.search(r"\b(?:open|launch|start|run)\b\s+(.+)", t)
    if not m:
        say(f"Try 'open steam', 'close chrome', 'workspace 3'. Heard: {text.strip()}")
        return 1
    heard = m.group(1)
    table = {**load_desktop_apps(), **load_aliases()}  # nicknames win
    name = best_match(heard, table)
    if not name:
        say(f"No app matches '{heard.strip(' .')}'")
        return 1
    kind, target = table[name]
    if not dry:
        say(f"Opening {name}")
    run(kind, target, dry)
    return 0


MSGS = []
CMD_START = re.compile(
    r"(?=\b(?:(?:go to|switch to|jump to)\s+)?work ?space\b|\b(?:open|launch|start|run|close|quit|kill)\b|\bfull ?screen\b|\bfloat(?:ing)?\b)")
CMD_WORDS = re.compile(r"\b(?:work ?space|open|launch|start|run|close|quit|kill|full ?screen|float(?:ing)?)\b")
TRAIL = re.compile(r"[\s,.;]*(?:\b(?:and|then|also|next|after that)\b[\s,.;]*)*$")


def say(msg):
    MSGS.append(msg)


def split_commands(text):
    """'go to workspace 7 and open kitty' -> ['workspace 7', 'open kitty']"""
    segs = [TRAIL.sub("", seg.strip()) for seg in CMD_START.split(text.lower())]
    out = []
    for seg in segs:
        if not CMD_WORDS.search(seg):
            continue
        if re.fullmatch(r"(?:open|launch|start|run)", seg):
            continue  # "open workspace 7": the bare "open" is just a lead-in
        m = re.fullmatch(r"(open|launch|start|run|close|quit|kill)\s+(.+)", seg)
        if m and re.search(r",|\band\b|\bplus\b", m.group(2)):
            # "open steam, kitty and chrome" -> one command per app
            out += [f"{m.group(1)} {item}" for item in re.split(r"\s*(?:,|\band\b|\bplus\b)\s*", m.group(2)) if item.strip()]
        else:
            out.append(seg)
    return out


GLUED = re.compile(r"\b(open|launch|close|quit|kill)([a-z]{3,})\b")
NOT_GLUED = {"ed", "ing", "er", "ers", "ly", "ness", "et", "ets", "ings", "ure", "ures"}  # opened, closet, killer...
ON_WORKSPACE = re.compile(r"\b(open|launch|start|run)\s+(.+?)\s+(?:on|in|at|to)\s+(?:the\s+)?(work ?space\s+\w+)")
LOG = HOME / ".cache/voice-commands.log"


def unglue(text):
    """Whisper writes "Open Steam" as "OpenSteam"; split the verb back off unless it's a real word."""
    def fix(m):
        rest = m.group(2)
        if rest in NOT_GLUED or (rest.endswith("ed") and len(rest) <= 3):
            return m.group(0)
        return f"{m.group(1)} {rest}"
    return GLUED.sub(fix, text)


def log(line):
    try:
        with LOG.open("a") as f:
            f.write(f"{time.strftime('%I:%M:%S %p')}  {line}\n")
    except OSError:
        pass


def handle(text, dry=False):
    raw = text
    text = unglue(text.lower())
    on_ws = bool(ON_WORKSPACE.search(text))
    text = ON_WORKSPACE.sub(r"\3, \1 \2", text)  # "open kitty on workspace 7" -> "workspace 7, open kitty"
    segs = split_commands(text) or [text]
    if not dry:
        log(f"heard: {raw.strip()!r} -> {segs}")
    if len(segs) > (2 if on_ws else 1):  # "open X on workspace N" is one command; anything more is refused
        if dry:
            print("says: I can only do one command at a time")
        else:
            notify("I can only do one command at a time")
            log("did: refused (more than one command)")
        return 1
    rc = 0
    for i, seg in enumerate(segs):
        rc = max(rc, handle_one(seg, dry))
        if i < len(segs) - 1 and not dry:
            # let the workspace switch / the new window land before the next command acts on "the active window"
            time.sleep(1.5 if re.search(r"\b(?:open|launch|start|run)\b", seg) else 0.4)
    if dry:
        print("says:", " | ".join(MSGS))
    elif MSGS:
        notify(" · ".join(MSGS))
        log("did: " + " · ".join(MSGS))
    return rc


def listen():
    OUT.unlink(missing_ok=True)
    subprocess.run(["voxtype", "record", "start", f"--file={OUT}"], check=True)
    subprocess.Popen([str(HOME / ".config/voxtype/silence-stop.py")], start_new_session=True)
    deadline = time.monotonic() + WAIT_SECS
    while time.monotonic() < deadline:
        if OUT.exists() and OUT.stat().st_size:
            time.sleep(0.2)
            text = OUT.read_text()
            OUT.unlink(missing_ok=True)
            return text
        time.sleep(0.2)
    return ""


if __name__ == "__main__":
    args = sys.argv[1:]
    dry = "--dry" in args
    if "--text" in args:
        sys.exit(handle(args[args.index("--text") + 1], dry))
    text = listen()
    if not text.strip():
        notify("Didn't hear anything")
        sys.exit(1)
    sys.exit(handle(text, dry))
