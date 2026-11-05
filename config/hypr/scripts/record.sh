#!/usr/bin/env bash
# Area screen recording with wf-recorder, for the Waybar camera button.
#   (no arg)  print waybar JSON (camera icon, red while recording)
#   toggle    stop the current recording, or open the menu (region / window / full screen / audio / GIF)
#   start M S [Q] start straight away: M = region|window|screen|gif, S = none|mic|system|both, Q = native60|nativemax|hevc60|1440p|1080p|720p
dir=~/Videos/Recordings
pidf=${XDG_RUNTIME_DIR:-/tmp}/record.pid
startf=${XDG_RUNTIME_DIR:-/tmp}/record.start
discordf=~/.config/rices/record-discord

refresh()   { pkill -RTMIN+15 waybar; }
recording() { [ -f "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; }

# discord_shrink IN OUT: re-encode IN to H.264/AAC so OUT stays under 50 MB (the Discord upload limit on this account).
# Picks the bitrate from the clip length (two-pass), lowers the resolution for long clips, retries smaller if it overshoots.
discord_shrink() {
    local in=$1 out=$2 dur limit=46000000 audio_k=96 total vk scale tries=0 log=${XDG_RUNTIME_DIR:-/tmp}/record-pass
    dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$in" | cut -d. -f1)
    [ -z "$dur" ] || [ "$dur" -lt 1 ] && dur=1
    total=$(( limit * 8 / dur / 1000 ))          # kbit/s we may spend on audio + video together
    vk=$(( total - audio_k )); [ "$vk" -lt 80 ] && vk=80
    while [ $tries -lt 3 ]; do
        if   [ "$vk" -ge 1800 ]; then scale="scale='min(1920,iw)':-2"
        elif [ "$vk" -ge 900 ];  then scale="scale='min(1280,iw)':-2"
        elif [ "$vk" -ge 400 ];  then scale="scale='min(854,iw)':-2"
        else                          scale="scale='min(640,iw)':-2"; fi
        ffmpeg -loglevel error -y -i "$in" -vf "fps=30,$scale,format=yuv420p" -c:v libx264 -preset medium -b:v "${vk}k" \
            -pass 1 -passlogfile "$log" -an -f null /dev/null &&
        ffmpeg -loglevel error -y -i "$in" -vf "fps=30,$scale,format=yuv420p" -c:v libx264 -preset medium -b:v "${vk}k" \
            -pass 2 -passlogfile "$log" -c:a aac -b:a "${audio_k}k" -movflags +faststart "$out" || { rm -f "$log"*; return 1; }
        rm -f "$log"*
        [ "$(stat -c %s "$out")" -le 49500000 ] && return 0
        vk=$(( vk * 80 / 100 )); tries=$((tries + 1))   # overshot: try again 20% smaller
    done
    return 1
}

# boost_audio FILE: the mic input is quiet (15% input volume), so lift a quiet recording's audio to a normal level.
# Video is copied untouched, only the audio is re-encoded; gain is capped so silence is not blown up too far.
boost_audio() {
    local f=$1 peak gain tmp=${1%.mp4}-boost.mp4
    peak=$(ffmpeg -hide_banner -i "$f" -af volumedetect -vn -f null /dev/null 2>&1 | sed -n 's/.*max_volume: \(-\?[0-9.]*\) dB.*/\1/p')
    [ -z "$peak" ] && return 0
    gain=$(awk -v p="$peak" 'BEGIN { g = -2 - p; if (g > 24) g = 24; if (g < 1) g = 0; printf "%d", g }')
    [ "$gain" -ge 1 ] || return 0
    ffmpeg -loglevel error -y -i "$f" -c:v copy -af "volume=${gain}dB,alimiter=limit=0.95" -c:a aac -b:a 128k "$tmp" && mv "$tmp" "$f"
}

# encoder QUALITY: fills the enc array. QUALITY: native60 (default) | nativemax | hevc60 | 1440p | 1080p | 720p
# Uses the GPU's hardware encoder (low CPU, good for games) at native resolution; scaled options keep the aspect ratio and never upscale.
# Falls back to software x264 if the GPU has no VA-API encoder. RECORD_VAAPI_DEVICE overrides the device.
encoder() {
    local q=${1:-native60} h= codec=h264 fps=60 dev=${RECORD_VAAPI_DEVICE:-/dev/dri/renderD128} info=
    case $q in nativemax) fps=0 ;; hevc60) codec=hevc ;; 1440p) h=1440 ;; 1080p) h=1080 ;; 720p) h=720 ;; esac
    enc=()
    [ -e "$dev" ] && info=$(vainfo --display drm --device "$dev" 2>/dev/null)
    if grep -qi "VAProfileH264.*EncSlice" <<<"$info"; then
        if [ $codec = hevc ] && ! grep -qi "VAProfileHEVC.*EncSlice" <<<"$info"; then codec=h264; fi
        if [ $codec = hevc ]; then enc+=(-c hevc_vaapi -d "$dev" -p qp=20); else enc+=(-c h264_vaapi -d "$dev" -p qp=18); fi
        [ -n "$h" ] && enc+=(-F "scale_vaapi=w=-2:h='min(ih,$h)':format=nv12:out_range=full")
    else
        enc+=(-c libx264 -x yuv420p -p preset=veryfast -p crf=18)
        [ -n "$h" ] && enc+=(-F "scale=-2:'min(ih,$h)'")
    fi
    [ "$fps" != 0 ] && enc+=(-r "$fps")
}

