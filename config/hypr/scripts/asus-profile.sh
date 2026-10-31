#!/usr/bin/env bash
# ASUS performance profile for waybar.
#   next   cycles Quiet -> Balanced -> Performance
#   game   toggles game mode: CPU and GPU at max (Performance profile), fans on automatic
#   turbo  toggles turbo mode: CPU and GPU at max, both fans locked at 100%
#         ("turbo anim" also turns Hyprland animations off; used by the maxperf button)
state=${XDG_RUNTIME_DIR:-/tmp}/gamemode
turbo=${XDG_RUNTIME_DIR:-/tmp}/turbomode
noanim=${XDG_RUNTIME_DIR:-/tmp}/noanimmode   # set only by "turbo anim"; this is what the maxperf button shows
flat=30c:100%,40c:100%,50c:100%,60c:100%,70c:100%,80c:100%,90c:100%,100c:100%
profile() { asusctl profile get 2>/dev/null | sed -n 's/^Active profile: //p'; }

case "$1" in
  next)
    asusctl profile next >/dev/null
    notify-send -t 1500 "Performance profile" "$(profile)" ;;
  game)
    [ -f "$turbo" ] && "$0" turbo >/dev/null
    if [ -f "$state" ]; then
        read -r prev fans <"$state"; rm -f "$state"
        asusctl profile set "$prev" >/dev/null
        asusctl fan-curve --mod-profile Performance --enable-fan-curves "$fans" >/dev/null
        sudo -n /usr/local/bin/gpu-perf auto 2>/dev/null
        notify-send -t 2000 "Game mode off" "Back to $prev"
    else
        fans=$(asusctl fan-curve --mod-profile Performance | grep -q 'enabled: true' && echo true || echo false)
        echo "$(profile) $fans" >"$state"
        asusctl profile set Performance >/dev/null                                      # CPU to max
        asusctl fan-curve --mod-profile Performance --enable-fan-curves false >/dev/null  # fans on auto
        if sudo -n /usr/local/bin/gpu-perf high 2>/dev/null; then                       # GPU to max
            notify-send -t 2000 "Game mode on" "CPU and GPU at max, fans on auto"
        else
            notify-send -t 4000 "Game mode on" "CPU at max, fans on auto. GPU not set yet: run bash ~/src/gamemode/install.sh once"
        fi
    fi ;;
  turbo)
    if [ "$2" = anim ] && [ -f "$turbo" ] && [ ! -f "$noanim" ]; then
        # turbo already on from the speed button: just add animations-off
        touch "$noanim"
        hyprctl eval 'hl.config({animations={enabled=false}})' >/dev/null
        notify-send -t 2000 "Animations off" "Turbo mode stays on"
    elif [ -f "$turbo" ]; then
        read -r prev <"$turbo"; rm -f "$turbo" "$noanim"
        asusctl fan-curve --mod-profile Performance --default >/dev/null
        asusctl fan-curve --mod-profile Performance --enable-fan-curves false >/dev/null
        asusctl profile set "$prev" >/dev/null
        sudo -n /usr/local/bin/gpu-perf auto 2>/dev/null
        hyprctl eval 'hl.config({animations={enabled=true}})' >/dev/null
        notify-send -t 2000 "Turbo mode off" "Back to $prev"
    else
        [ -f "$state" ] && { rm -f "$state"; sudo -n /usr/local/bin/gpu-perf auto 2>/dev/null; }
        echo "$(profile)" >"$turbo"
        asusctl profile set Performance >/dev/null
        for fan in cpu gpu; do
            asusctl fan-curve --mod-profile Performance --fan $fan --data "$flat" >/dev/null
        done
        asusctl fan-curve --mod-profile Performance --enable-fan-curves true >/dev/null
        msg="fans at 100%"
        [ "$2" = anim ] && { touch "$noanim"; hyprctl eval 'hl.config({animations={enabled=false}})' >/dev/null; msg="fans at 100%, animations off"; }
        if sudo -n /usr/local/bin/gpu-perf high 2>/dev/null; then
            notify-send -t 2000 "Turbo mode on" "CPU and GPU at max, $msg"
        else
            notify-send -t 4000 "Turbo mode on" "CPU at max, $msg. GPU not set yet: run bash ~/src/gamemode/install.sh once"
        fi
    fi ;;
esac
[ -n "$1" ] && pkill -RTMIN+9 waybar && pkill -RTMIN+11 waybar

p=$(profile)
case "$p" in
  Quiet)       icon="󰾆" ;;
  Balanced)    icon="󰾅" ;;
  Performance) icon="󰓅" ;;
  *)           icon="󰾅"; p="Unknown" ;;
esac
if [ -f "$turbo" ]; then
    echo "{\"text\":\"󰈐 $icon\",\"class\":\"turbo\",\"tooltip\":\"Turbo mode ON: max CPU/GPU, fans 100%\\nMiddle click: turn turbo off\"}"
elif [ -f "$state" ]; then
    echo "{\"text\":\"󰊴 $icon\",\"class\":\"game\",\"tooltip\":\"Game mode ON ($p)\\nRight click: turn game mode off\"}"
else
    echo "{\"text\":\"$icon\",\"class\":\"${p,,}\",\"tooltip\":\"Profile: $p\\nLeft click: change profile  ·  Right click: game mode  ·  Middle click: turbo (fans 100%)\"}"
fi
