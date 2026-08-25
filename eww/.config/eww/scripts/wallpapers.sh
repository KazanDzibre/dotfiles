#!/usr/bin/env bash
# Build (and cache) thumbnails for ~/Wallpapers, then emit them as JSON rows for
# the picker popup.
#
# Rows rather than a flat list because eww has no grid widget -- the popup nests
# two `for` loops to lay the thumbnails out.
#
# Thumbnails are keyed by the full filename including extension: the folder holds
# both stallman-2.jpg and stallman-2.png, which would otherwise collide.

set -uo pipefail

DIR="$HOME/Wallpapers"
CACHE="$HOME/.cache/eww/wallpapers"
COLS=4
GEOM="240x135"

mkdir -p "$CACHE"

# Only still images: the swaybg backend cannot display the .mp4 in that folder.
images() {
    find "$DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        | sort
}

while IFS= read -r src; do
    [ -n "$src" ] || continue
    thumb="$CACHE/$(basename "$src").png"
    if [ ! -f "$thumb" ] || [ "$src" -nt "$thumb" ]; then
        # [0] takes the first frame, so a multi-page image cannot explode into
        # dozens of output files.
        convert "${src}[0]" -thumbnail "${GEOM}^" -gravity center \
            -extent "$GEOM" "$thumb" 2>/dev/null
    fi
done < <(images)

images | jq -R -s --arg cache "$CACHE" --argjson cols "$COLS" '
  split("\n")
  | map(select(length > 0))
  | map({
      path:  .,
      name:  (split("/") | last),
      thumb: ($cache + "/" + (split("/") | last) + ".png")
    })
  | . as $items
  | [ range(0; ($items | length); $cols) | $items[.:(. + $cols)] ]
'