case "$1" in
  click)   # left click: stop if recording, otherwise screenshot an area
    if recording; then kill -INT "$(cat "$pidf")"; else exec ~/.config/hypr/scripts/screenshot.sh region; fi
    exit ;;
  dot)     # big red dot next to the clock, empty (hidden) when not recording
    if recording; then echo '{"text":"●","class":"on","tooltip":"Recording the screen"}'; else echo '{"text":""}'; fi
    exit ;;
  toggle)
    # Stopping: wf-recorder finishes the file on SIGINT; the starter below reports it
    if recording; then kill -INT "$(cat "$pidf")"; exit; fi

    if [ -e "$discordf" ]; then dmode="Discord mode: ON (click to turn off)"; else dmode="Discord mode: off (click to shrink every clip under 50 MB)"; fi
    pick=$(printf '%s\n' "Region" "Window" "Full screen" "GIF of a region" "$dmode" |
        wofi --dmenu --prompt "Record" --lines 5 --insensitive) || exit 0
    case $pick in
      "Region"*)      mode=region ;;
      "Window"*)      mode=window ;;
      "Full screen"*) mode=screen ;;
      "GIF"*)         mode=gif ;;
      "Discord mode"*)
        if [ -e "$discordf" ]; then rm -f "$discordf"; notify-send -t 2500 "Discord mode off" "Clips are saved at full size again"
        else mkdir -p "$(dirname "$discordf")"; touch "$discordf"; notify-send -t 3500 "Discord mode on" "Every recording is shrunk under 50 MB and copied, ready to paste into Discord"; fi
        exit 0 ;;
      *) exit 0 ;;
    esac
    if [ "$mode" = gif ]; then sound=none; else
        snd=$(printf '%s\n' "No sound" "Microphone" "Laptop audio" "Microphone + laptop audio" |
            wofi --dmenu --prompt "Sound" --lines 4 --insensitive) || exit 0
        case $snd in
          "Microphone + laptop"*) sound=both ;;
          "Microphone"*)          sound=mic ;;
          "Laptop audio"*)        sound=system ;;
          *)                      sound=none ;;
        esac
    fi
    qual=native60
    if [ "$mode" != gif ] && [ ! -e "$discordf" ]; then
        q=$(printf '%s\n' "Native · 60 fps (best for gaming)" "Native · max fps (up to 165, big files)" "Native · 60 fps · HEVC (smaller files)" "1440p · 60 fps" "1080p · 60 fps" "720p · 60 fps" |
            wofi --dmenu --prompt "Quality" --lines 6 --insensitive) || exit 0
        case $q in
          "Native · max"*) qual=nativemax ;;
          *HEVC*)          qual=hevc60 ;;
          1440p*)          qual=1440p ;;
          1080p*)          qual=1080p ;;
          720p*)           qual=720p ;;
        esac
    fi
    exec "$0" start "$mode" "$sound" "$qual" ;;

  start)   # start MODE SOUND [QUALITY]: region|window|screen|gif, sound none|mic|system|both, quality see encoder() (used by the menu above)
    command -v wf-recorder >/dev/null || { notify-send "Screen recording" "wf-recorder isn't installed: sudo pacman -S wf-recorder"; exit 1; }
    recording && exit 0
    mode=$2 sound=${3:-none} qual=${4:-native60}
    case $sound in 0) sound=none ;; 1) sound=system ;; esac
    discord=0; [ -e "$discordf" ] && discord=1
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
    mixmods=
    case $sound in
      mic)    args+=(--audio="$(pactl get-default-source)") ;;
      system) args+=(--audio="$(pactl get-default-sink).monitor") ;;
      both)   # wf-recorder takes one audio device: mix the mic and the laptop's sound into a temporary virtual one
        mixmods="$(pactl load-module module-null-sink sink_name=rec_mix sink_properties=device.description=rec_mix)"
        mixmods="$mixmods $(pactl load-module module-loopback source="$(pactl get-default-source)" sink=rec_mix latency_msec=30)"
        mixmods="$mixmods $(pactl load-module module-loopback source="$(pactl get-default-sink).monitor" sink=rec_mix latency_msec=30)"
        args+=(--audio=rec_mix.monitor) ;;
    esac
    if [ "$mode" != gif ]; then encoder "$qual"; args+=("${enc[@]}"); fi
    mkdir -p "$dir"
    stamp=$(date +%Y-%m-%d_%I-%M-%S%p)
    file="$dir/$stamp.mp4"
    [ "$mode" = gif ] && file="${XDG_RUNTIME_DIR:-/tmp}/record-$stamp.mp4"
    [ "$discord" = 1 ] && file="${XDG_RUNTIME_DIR:-/tmp}/record-$stamp.mp4"

    wf-recorder "${args[@]}" -f "$file" >/dev/null 2>&1 &
    echo $! >"$pidf"; date +%s >"$startf"
    refresh
    ( while recording; do sleep 1; refresh; done ) &   # live timer in the bar
    notify-send -t 2500 "Recording started" "Click the REC pill in the bar to stop"

    wait $!
    rm -f "$pidf" "$startf"
    for m in $mixmods; do pactl unload-module "$m" 2>/dev/null; done
    refresh
    case $sound in mic|both) [ -s "$file" ] && boost_audio "$file" ;; esac
    if [ "$mode" = gif ] && [ -s "$file" ]; then
        gif="$dir/$stamp.gif"
        ffmpeg -loglevel error -y -i "$file" -vf "fps=12,scale='min(800,iw)':-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" "$gif"
        rm -f "$file"; file=$gif
    fi
    if [ "$discord" = 1 ] && [ -s "$file" ]; then
        out="$dir/$stamp-discord.mp4"
        notify-send -t 4000 "Discord clip" "Shrinking to fit under 50 MB…"
        if discord_shrink "$file" "$out"; then
            rm -f "$file"; file=$out
            command -v wl-copy >/dev/null && printf 'file://%s\n' "$file" | wl-copy --type text/uri-list
            notify-send "Discord clip ready ($(du -h "$file" | cut -f1))" "Copied: paste it into Discord (Ctrl+V), or drag $file"
            exit
        fi
        rm -f "$out"   # shrinking failed: keep the full-size recording instead
        mv "$file" "$dir/$stamp.mp4"; file="$dir/$stamp.mp4"
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
    printf '{"text":"󰄀 <span foreground=\\"#ff3b3b\\" size=\\"large\\">●</span>","class":"recording","tooltip":"Recording the screen (%02d:%02d).\\nClick to stop."}\n' $((e/60)) $((e%60))
else
    echo '{"text":"󰄀","class":"idle","tooltip":"Left click: screenshot an area\nRight click: record an area (click again to stop)"}'
fi
