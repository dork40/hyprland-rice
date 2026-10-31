------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Screens are set with the Displays app (Super+Shift+D); it saves them to monitors.lua
if not pcall(dofile, os.getenv("HOME") .. "/.config/hypr/monitors.lua") then
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1" })
end

-- X11 apps (Steam, games, launchers) draw at the real 1920x1200
-- instead of 1536x960 stretched up, so they're sharp instead of blurry
hl.config({ xwayland = { force_zero_scaling = true } })

---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "dolphin"
local menu = "wofi"

-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
-- hl.on("hyprland.start", function () 
--   hl.exec_cmd(terminal)
--   hl.exec_cmd("nm-applet")
--   hl.exec_cmd("waybar & hyprpaper & firefox")
-- end)
-- hl.exec("nm-applet --indicator")
--hl.exec("waybar")

hl.on("hyprland.start", function ()
  hl.exec_cmd("sh -c 'while :; do waybar; sleep 1; done'")  -- restarts the bar if it ever crashes
  hl.exec_cmd("~/.config/hypr/scripts/wallpaper-restore.sh")
  hl.exec_cmd("swayosd-server")
  hl.exec_cmd("hypridle -c ~/.config/hypr/hypridle-sleeponly.conf")  -- screen timeout starts OFF; turn it on with the Waybar button
  hl.exec_cmd("~/.config/hypr/scripts/easyeffects-start.sh")  -- speaker effects, always the Laptop preset
  hl.exec_cmd("~/.config/hypr/scripts/mangohud.sh apply")  -- MangoHud on/off, saved from the Waybar button
  hl.exec_cmd("~/.config/hypr/scripts/powerwatch.sh")  -- turbo/game mode switch off when the charger is unplugged
  -- hl.exec_cmd("~/.config/hypr/scripts/autogame.sh")    -- off by request: game mode no longer turns itself on for games
  hl.exec_cmd("sh -c 'dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE; systemctl --user reset-failed xdg-desktop-portal-hyprland; systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal'")  -- screen sharing/OBS: the portal can crash if it starts before Hyprland after a re-login
  hl.exec_cmd("dunst")
  hl.exec_cmd("~/.config/rices/welcome.py --first-run")  -- one-time welcome window (reopen with Super+F1)
  hl.exec_cmd("~/.config/hypr/scripts/voxtype-run.sh")  -- dictation daemon (needs the input group, so not the systemd user service)
  hl.exec_cmd("/usr/lib/pam_kwallet_init")  -- unlocks the password keychain with your login (no KWallet popup)
  hl.exec_cmd("command -v kclockd && kclockd")  -- KClock alarms ring even with the Clock window closed
  hl.exec_cmd("udiskie --automount --notify --smart-tray")  -- USB drives mount by themselves
  hl.exec_cmd("~/.config/hypr/scripts/battery-warn.sh")     -- low battery warnings at 15% and 5%
  hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
  hl.exec_cmd("nm-applet --indicator")
  hl.exec_cmd("blueman-applet")  -- Bluetooth pairing prompts + tray icon (needed to pair controllers/earbuds)
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Breeze_Light")
hl.env("HYPRCURSOR_THEME", "Breeze_Light")
hl.env("QT_QPA_PLATFORMTHEME", "kde")  -- KDE apps (Dolphin etc.) use the Noir colour scheme

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 2,
        gaps_out = 6,

        border_size = 0,

        -- Catppuccin Mocha: mauve -> blue gradient on the focused window
        col = {
            active_border   = { colors = { "rgba(cba6f7ff)", "rgba(f5c2e7ff)", "rgba(89b4faff)", "rgba(cba6f7ff)" }, angle = 45 },
            inactive_border = "rgba(31324488)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 6,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = false,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 5,
            passes    = 2,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Fancy animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("overshot",   { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.12}  } })  -- grows past target, settles back
