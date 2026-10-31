#!/usr/bin/env python3
"""AI switcher: jump to (or open) any AI assistant with one key.
  ai.py <id>      focus the AI's window if it is open, otherwise launch it
  ai.py slot <n>  what Super+Shift+Ctrl+<n> does: the first time it asks "Which AI do you want?" and remembers the answer
  ai.py assign    change which AI a key opens
  ai.py select    switch agent: pick which AI is "selected" and open it (Super+Shift+Ctrl+`)
  ai.py open      open the selected AI (Super+Shift+Ctrl+A); asks first if none is selected yet
  ai.py yolo [on|off|toggle]   yolo mode: start the selected CLI with "don't ask permission" flags (off by default)
  ai.py pick      plain menu of every AI (opens the one you click without selecting it)
  ai.py list      print the catalogue
Number keys Super+Shift+Ctrl+1..0 map to the first ten entries of ORDER.
Override a command without touching this file: ~/.config/hypr/ai-overrides.json  {"claude": "claude --some-flag"}"""
import json, os, pathlib, shlex, shutil, subprocess, sys

HOME = pathlib.Path.home()
OVERRIDES = HOME / ".config/hypr/ai-overrides.json"
SELECTED = HOME / ".config/hypr/ai-selected.json"   # {"id": "claude"}
YOLO_FILE = HOME / ".config/hypr/ai-yolo"            # exists = yolo mode on
SLOTS = HOME / ".config/hypr/ai-slots.json"      # {"1": "claude", ...} filled in as keys are used for the first time

# id: (name, kind, command-or-url, install hint)   kind: cli | web
CATALOG = {
    "claude":     ("Claude Code",      "cli", "claude",     "npm install -g @anthropic-ai/claude-code"),
    "codex":      ("OpenAI Codex",     "cli", "codex",      "npm install -g @openai/codex"),
    "gemini":     ("Gemini CLI",       "cli", "gemini",     "npm install -g @google/gemini-cli"),
    "opencode":   ("OpenCode",         "cli", "opencode",   "npm install -g opencode-ai"),
    "aider":      ("Aider",            "cli", "aider",      "pipx install aider-chat"),
    "ollama":     ("Ollama (local)",   "cli", "sh -c 'ollama run \"$(ollama list | awk \"NR==2{print \\$1}\")\"'", "install ollama from your package manager, then: ollama pull llama3.2"),
    "chatgpt":    ("ChatGPT",          "web", "https://chatgpt.com", ""),
    "claude-web": ("Claude.ai",        "web", "https://claude.ai", ""),
    "gemini-web": ("Gemini",           "web", "https://gemini.google.com", ""),
    "perplexity": ("Perplexity",       "web", "https://www.perplexity.ai", ""),
    "grok":       ("Grok",             "web", "https://grok.com", ""),
    "copilot":    ("Microsoft Copilot", "web", "https://copilot.microsoft.com", ""),
    "mistral":    ("Le Chat (Mistral)", "web", "https://chat.mistral.ai", ""),
    "deepseek":   ("DeepSeek",         "web", "https://chat.deepseek.com", ""),
    "qwen":       ("Qwen Code",        "cli", "qwen",       "npm install -g @qwen-code/qwen-code"),
    "goose":      ("Goose",            "cli", "goose",      "see https://block.github.io/goose"),
    "copilot-cli": ("GitHub Copilot CLI", "cli", "copilot", "npm install -g @github/copilot"),
}
# Flags that make each terminal AI stop asking for permission before it edits files or runs commands.
# DANGEROUS: it can change or delete anything your user can. Off unless you turn yolo mode on.
YOLO_FLAGS = {
    "claude": "--dangerously-skip-permissions",
    "codex": "--dangerously-bypass-approvals-and-sandbox",
    "gemini": "--yolo",
    "aider": "--yes-always",
    "qwen": "--yolo",
    "copilot-cli": "--allow-all-tools",
}
YOLO_ENV = {"goose": "GOOSE_MODE=auto"}
ORDER = ["claude", "codex", "gemini", "opencode", "aider", "ollama", "chatgpt", "claude-web", "gemini-web", "perplexity"]


def yolo_on():
    return YOLO_FILE.exists()


def command(i):
    name, kind, cmd, hint = CATALOG[i]
    try:
        over = json.loads(OVERRIDES.read_text())
    except (OSError, ValueError):
        over = {}
    if i in over:
        return over[i]                      # your own command wins, flags included
    if kind == "cli" and yolo_on():
        if i in YOLO_FLAGS:
            cmd = f"{cmd} {YOLO_FLAGS[i]}"
        elif i in YOLO_ENV:
            cmd = f"{YOLO_ENV[i]} {cmd}"
    return cmd


def yolo_supported(i):
    return i in YOLO_FLAGS or i in YOLO_ENV


