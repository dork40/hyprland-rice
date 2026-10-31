-- Laptop extras. Written by the installer only when you pick the laptop edition.
-- Screen brightness keys
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.config/hypr/scripts/osd.sh --brightness raise"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd.sh --brightness lower"), { locked = true, repeating = true })

-- Low battery warnings at 15% and 5%
hl.on("hyprland.start", function()
    hl.exec_cmd("~/.config/hypr/scripts/battery-warn.sh")
end)