hl.curve("bounce",     { type = "bezier", points = { {0.34, 1.56}, {0.64, 1}    } })  -- springy pop
hl.curve("md3_decel",  { type = "bezier", points = { {0.05, 0.7},  {0.1, 1}     } })
hl.curve("md3_accel",  { type = "bezier", points = { {0.3, 0},     {0.8, 0.15}  } })
hl.curve("smoothOut",  { type = "bezier", points = { {0.36, 0},    {0.66, -0.56} } })  -- slight pull-back before leaving
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1},  {0.32, 1}    } })
hl.curve("linear",     { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("quick",      { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Bouncy spring for moving/resizing windows
hl.curve("wobble",     { type = "spring", mass = 1, stiffness = 200, dampening = 16 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,  bezier = "md3_decel" })
hl.animation({ leaf = "windows",       enabled = true, speed = 6,   spring = "wobble" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 6,   bezier = "overshot",  style = "popin 50%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 4,   bezier = "smoothOut", style = "popin 50%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 6,   spring = "wobble" })
hl.animation({ leaf = "border",        enabled = true, speed = 8,   bezier = "easeOutQuint" })
hl.animation({ leaf = "borderangle",   enabled = false, speed = 60,  bezier = "linear",    style = "loop" })  -- rotating gradient
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 4,   bezier = "md3_decel" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 3,   bezier = "md3_accel" })
hl.animation({ leaf = "fade",          enabled = true, speed = 4,   bezier = "md3_decel" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 4,   bezier = "md3_decel" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,   bezier = "bounce",    style = "popin 70%" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2.5, bezier = "md3_accel", style = "popin 70%" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 3,   bezier = "md3_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2,   bezier = "md3_accel" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 6,   bezier = "overshot",  style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, bezier = "overshot", style = "slidevert" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,   bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = false, -- If true disables the random hyprland logo / anime girl background. :(
        key_press_enables_dpms  = true,  -- a key press wakes a turned-off screen (mouse movement does not)
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.
        accel_profile = "flat", -- no mouse acceleration
        force_no_accel = false, -- flat profile above already means no accel; true ignores per-device sensitivity

        touchpad = {
            natural_scroll = false,
            disable_while_typing = false, -- touchpad keeps working while keys are held (games)
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})

-- Laptop touchpad: adaptive accel so slow finger moves stay precise (the mouse stays flat)
hl.device({
    name          = "asup1205:00-093a:2008-touchpad",
    sensitivity   = 0.05,
    accel_profile = "adaptive",
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd("google-chrome-stable"))  -- browser (change to your own)
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("true"))  -- dictation: voxtype handles hold-to-talk itself ([hotkey] in its config); this just keeps Super+Z out of apps

-- Voxtype switches here while it types, so a still-held Super can't turn the dictated letters into shortcuts.
-- F12 is the escape hatch if it ever gets stuck.
hl.define_submap("voxtype_suppress", function()
    hl.bind("F12", hl.dsp.submap("reset"))
end)
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("wofi --show drun"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())

-- Screenshots (saved to ~/Pictures/Screenshots and copied to clipboard)
hl.bind("Print",                   hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh region"))
hl.bind("SHIFT + Print",           hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh window"))
hl.bind("CTRL + Print",            hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh screen"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh region"))

-- Clipboard history, notification toggle, power menu
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh"))
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("~/.config/hypr/scripts/notif-toggle.sh"))
-- hl.bind(mainMod .. " + Escape",    hl.dsp.exec_cmd("wlogout -b 6 -T 400 -B 400"))  -- removed: Fn brightness keys were opening it; use the Waybar power button

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    -- by keycode (1 = code:10 … 0 = code:19) so Shift turning 1 into ! does not break it
    hl.bind(mainMod .. " + SHIFT + code:" .. (9 + i), hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + SHIFT + mouse:272", hl.dsp.window.resize(), { mouse = true })  -- Super+Shift+left-drag also resizes

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("swayosd-client --brightness raise"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("swayosd-client --brightness lower"),                  { locked = true, repeating = true })

-- TUF A16: Fn+F7/Fn+F8 send the same code as plain F7/F8, so brightness lives on Super+F7/F8
hl.bind(mainMod .. " + F7", hl.dsp.exec_cmd("swayosd-client --brightness lower"), { locked = true, repeating = true })
hl.bind(mainMod .. " + F8", hl.dsp.exec_cmd("swayosd-client --brightness raise"), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- ASUS keys: keyboard backlight and performance profile (the ROG / fan key)
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("asusctl leds next"), { locked = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("asusctl leds prev"), { locked = true })
hl.bind("XF86Launch4",           hl.dsp.exec_cmd("~/.config/hypr/scripts/asus-profile.sh next"))  -- Fn+F5 fan key

-- Armoury Crate key opens ROG Control Center (the key code differs between models)
hl.bind("XF86Launch1", hl.dsp.exec_cmd("rog-control-center"))
hl.bind("XF86Launch2", hl.dsp.exec_cmd("rog-control-center"))
hl.bind("XF86Launch3", hl.dsp.exec_cmd("rog-control-center"))

-- Wallpaper picker
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper.sh"))
-- AI assistants. Super+Shift+Ctrl+` switches agent (pick which AI is yours); Super+Shift+Ctrl+A opens the selected one.
-- Super+Shift+Ctrl+1..0: one key per AI. The first time you press a number it asks "Which AI do you want?" and remembers it.
-- Suggested: 1 Claude Code  2 Codex  3 Gemini CLI  4 OpenCode  5 Aider  6 Ollama  7 ChatGPT  8 Claude.ai  9 Gemini  0 Perplexity
hl.bind(mainMod .. " + SHIFT + CTRL + code:49", hl.dsp.exec_cmd("~/.config/rices/ai.py select"))
hl.bind(mainMod .. " + SHIFT + CTRL + A", hl.dsp.exec_cmd("~/.config/rices/ai.py open"))
for i = 1, 10 do
    hl.bind(mainMod .. " + SHIFT + CTRL + code:" .. (i == 10 and 19 or 9 + i), hl.dsp.exec_cmd("~/.config/rices/ai.py slot " .. (i % 10)))
end

hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("~/.config/rices/welcome.py"))  -- Welcome: how to use the rice
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("~/.config/rices/displays.py"))  -- Displays: resolution, refresh rate, multi-monitor layout
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/rices/wardrobe.py pick"))  -- Wardrobe: switch rice style

-- Window switcher: every open window across workspaces
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("~/.config/hypr/scripts/windows.sh"))

-- Emoji picker, colour picker, calculator, dropdown terminal
hl.bind(mainMod .. " + period",        hl.dsp.exec_cmd("rofimoji --selector wofi --action copy"))
hl.bind(mainMod .. " + SHIFT + C",     hl.dsp.exec_cmd("~/.config/hypr/scripts/colorpick.sh"))
hl.bind(mainMod .. " + equal",         hl.dsp.exec_cmd("~/.config/hypr/scripts/calc.sh"))
hl.bind(mainMod .. " + grave",         hl.dsp.exec_cmd("~/.config/hypr/scripts/dropdown.sh"))
hl.bind(mainMod .. " + SHIFT + T",     hl.dsp.exec_cmd("~/.config/hypr/scripts/ocr.sh"))  -- copy text from the screen
hl.bind(mainMod .. " + SHIFT + L",     hl.dsp.exec_cmd("~/.config/hypr/scripts/voxtype-translate.sh"))  -- dictation: toggle translate-to-English
hl.bind(mainMod .. " + slash",         hl.dsp.exec_cmd("~/.config/hypr/scripts/keybinds.sh"))  -- shortcut cheat sheet

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Blur behind the wofi launcher
hl.layer_rule({
    name  = "blur-wofi",
    match = { namespace = "^wofi$" },
    blur  = true,
    ignore_alpha = 0,
})

-- Small utility windows open floating and centred instead of tiling
hl.window_rule({
    name   = "float-utilities",
    match  = { class = "^(org.pulseaudio.pavucontrol|pavucontrol|blueman-manager|nm-connection-editor|nm-applet|org.kde.polkit-kde-authentication-agent-1|xdg-desktop-portal-gtk|btop|dev.rice.Displays|dev.rice.Welcome)$" },
    float  = true,
    center = true,
    size   = "900 600",
})

hl.window_rule({
    name   = "float-dialogs",
    match  = { title = "^(Open File|Open Files|Save File|Save As|Select a File|Choose Files|File Upload|Open Folder|Select Folder)(.*)$" },
    float  = true,
    center = true,
    size   = "1000 650",
})

hl.window_rule({
    name   = "float-btop",
    match  = { title = "^btop$" },
    float  = true,
    center = true,
    size   = "1100 700",
})

-- Dropdown terminal (Super+`) lives on its own special workspace at the top of the screen
hl.window_rule({
    name      = "dropdown-terminal",
    match     = { class = "^dropdown$" },
    workspace = "special:dropdown",
    float     = true,
    size      = "monitor_w*0.7 monitor_h*0.5",
    move      = "monitor_w*0.15 60",
})

-- Blur behind the volume/brightness popup
hl.layer_rule({
    name  = "blur-swayosd",
    match = { namespace = "^swayosd$" },
    blur  = true,
    ignore_alpha = 0,
})

-- HyprMod (GUI settings/keybind editor) saves its changes here
require("hyprland-gui")

-- CS2 (native Linux, runs under XWayland): open fullscreen. As a tiled window on this 1.25x-scaled screen
-- its mouse-look broke (the game re-centres the cursor and the warps land wrong in a scaled XWayland window).
hl.window_rule({
    name       = "cs2-fullscreen",
    match      = { class = "^cs2$" },
    fullscreen = true,
})

-- NVIDIA environment (written by install.sh only on machines where NVIDIA drives the display)
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/nvidia.lua")

-- Wardrobe: the active rice style (gaps, borders, rounding, blur, animations), switched with Super+Shift+R
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/rice.lua")
