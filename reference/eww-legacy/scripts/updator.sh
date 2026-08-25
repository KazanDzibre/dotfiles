#!/usr/bin/env sh

UPDATES_DIR="/tmp/updates"
ICON="󰮯"
GHOST_ICON="󰊠"
INTERVAL_MINUTES=10

# Exit early on snapshot boots (keep if using Timeshift/BTRFS)
if grep -q 'subvol=@/.snapshots' /proc/cmdline; then
  exit
fi

mkdir -p "$UPDATES_DIR"

check_and_write_updates() {
  # Update the local package index first (Requires sudo or a NOPASSWD rule)
  # If you don't have sudo rights, apt will only check against the last time you ran update.
  sudo apt-get update > /dev/null 2>&1

  # Official Apt Repos
  # We simulate an upgrade and grep for lines starting with 'Inst' (Install)
  apt_list=$(apt-get -s upgrade 2>/dev/null | grep "^Inst")
  
  echo "$apt_list" > "$UPDATES_DIR/official_list"
  ofc=$(echo "$apt_list" | grep -c "^Inst")
  echo "$ofc" > "$UPDATES_DIR/official"

  # Flatpak (Logic remains the same as it's distro-agnostic)
  if command -v flatpak >/dev/null 2>&1; then
    flatpak remote-ls --updates 2>/dev/null \
      | tee "$UPDATES_DIR/flatpak_list" >/dev/null
    fpk=$(wc -l < "$UPDATES_DIR/flatpak_list")
  else
    fpk=0
    : > "$UPDATES_DIR/flatpak_list"
  fi
  echo "$fpk" > "$UPDATES_DIR/flatpak"

  # AUR doesn't exist on Debian/Ubuntu, so we'll just set it to 0
  echo "0" > "$UPDATES_DIR/aur"
  : > "$UPDATES_DIR/aur_list"
}

boldify_ascii() {
  INPUT="$1"
  echo "$INPUT" | perl -CS -pe '
    s/([A-Z])/chr(ord($1) + 0x1D400 - ord("A"))/ge;
    s/([a-z])/chr(ord($1) + 0x1D41A - ord("a"))/ge;
  '
}

generate_json_output() {
  ofc=$(< "$UPDATES_DIR/official")
  fpk=$(< "$UPDATES_DIR/flatpak")
  total=$((ofc + fpk))

  if (( total == 0 )); then
    echo "{\"icon\": \"\", \"ghost\": \"${GHOST_ICON}\", \"count\": \"\", \"tooltip\": \"System Up to Date\"}"
    return
  fi

  tooltip=$(
    # Format apt output to match the expected "pkg version" style
    cat "$UPDATES_DIR/official_list" 2>/dev/null | sed 's/^Inst //' | sed 's/ (.*//' > "$UPDATES_DIR/temp_list"
    cat "$UPDATES_DIR/temp_list" "$UPDATES_DIR/flatpak_list" 2>/dev/null \
    | sed '/^$/d' \
    | while IFS= read -r line; do
        pkg="${line%% *}"
        rest="${line#* }"
        boldpkg=$(boldify_ascii "$pkg")
        printf ' %s %s\n' "$boldpkg" "$rest"
      done \
    | sed -z 's/\n/\\n/g'
  )

  tooltip="${tooltip%\\n}"
  echo "{\"icon\": \"${ICON}\", \"ghost\": \"${GHOST_ICON}\", \"count\": \"${total}\", \"tooltip\": \"$tooltip\"}"
}

while true; do
  check_and_write_updates
  generate_json_output
  sleep $((INTERVAL_MINUTES * 60))
done
