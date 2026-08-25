#!/usr/bin/env bash
# Stream a compact spectrum for the media button's equalizer.
#
# cava reads the default audio output's monitor, so this reacts to whatever is
# actually coming out of the speakers -- Spotify, a browser tab, anything.
#
# 20fps rather than 60: every frame is a variable update that re-renders the
# label on every bar, and the difference is not visible at eight characters.

set -uo pipefail

printf '%s\n' \
    '[general]' \
    'framerate=20' \
    'bars=8' \
    'autosens=1' \
    '[output]' \
    'method=raw' \
    'raw_target=/dev/stdout' \
    'data_format=ascii' \
    'ascii_max_range=7' \
  | cava -p /dev/stdin \
  | sed -u 's/;//g; s/0/▁/g; s/1/▂/g; s/2/▃/g; s/3/▄/g; s/4/▅/g; s/5/▆/g; s/6/▇/g; s/7/█/g'
