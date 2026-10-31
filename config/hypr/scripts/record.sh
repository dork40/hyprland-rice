#!/usr/bin/env bash
# Area screen recording with wf-recorder, for the Waybar camera button.
#   (no arg)  print waybar JSON (camera icon, red while recording)
#   toggle    pick an area with slurp and start recording, or stop the current recording
dir=~/Videos/Recordings
pidf=${XDG_RUNTIME_DIR:-/tmp}/record.pid

refresh()   { pkill -RTMIN+15 waybar; }
recording() { [ -f "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; }

case "$1" in
  toggle)
    # Stopping: wf-recorder finishes the file on SIGINT; the starter below reports it
    if recording; then kill -INT "$(cat "$pidf")"; exit; fi

    command -v wf-recorder >/dev/null || { notify-send "Screen recording" "wf-recorder isn't installed: sudo pacman -S wf-recorder"; exit 1; }
    geom=$(slurp) || exit 1
    # x264 needs an even width and height
    geom=$(awk '{ split($2, s, "x"); printf "%s %dx%d", $1, s[1] - s[1] % 2, s[2] - s[2] % 2 }' <<<"$geom")
    mkdir -p "$dir"
    file="$dir/$(date +%Y-%m-%d_%I-%M-%S%p).mp4"

    wf-recorder -g "$geom" -f "$file" >/dev/null 2>&1 &
    echo $! >"$pidf"
    refresh
    notify-send -t 2500 "Recording started" "Right click the camera again to stop"

    wait $!
    rm -f "$pidf"
    refresh
    if [ -s "$file" ]; then
        notify-send "Recording saved" "$file"
    else
        rm -f "$file"; notify-send "Recording failed" "Nothing was saved"
    fi
    exit ;;
esac

if recording; then
    echo '{"text":"󰄀","class":"recording","tooltip":"Recording… right click to stop"}'
else
    echo '{"text":"󰄀","class":"idle","tooltip":"Left click: screenshot an area\nRight click: record an area (right click again to stop)"}'
fi
