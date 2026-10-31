# Hyprland rice

A complete, good-looking **Hyprland desktop you can install with one command**: a black, glassy, minimal setup with a bar, launcher, notifications, terminal, wallpapers and a handful of small apps that make it easy to live in. Works on **Arch, Fedora and Ubuntu/Debian**, with **NVIDIA support**.

**This is the laptop edition.** Running a desktop PC? Switch to the `pc-edition` branch (`git checkout pc-edition`): no laptop bits, plus an optional max-performance service.

### What you get

- **Wardrobe**: one keypress (`Super+Shift+R`) swaps the whole look at once, wallpaper included (see the three styles below).
- **A finished desktop**: Waybar, wofi launcher, dunst notifications, kitty terminal, a power menu, volume and brightness pop-ups, clipboard history, an emoji picker, a screenshot tool and a screen text-copy (OCR) shortcut.
- **Displays app** (`Super+Shift+D`): resolution, refresh rate, scale, rotation and drag-to-arrange for several monitors, with a "keep these settings?" countdown so you can't lock yourself out.
- **AI switcher** (`Super+Shift+Ctrl+...`): one key to jump to Claude Code, Codex, Gemini, OpenCode, Aider, Ollama or a web chat, with an optional yolo mode.
- **Welcome window** (`Super+F1`): a first-login guide to the basics, so a new user knows how to open apps, move windows and change the look.
- **A real installer**: installs the dependencies for your distro, backs up your old configs first, and sets up NVIDIA drivers when it finds an NVIDIA GPU.

### The three styles

| Style | Look |
|---|---|
| **noir** | Catppuccin accents on black, floating rounded corners (default) |
| **liquid** | Frosted liquid glass: see-through panels, heavy blur, soft corners |
| **mono** | Pure greyscale, flat and instant, no animations |

Wallpapers are public-domain NASA photos (credits in `wallpapers/CREDITS.md`).

## Install

```sh
git clone https://github.com/dork40/hyprland-rice.git
cd hyprland-rice
./install.sh   # installs everything: packages (asks for sudo), configs, wallpapers, the apps below
```

The installer is all-in-one: there are no options to pick through. It installs only what the rice itself uses: Hyprland and its helpers (hypridle, hyprpaper, hyprpicker), Waybar, wofi, dunst, kitty, swayosd, wlogout, thunar (files), clipboard history, screenshots and screen recording, media keys, the volume/network/Bluetooth applets, the starship prompt and the JetBrainsMono Nerd Font. It does not install anyone's personal apps.

Existing configs are backed up to `~/.config-rice-backup-<date>` before anything is overwritten.

## AI switcher

