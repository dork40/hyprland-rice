#!/bin/sh
# Toggle dictation between English-only and "any language -> English" (restarts voxtype to apply)
cfg="$HOME/.config/voxtype/config.toml"
if grep -q '^translate = true' "$cfg"; then
    sed -i -e 's/^translate = true/translate = false/' -e 's/^language = "auto"/language = "en"/' "$cfg"
    msg="Dictation: English only"
else
    sed -i -e 's/^translate = false/translate = true/' -e 's/^language = "en"/language = "auto"/' "$cfg"
    msg="Dictation: translating to English"
fi
# (no notification: user turned Voxtype notifications off)
pkill -f '^voxtype -q daemon'   # voxtype-run.sh restarts it with the new config
