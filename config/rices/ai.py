#!/usr/bin/env python3
"""AI switcher: jump to (or open) any AI assistant with one key.
  ai.py <id>      focus the AI's window if it is open, otherwise launch it
  ai.py slot <n>  what Super+Shift+Ctrl+<n> does: the first time it asks "Which AI do you want?" and remembers the answer
  ai.py assign    change which AI a key opens
  ai.py pick      menu of every AI (Super+Shift+Ctrl+A)
  ai.py list      print the catalogue
Number keys Super+Shift+Ctrl+1..0 map to the first ten entries of ORDER.
Override a command without touching this file: ~/.config/hypr/ai-overrides.json  {"claude": "claude --some-flag"}"""
import json, os, pathlib, shlex, shutil, subprocess, sys

HOME = pathlib.Path.home()
OVERRIDES = HOME / ".config/hypr/ai-overrides.json"
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
ORDER = ["claude", "codex", "gemini", "opencode", "aider", "ollama", "chatgpt", "claude-web", "gemini-web", "perplexity"]


def command(i):
    name, kind, cmd, hint = CATALOG[i]
    try:
        cmd = json.loads(OVERRIDES.read_text()).get(i, cmd)
    except (OSError, ValueError):
        pass
    return cmd


def installed(i):
    name, kind, cmd, hint = CATALOG[i]
    if kind == "web":
        return True
    first = shlex.split(command(i))[0]
    first = os.path.expanduser(first)
    if first == "sh":                      # wrapper commands (ollama): check the real tool
        first = "ollama"
    return bool(shutil.which(first) or (HOME / ".local/bin" / first).exists())


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
    subprocess.Popen(["kitty", "--class", cls, "--title", name, "--directory", str(HOME), "bash", "-lc", inner],
                     start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def load_slots():
    try:
        return json.loads(SLOTS.read_text())
    except (OSError, ValueError):
        return {}


def ask(title, ids, default=None):
    """Show a menu of AIs and return the chosen id (None if cancelled). The suggested one is listed first."""
    ids = ([default] if default in ids else []) + [i for i in ids if i != default]
    lines = [f"{'●' if installed(i) else '○'}  {CATALOG[i][0]:<20} {'web' if CATALOG[i][1] == 'web' else 'terminal'}"
             + ("   (suggested)" if i == default else "") for i in ids]
    r = subprocess.run(["wofi", "--dmenu", "--prompt", title, "--width", "620", "--lines", str(min(len(lines), 12)),
                        "--insensitive", "--cache-file", "/dev/null"], input="\n".join(lines), text=True, capture_output=True)
    sel = r.stdout.rstrip("\n")
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
        mark = "●" if installed(i) else "○"
        lines.append(f"{mark}  {name:<20} {'web' if kind == 'web' else 'terminal':<9} {key}\t{i}")
    lines.append("⚙  Change which AI a key opens…\tassign")
    shown = [l.split("\t")[0] for l in lines]
    r = subprocess.run(["wofi", "--dmenu", "--prompt", "AI  (● ready, ○ not installed)", "--width", "620", "--lines", str(len(shown)),
                        "--insensitive"], input="\n".join(shown), text=True, capture_output=True)
    sel = r.stdout.rstrip("\n")
    if sel in shown:
        target = lines[shown.index(sel)].split("\t")[1]
        assign() if target == "assign" else launch(target)


if __name__ == "__main__":
    a = sys.argv[1] if len(sys.argv) > 1 else "pick"
    if a == "pick":
        pick()
    elif a == "slot" and len(sys.argv) > 2:
        slot(sys.argv[2])
    elif a == "assign":
        assign()
    elif a == "list":
        for i, (name, kind, cmd, hint) in CATALOG.items():
            print(f"{'●' if installed(i) else '○'} {i:12} {name:20} {kind}")
    elif a in CATALOG:
        launch(a)
    else:
        sys.exit(f"unknown AI: {a} (try: ai.py list)")