def installed(i):
    name, kind, cmd, hint = CATALOG[i]
    if kind == "web":
        return True
    parts = shlex.split(command(i))
    while parts and "=" in parts[0] and not parts[0].startswith(("/", "~", ".")):   # skip VAR=value prefixes
        parts.pop(0)
    first = parts[0]
    first = os.path.expanduser(first)
    if first == "sh":                      # wrapper commands (ollama): check the real tool
        first = "ollama"
    return bool(shutil.which(first) or (HOME / ".local/bin" / first).exists())


def logged_in(i):
    """True / False for terminal AIs (best guess from their login files or API-key variables), None for web chats
    (they use whatever your browser is signed in to) and for local models."""
    name, kind, cmd, hint = CATALOG[i]
    if kind == "web" or i == "ollama":
        return None
    h = HOME
    env = os.environ.get
    def has(*paths):
        return any((h / p).exists() for p in paths)
    if i == "claude":
        try:
            return "oauthAccount" in json.loads((h / ".claude.json").read_text()) or has(".claude/.credentials.json") or bool(env("ANTHROPIC_API_KEY"))
        except (OSError, ValueError):
            return has(".claude/.credentials.json") or bool(env("ANTHROPIC_API_KEY"))
    if i == "codex":
        return has(".codex/auth.json") or bool(env("OPENAI_API_KEY"))
    if i == "gemini":
        return has(".gemini/oauth_creds.json") or bool(env("GEMINI_API_KEY") or env("GOOGLE_API_KEY"))
    if i == "opencode":
        return has(".local/share/opencode/auth.json")
    if i == "aider":
        return any(env(k) for k in ("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY", "DEEPSEEK_API_KEY")) or has(".aider.conf.yml")
    if i == "qwen":
        return has(".qwen/oauth_creds.json") or bool(env("OPENAI_API_KEY"))
    if i == "goose":
        return has(".config/goose/config.yaml")
    if i == "copilot-cli":
        return has(".copilot/config.json", ".config/github-copilot/apps.json")
    return None


def status(i):
    """● ready / signed in, ◐ installed but not signed in, ○ not installed"""
    if not installed(i):
        return "○"
    return "◐" if logged_in(i) is False else "●"


def clients():
    out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True).stdout
    try:
        return json.loads(out)
    except ValueError:
        return []


def focus(match):
    for c in clients():
        if match(c):
            subprocess.run(["hyprctl", "dispatch", f'hl.dsp.focus({{ window = "address:{c["address"]}" }})'],
                           stdout=subprocess.DEVNULL)
            return True
    return False


