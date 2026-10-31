# Hyprland rice

An Arch + Hyprland desktop with a style switcher called **Wardrobe**. One keypress swaps the whole look: Hyprland gaps/borders/blur/animations, Waybar, kitty, wofi, dunst, the volume popup, the power menu, and the wallpaper.

| Style | Look |
|---|---|
| **noir** | Catppuccin accents on black, floating rounded (default) |
| **liquid** | Frosted liquid glass: see-through panels, heavy blur |
| **mono** | Pure greyscale, flat, no animations |

## Install

```sh
git clone https://github.com/dork40/hyprland-rice.git
cd hyprland-rice
./install.sh              # packages (asks for sudo) + configs + wallpapers
./install.sh --no-packages  # configs only
./install.sh --dry-run      # show what it would do
```

Existing configs are backed up to `~/.config-rice-backup-<date>` before anything is overwritten.

## AI switcher

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
| `A` | menu of all of them, plus Grok, Copilot, Le Chat, DeepSeek, Qwen Code, Goose and GitHub Copilot CLI |

Terminal AIs open in their own kitty window. If one isn't installed, the window shows the install command and offers to run it. Web AIs open as app windows in Chrome/Chromium (or your default browser). `ai.py list` shows what is installed. To change which AI a key opens later, use the "Change which AI a key opens" line in the `Super+Shift+Ctrl+A` menu (answers are kept in `~/.config/hypr/ai-slots.json`). To change a command, create `~/.config/hypr/ai-overrides.json`, for example `{"claude": "claude --model opus"}`.

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
| `Super+Shift+Ctrl+A` | AI menu with every assistant |
| `Super+F1` | Welcome window: how to open apps, move windows, change styles |
| `Super+/` | Searchable cheat sheet of every shortcut |

## NVIDIA

`install.sh` detects an NVIDIA GPU by itself. If it finds one it installs the open driver (`nvidia-open-dkms` and friends, for GTX 16xx / RTX and newer), turns on kernel modesetting, and enables the suspend/resume services. Reboot once afterwards.

- **NVIDIA only (desktop):** it also writes `~/.config/hypr/nvidia.lua` with the Wayland environment variables Hyprland needs.
- **NVIDIA + AMD/Intel (hybrid laptop):** it leaves the environment alone so the integrated GPU keeps driving the screen. Run games on the NVIDIA GPU with `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <program>`.
- The Waybar GPU module shows NVIDIA usage and temperature through `nvidia-smi`.
- Older cards (GTX 10xx and before) need the AUR driver `nvidia-580xx-dkms` instead; install it by hand.

## Notes

- `config/hypr/hyprland.lua` uses the **Lua config** of recent Hyprland and sets the built-in screen to `eDP-1` 1920x1200@165Hz at 1.25 scale. Edit the `hl.monitor` block for your display.
- Some scripts are laptop-specific (ASUS fan/RGB keys, battery limit, voice dictation). They do nothing without that hardware.
- Weather defaults to a location guessed from your IP. Set `WEATHER_LOCATION="City,State"` to pin it.
- Fonts: JetBrainsMono Nerd Font. Cursor: Breeze_Light. Icons: Papirus-Dark.
- Edit styles in `config/rices/wardrobe.py` (palette + Hyprland values per style) and the shared base files in `config/rices/base/`. Do not edit the generated `waybar/style.css`, `wofi/style.css`, etc.: they are rewritten on every switch.

## License

Configs and scripts: MIT (see `LICENSE`). Wallpapers: NASA public-domain photos, see `wallpapers/CREDITS.md`.
