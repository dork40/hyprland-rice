#!/bin/sh
# Hold-to-talk for voxtype. start: on key press, stop: on key release.
# stop is a no-op unless a hold recording is running, so tap modes are unaffected. Logs to ~/.cache/voxtype-hold.log.
run="${XDG_RUNTIME_DIR:-/tmp}"
hold="$run/voxtype-hold"
spoke="$run/voxtype-spoke"
# Runs on every Z / Super release: bail out instantly unless a hold recording is active.
[ "$1" = stop ] && [ ! -e "$hold" ] && exit 0
log() { echo "$(date +"%I:%M:%S.%3N %p") $*" >> "$HOME/.cache/voxtype-hold.log"; }
log "$1 (hold marker: $([ -e "$hold" ] && echo yes || echo no), status: $(voxtype status))"
case "$1" in
start)
    rm -f "$spoke"
    touch "$hold"
    voxtype record start || { rm -f "$hold"; exit 1; }
    setsid -f "$HOME/.config/voxtype/hold-watch.py" >/dev/null 2>&1
    ;;
stop)
    mv "$hold" "$hold.$$" 2>/dev/null || exit 0   # atomic: if two triggers fire at once, only one stops
    rm -f "$hold.$$"
    log "  trigger: ${2:-?}"
    if [ -e "$spoke" ]; then
        voxtype record stop; log "  -> stop (speech heard)"
    else
        voxtype record cancel; log "  -> cancel (no speech heard)"   # nothing was said: drop it so Whisper can't invent text
    fi
    rm -f "$spoke"
    ;;
esac
