#!/usr/bin/env bash
# Bring an Arch (or CachyOS) box up to this repo's desktop: Hyprland + the
# Quickshell bar, pywal-driven colours, the lock screen, fingerprint unlock.
# The Ubuntu laptop has its own script, install.sh, next to this one.
#
# Run it as your normal user from a real terminal: it calls sudo for pacman and
# will ask for your password there.
#
#   bootstrap/install-arch.sh           packages, then a check
#   bootstrap/install-arch.sh packages  only install what's missing
#   bootstrap/install-arch.sh check     report what's present, change nothing
#
# Idempotent: pacman runs with --needed, so re-running only fills gaps. A few
# packages are in the CachyOS repos but only in the AUR on plain Arch; each of
# those is tried with pacman first and handed to yay/paru if pacman doesn't
# know it. Configs aren't linked here: stow them yourself (see the end).
set -uo pipefail

# ---------------------------------------------------------------- packages
# Grouped by what needs them, so it's clear what can be left out.
PACKAGES=(
  # Compositor and its tools
  hyprland hyprlock hypridle hyprpaper hyprpicker hyprsunset
  xdg-desktop-portal-hyprland polkit-kde-agent

  # The bar: Quickshell (CachyOS's build, called noctalia-qs), and what it runs
  noctalia-qs
  imagemagick       # wallpaper thumbnails, cover and app colours
  cava              # the island's music visualiser
  playerctl         # media keys, the lock screen's "now playing"
  wl-clipboard      # clipboard history, copying from the island
  grim slurp        # screenshots, recording a region
  wf-recorder       # screen recording
  pipewire pipewire-pulse wireplumber libpulse   # sound, pw-play, pactl
  brightnessctl     # brightness keys and slider
  mpv               # the healing tones
  libnotify         # notify-send (screenshots announce themselves)
  xdg-utils         # xdg-open
  upower            # battery
  networkmanager bluez bluez-utils   # Wi-Fi and Bluetooth panels
  qrencode          # the wifiqr search command
  pacman-contrib    # checkupdates, for the updates badge
  curl jq sqlite python
  python-icalendar python-recurring-ical-events   # Google Calendar in the island

  # Wallpaper and colours
  waypaper python-pywal

  # Fonts the configs name, and colour emoji for the emoji picker
  ttf-fantasque-nerd ttf-jetbrains-mono-nerd noto-fonts-emoji

  # Fingerprint unlock (enrol with `fprintd-enroll`)
  fprintd

  # Everyday tools the binds launch
  alacritty neovim fish stow

  # Zed (zed/), and stylua, which it formats Lua with on save
  zed stylua
)

# Programs the config calls, and which package brings each: what `check` reports.
COMMANDS=(
  quickshell:noctalia-qs hyprland:hyprland hyprlock:hyprlock hypridle:hypridle
  hyprpaper:hyprpaper hyprpicker:hyprpicker hyprsunset:hyprsunset
  waypaper:waypaper wal:python-pywal magick:imagemagick cava:cava
  playerctl:playerctl wl-copy:wl-clipboard grim:grim slurp:slurp
  wf-recorder:wf-recorder pw-play:pipewire pactl:libpulse wpctl:wireplumber
  brightnessctl:brightnessctl mpv:mpv notify-send:libnotify xdg-open:xdg-utils
  upower:upower nmcli:networkmanager bluetoothctl:bluez-utils qrencode:qrencode
  checkupdates:pacman-contrib curl:curl jq:jq sqlite3:sqlite python3:python
  fprintd-verify:fprintd alacritty:alacritty nvim:neovim fish:fish stow:stow
  zeditor:zed stylua:stylua
)

say() { printf '\033[1m%s\033[0m\n' "$*"; }

aur_helper() {
  for h in yay paru; do
    command -v "$h" >/dev/null 2>&1 && { echo "$h"; return; }
  done
}

install_packages() {
  local repo=() aur=() p
  say "Checking which packages pacman can install..."
  for p in "${PACKAGES[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 && continue          # already installed
    if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
  done

  if ((${#repo[@]})); then
    say "Installing from the repos: ${repo[*]}"
    sudo pacman -S --needed "${repo[@]}" || say "pacman reported a problem (see above); carrying on."
  else
    say "Everything available from the repos is already installed."
  fi

  if ((${#aur[@]})); then
    local helper
    helper=$(aur_helper)
    if [[ -n "$helper" ]]; then
      say "Installing from the AUR with $helper: ${aur[*]}"
      "$helper" -S --needed "${aur[@]}" || say "$helper reported a problem (see above); carrying on."
    else
      say "Not in your repos, and no AUR helper (yay or paru) to fetch them: ${aur[*]}"
      say "Install yay (https://github.com/Jguer/yay), then run this again."
    fi
  fi
}

check() {
  local missing=0 entry cmd pkg
  say "Programs the desktop uses:"
  for entry in "${COMMANDS[@]}"; do
    cmd=${entry%%:*}
    pkg=${entry#*:}
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf '  missing  %-15s (package: %s)\n' "$cmd" "$pkg"
      missing=1
    fi
  done
  ((missing)) || echo "  all present"

  say "Python libraries:"
  python3 -c "import icalendar, recurring_ical_events" 2>/dev/null &&
    echo "  calendar libraries present" ||
    echo "  missing python-icalendar / python-recurring-ical-events (the island's calendar)"

  say "Things only you can set up (none of them stop the desktop working):"
  [[ -f "$HOME/.config/hypr/secrets.conf" ]] &&
    echo "  ~/.config/hypr/secrets.conf exists (API keys)" ||
    echo "  no ~/.config/hypr/secrets.conf: AI chat and GIF search have no keys. Lines like:  env = QS_AI_API_KEY,<key>"
  grep -qs '^env = QS_GIPHY_API_KEY,' "$HOME/.config/hypr/secrets.conf" ||
    echo "  no QS_GIPHY_API_KEY: GIF search stays off (free key at developers.giphy.com)"
  [[ -s "$HOME/.local/share/quickshell/calendar-url" ]] &&
    echo "  Google Calendar link saved" ||
    echo "  no Google Calendar link: save the secret iCal address to ~/.local/share/quickshell/calendar-url"
  if command -v fprintd-list >/dev/null 2>&1; then
    fprintd-list "$USER" 2>/dev/null | grep -q 'finger' &&
      echo "  a fingerprint is enrolled" ||
      echo "  no fingerprint enrolled: run fprintd-enroll"
  fi

  # -t ~ matters: the repo lives in ~/Nuketown, and stow's default target is
  # the repo's parent, so a bare `stow` links into ~/Nuketown/.config.
  say "Configs are linked with stow from the repo root, for example:"
  echo "  cd $(cd "$(dirname "$(readlink -f "$0")")/.." && pwd) && stow -t ~ hypr quickshell nvim wal fish screensaver starship zed wireplumber"
  echo "  (not waypaper on Arch: its config.ini points at the Ubuntu laptop's post-command"
  echo "   script, so keep a local ~/.config/waypaper/config.ini that runs post-command.sh)"
}

case "${1:-all}" in
  packages) install_packages ;;
  check) check ;;
  all) install_packages; echo; check ;;
  *) echo "usage: $0 [packages|check]" >&2; exit 2 ;;
esac