- **`Super+Shift+Ctrl+` ` `` ` `** (the backtick key) **switches agent**: a menu shows every AI with a status dot (● ready, ◐ installed but not signed in yet, ○ not installed). Pick one and it becomes your AI and opens.
- **`Super+Shift+Ctrl+A`** opens your selected AI, or jumps to its window if it is already open. If you haven't picked one yet it asks first.
- **`Super+Shift+Ctrl+1` to `0`** are one-key shortcuts, one per AI.

**Yolo mode** (off by default) starts your terminal AI without the "may I edit this file / run this command?" prompts. Turn it on or off from the bottom line of the switch-agent menu, or run `ai.py yolo on` / `ai.py yolo off`. It uses each tool's own flag: Claude Code `--dangerously-skip-permissions`, Codex `--dangerously-bypass-approvals-and-sandbox`, Gemini CLI and Qwen Code `--yolo`, Aider `--yes-always`, GitHub Copilot CLI `--allow-all-tools`, Goose `GOOSE_MODE=auto`. **It lets the AI change or delete anything your user can, so only use it where you accept that.** Web AIs and OpenCode/Ollama have no such flag. A command in `ai-overrides.json` always wins over yolo mode.

Sign-in status is a best guess from each tool's login files or API-key variables. Web AIs use whatever your browser is signed in to.

One key per assistant. **The first time you press a key it asks "Which AI do you want?"** (the suggested one is on top) and remembers your answer. After that the key jumps to that AI if it is already open, or opens it. Suggested defaults:

| Key (with `Super+Shift+Ctrl`) | AI |
|---|---|
| `1` | Claude Code |
| `2` | OpenAI Codex |
| `3` | Gemini CLI |
| `4` | OpenCode |
| `5` | Aider |
| `6` | Ollama (local models) |
| `7` | ChatGPT (web) |
| `8` | Claude.ai (web) |
| `9` | Gemini (web) |
| `0` | Perplexity (web) |
| other AIs | Grok, Copilot, Le Chat, DeepSeek, Qwen Code, Goose and GitHub Copilot CLI are in the switch-agent menu |

Terminal AIs open in their own kitty window. If one isn't installed, the window shows the install command and offers to run it. Web AIs open as app windows in Chrome/Chromium (or your default browser). `ai.py list` shows what is installed. To change which AI a key opens later, use the "Change which AI a key opens" line in the `Super+Shift+Ctrl+A`-menu (`ai.py pick`) or run `ai.py assign` (answers are kept in `~/.config/hypr/ai-slots.json`). To change a command, create `~/.config/hypr/ai-overrides.json`, for example `{"claude": "claude --model opus"}`.

## Welcome window

On your first login a **Welcome** window opens with the basics: how to open apps, close and move windows, switch workspaces, take screenshots, and buttons for changing the style, wallpaper and screens. Reopen it any time with `Super+F1`.

## Displays app

`Super+Shift+D` (or "Displays" in your app launcher) opens a screen settings window:

- pick **resolution**, **refresh rate**, **scale** and **rotation** for each monitor
- **drag the screens** to arrange them side by side (they snap together), or use the ◀ ▶ ▲ ▼ buttons to place one next to another
- **mirror** one screen onto another, or switch a screen off
- **Apply** shows a 15-second "keep these settings?" countdown and reverts by itself if you don't confirm, so a bad setting can't lock you out
- **Keep** saves the layout to `~/.config/hypr/monitors.lua`, which Hyprland loads at every start

## Supported distros

`install.sh` detects your distro and installs the dependencies with its package manager:

| Distro | How |
|---|---|
| **Arch** (and Arch-based) | `pacman`, plus the AUR (`awww`, `blesh-git`, `rofimoji`) through `yay` or `paru` |
| **Fedora** | `dnf`, with the [`solopasha/hyprland`](https://copr.fedorainfracloud.org/coprs/solopasha/hyprland/) COPR for a current Hyprland |
| **Ubuntu / Debian** | `apt`; Hyprland and its companion tools are only installed if your release ships them |

Anything the distro doesn't ship is listed at the end, so you know what to install by hand. The JetBrainsMono Nerd Font and the `starship` prompt are downloaded from their GitHub releases on non-Arch systems. Arch is the tested path; Fedora and Ubuntu are best-effort.

**Important:** the config uses Hyprland's newer **Lua config format** (written against Hyprland 0.56). On Ubuntu/Debian releases that ship an older Hyprland, install a newer one (build from source, or use a newer release) or the config won't load. The installer warns you if your version looks too old.

## Keys

| Key | Action |
|---|---|
| `Super+Shift+R` | Wardrobe: pick a style |
| `Super+W` | Wallpapers for the current style |
| `Super+Shift+D` | Displays: resolution, refresh rate, scale, rotation, multi-monitor layout |
| `Super+Shift+Ctrl+1` to `0` | AI switcher: jump to an AI assistant (see below) |
| `Super+Shift+Ctrl+` + `` ` `` | Switch agent: pick which AI is yours |
| `Super+Shift+Ctrl+A` | Open your selected AI |
| `Super+F1` | Welcome window: how to open apps, move windows, change styles |
| `Super+/` | Searchable cheat sheet of every shortcut |

## NVIDIA

`install.sh` detects an NVIDIA GPU by itself. If it finds one it installs the open driver (`nvidia-open-dkms` and friends, for GTX 16xx / RTX and newer), turns on kernel modesetting, and enables the suspend/resume services. Reboot once afterwards.

- **NVIDIA only (desktop):** it also writes `~/.config/hypr/nvidia.lua` with the Wayland environment variables Hyprland needs.
- **NVIDIA + AMD/Intel (hybrid laptop):** it leaves the environment alone so the integrated GPU keeps driving the screen. Run games on the NVIDIA GPU with `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <program>`.
- The Waybar GPU module shows NVIDIA usage and temperature through `nvidia-smi`.
- Older cards (GTX 10xx and before) need the AUR driver `nvidia-580xx-dkms` instead; install it by hand.

## Notes

- `config/hypr/hyprland.lua` uses the **Lua config** of recent Hyprland (written against 0.56). Screens are managed by the Displays app (`Super+Shift+D`); until you save a layout, Hyprland auto-detects them.
- Weather defaults to a location guessed from your IP. Set `WEATHER_LOCATION="City,State"` to pin it.
- Fonts: JetBrainsMono Nerd Font. Cursor: Breeze_Light. Icons: Papirus-Dark.
- Edit styles in `config/rices/wardrobe.py` (palette + Hyprland values per style) and the shared base files in `config/rices/base/`. Do not edit the generated `waybar/style.css`, `wofi/style.css`, etc.: they are rewritten on every switch.

## License

Configs and scripts: MIT (see `LICENSE`). Wallpapers: NASA public-domain photos, see `wallpapers/CREDITS.md`.