def launch(i):
    name, kind, cmd, hint = CATALOG[i]
    cmd = command(i)
    if kind == "web":
        host = cmd.split("//")[1].split("/")[0].replace("www.", "")
        if focus(lambda c: host in c["class"].lower()):
            return
        browser = shutil.which("google-chrome-stable") or shutil.which("chromium")
        subprocess.Popen([browser, f"--app={cmd}"] if browser else ["xdg-open", cmd], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    cls = f"ai-{i}"
    if focus(lambda c: c["class"] == cls):
        return
    if installed(i):
        inner = os.path.expanduser(cmd)
    else:
        q = shlex.quote
        inner = (f"echo {q(name + ' is not installed.')}; echo {q('Install with:  ' + hint)}; echo; "
                 + (f"read -p 'Install it now? [y/N] ' a; [ \"$a\" = y ] && {hint}; " if hint.startswith(("npm", "pipx")) else "")
                 + "echo; read -n1 -rsp 'Press any key to close'")
    inner = 'export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"; ' + inner   # login shells miss these
    subprocess.Popen(["kitty", "--class", cls, "--title", name, "--directory", str(HOME), "bash", "-lc", inner],
                     start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def load_slots():
    try:
        return json.loads(SLOTS.read_text())
    except (OSError, ValueError):
        return {}


def ask(title, ids, default=None, extra=()):
    """Show a menu of AIs and return the chosen id (None if cancelled). The suggested one is listed first."""
    ids = ([default] if default in ids else []) + [i for i in ids if i != default]
    lines = [f"{status(i)}  {CATALOG[i][0]:<20} {'web' if CATALOG[i][1] == 'web' else 'terminal'}"
             + ("   (suggested)" if i == default else "") for i in ids]
    labels = [l for l, _ in extra]
    shown = lines + labels
    r = subprocess.run(["wofi", "--dmenu", "--prompt", title, "--width", "620", "--lines", str(min(len(shown), 14)),
                        "--insensitive", "--cache-file", "/dev/null"], input="\n".join(shown), text=True, capture_output=True)
    sel = r.stdout.rstrip("\n")
    if sel in labels:
        return dict(extra)[sel]
    return ids[lines.index(sel)] if sel in lines else None


def slot(n, force=False):
    slots = load_slots()
    if force or n not in slots:
        default = ORDER[(int(n) - 1) % 10] if n.isdigit() and 1 <= int(n) <= 10 else None
        choice = ask(f"Which AI do you want on Super+Shift+Ctrl+{n}?", list(CATALOG), default)
        if not choice:
            return
        slots[n] = choice
        SLOTS.parent.mkdir(parents=True, exist_ok=True)
        SLOTS.write_text(json.dumps(slots, indent=1))
        notify(f"{CATALOG[choice][0]} is now on Super+Shift+Ctrl+{n}")
    launch(slots[n])


def selected():
    try:
        i = json.loads(SELECTED.read_text()).get("id")
        return i if i in CATALOG else None
    except (OSError, ValueError):
        return None


def select():
    """Switch agent: choose the AI that Super+Shift+Ctrl+A opens, and open it now."""
    cur = selected()
    toggle = ("⚡  Yolo mode: ON  (no permission prompts)  - click to turn OFF" if yolo_on()
              else "⚡  Yolo mode: OFF  - click to turn ON (AI won't ask before changing files)")
    choice = ask("Switch agent  (● ready, ◐ sign in needed, ○ not installed)", list(CATALOG), cur or ORDER[0],
                 extra=[(toggle, "__yolo__")])
    if choice == "__yolo__":
        set_yolo("off" if yolo_on() else "on")
        return select()
    if not choice:
        return
    SELECTED.parent.mkdir(parents=True, exist_ok=True)
    SELECTED.write_text(json.dumps({"id": choice}))
    notify(f"{CATALOG[choice][0]} is now your AI" + ("" if logged_in(choice) is not False else " (sign in when it opens)"))
    launch(choice)


def open_selected():
    cur = selected()
    if not cur:
        return select()
    if installed(cur) and logged_in(cur) is False:
        notify(f"{CATALOG[cur][0]} isn't signed in yet: finish signing in in its window")
    launch(cur)


def set_yolo(mode="toggle"):
    on = (not yolo_on()) if mode == "toggle" else mode == "on"
    YOLO_FILE.parent.mkdir(parents=True, exist_ok=True)
    if on:
        YOLO_FILE.touch()
    elif YOLO_FILE.exists():
        YOLO_FILE.unlink()
    notify("Yolo mode ON: your AI won't ask before it changes files or runs commands" if on else "Yolo mode OFF: your AI will ask first")
    return on


def notify(text):
    subprocess.run(["notify-send", "-t", "3000", "AI switcher", text], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def assign():
    r = subprocess.run(["wofi", "--dmenu", "--prompt", "Change which key?", "--lines", "10", "--insensitive", "--cache-file", "/dev/null"],
                       input="\n".join(f"Super+Shift+Ctrl+{k}   (now: {CATALOG[load_slots().get(k, ORDER[(int(k) - 1) % 10])][0]})"
                                       for k in "1234567890"), text=True, capture_output=True)
    sel = r.stdout.strip()
    if sel.startswith("Super+Shift+Ctrl+"):
        slot(sel[len("Super+Shift+Ctrl+")], force=True)


def pick():
    keys = {i: (n + 1) % 10 for n, i in enumerate(ORDER)}
    lines = []
    for n, i in enumerate(CATALOG):
        name, kind, _, _ = CATALOG[i]
        key = f"Super+Shift+Ctrl+{keys[i]}" if i in keys else ""
        mark = status(i)
        lines.append(f"{mark}  {name:<20} {'web' if kind == 'web' else 'terminal':<9} {key}\t{i}")
    lines.append("⚙  Change which AI a key opens…\tassign")
    shown = [l.split("\t")[0] for l in lines]
    r = subprocess.run(["wofi", "--dmenu", "--prompt", "AI  (● ready, ◐ sign in needed, ○ not installed)", "--width", "620", "--lines", str(len(shown)),
                        "--insensitive"], input="\n".join(shown), text=True, capture_output=True)
    sel = r.stdout.rstrip("\n")
    if sel in shown:
        target = lines[shown.index(sel)].split("\t")[1]
        assign() if target == "assign" else launch(target)


if __name__ == "__main__":
    a = sys.argv[1] if len(sys.argv) > 1 else "pick"
    if a == "pick":
        pick()
    elif a == "yolo":
        m = sys.argv[2] if len(sys.argv) > 2 else "toggle"
        print("on" if set_yolo(m) else "off") if m != "status" else print("on" if yolo_on() else "off")
    elif a == "select":
        select()
    elif a == "open":
        open_selected()
    elif a == "slot" and len(sys.argv) > 2:
        slot(sys.argv[2])
    elif a == "assign":
        assign()
    elif a == "list":
        for i, (name, kind, cmd, hint) in CATALOG.items():
            print(f"{status(i)} {i:12} {name:20} {kind}")
    elif a in CATALOG:
        launch(a)
    else:
        sys.exit(f"unknown AI: {a} (try: ai.py list)")
