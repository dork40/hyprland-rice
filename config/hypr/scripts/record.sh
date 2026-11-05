#!/usr/bin/env bash
# Area screen recording with wf-recorder, for the Waybar camera button.
#   (no arg)  print waybar JSON (camera icon, red while recording)
#   toggle    stop the current recording, or open the menu (region / window / full screen / audio / GIF)
#   start M A start straight away: M = region|window|screen|gif, A = 0|1 for system audio
dir=~/Videos/Recordings
pidf=${XDG_RUNTIME_DIR:-/tmp}/record.pid
startf=${XDG_RUNTIME_DIR:-/tmp}/record.start

refresh()   { pkill -RTMIN+15 waybar; }
recording() { [ -f "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; }

case "$1" in
  click)   # left click: stop if recording, otherwise screenshot an area
    if recording; then kill -INT "$(cat "$pidf")"; else exec ~/.config/hypr/scripts/screenshot.sh region; fi
    exit ;;
  toggle)
    # Stopping: wf-recorder finishes the file on SIGINT; the starter below reports it
    if recording; then kill -INT "$(cat "$pidf")"; exit; fi

    pick=$(printf '%s\n' "Region" "Window" "Full screen" "Region + system audio" "Window + system audio" "Full screen + system audio" "GIF of a region" |
        wofi --dmenu --prompt "Record" --lines 7 --insensitive) || exit 0
    case $pick in
      "Region"*)      mode=region ;;
      "Window"*)      mode=window ;;
      "Full screen"*) mode=screen ;;
      "GIF"*)         mode=gif ;;
      *) exit 0 ;;
    esac
    [[ $pick == *audio* ]] && audio=1 || audio=0
    exec "$0" start "$mode" "$audio" ;;

  start)   # start MODE AUDIO: region|window|screen|gif, audio 0|1 (used by the menu above)
    command -v wf-recorder >/dev/null || { notify-send "Screen recording" "wf-recorder isn't installed: sudo pacman -S wf-recorder"; exit 1; }
    recording && exit 0
    mode=$2 audio=${3:-0}
    args=()
    case $mode in
      region|gif) geom=$(slurp) || exit 1 ;;
      window)     geom=$(hyprctl -j activewindow | python3 -Ic 'import json,sys; w=json.load(sys.stdin); print("%d,%d %dx%d" % (*w["at"], *w["size"]))') ;;
      screen)     args+=(-o "$(hyprctl -j monitors | python3 -Ic 'import json,sys; m=json.load(sys.stdin); print(next((x["name"] for x in m if x.get("focused")), m[0]["name"]))')") ;;
    esac
    if [ -n "$geom" ]; then
        # x264 needs an even width and height
        geom=$(awk '{ split($2, s, "x"); printf "%s %dx%d", $1, s[1] - s[1] % 2, s[2] - s[2] % 2 }' <<<"$geom")
        args+=(-g "$geom")
    fi
    [ "$audio" = 1 ] && args+=(--audio="$(pactl get-default-sink).monitor")
    mkdir -p "$dir"
    stamp=$(date +%Y-%m-%d_%I-%M-%S%p)
    file="$dir/$stamp.mp4"
    [ "$mode" = gif ] && file="${XDG_RUNTIME_DIR:-/tmp}/record-$stamp.mp4"

    wf-recorder "${args[@]}" -f "$file" >/dev/null 2>&1 &
    echo $! >"$pidf"; date +%s >"$startf"
    refresh
    ( while recording; do sleep 1; refresh; done ) &   # live timer in the bar
    notify-send -t 2500 "Recording started" "Click the REC pill in the bar to stop"

    wait $!
    rm -f "$pidf" "$startf"
    refresh
    if [ "$mode" = gif ] && [ -s "$file" ]; then
        gif="$dir/$stamp.gif"
        ffmpeg -loglevel error -y -i "$file" -vf "fps=12,scale='min(800,iw)':-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" "$gif"
        rm -f "$file"; file=$gif
    fi
    if [ -s "$file" ]; then
        notify-send "Recording saved" "$file"
    else
        rm -f "$file"; notify-send "Recording failed" "Nothing was saved"
    fi
    exit ;;
esac

if recording; then
    e=$(( $(date +%s) - $(cat "$startf" 2>/dev/null || date +%s) ))
    printf '{"text":"󰑊  REC %02d:%02d","class":"recording","tooltip":"Recording the screen.\\nClick to stop."}\n' $((e/60)) $((e%60))
else
    echo '{"text":"󰄀","class":"idle","tooltip":"Left click: screenshot an area\nRight click: record an area (click again to stop)"}'
fi
