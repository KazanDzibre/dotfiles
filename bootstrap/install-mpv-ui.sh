#!/usr/bin/env bash
# mpv's player UI: uosc, plus thumbfast for previews on the seek bar.
# Arch and Ubuntu.
#
#   bootstrap/install-mpv-ui.sh          install them
#   bootstrap/install-mpv-ui.sh check    report what's installed, change nothing
#
# Both are downloaded from pinned, checksummed releases into ~/.config/mpv
# (scripts/, fonts/), so both laptops get the same versions and no sudo is
# needed. They are not in the repo; the settings are (mpv stow package:
# mpv.conf, input.conf, script-opts/uosc.conf). theme-sync colours uosc for the
# wallpaper. Safe to re-run.
set -uo pipefail

UOSC_VERSION=5.13.0
UOSC_SHA256=4be9da3289285300fa374496c3f1bfd7bb20ac08e890d25bd5a06b28eebe4882
UOSC_URL=https://github.com/tomasklaen/uosc/releases/download/$UOSC_VERSION/uosc.zip
THUMBFAST_COMMIT=0f711de3138c9bd6718209d819ac54022c23ded2
THUMBFAST_SHA256=a3d08e71eae8b892f6cd39f9593ea219768e709312d176bca883841b156448bf
THUMBFAST_URL=https://raw.githubusercontent.com/po5/thumbfast/$THUMBFAST_COMMIT/thumbfast.lua

repo=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
mpv=$HOME/.config/mpv

say() { printf '\033[1m%s\033[0m\n' "$*"; }
row() { printf '  %-8s %s\n' "$1" "$2"; }

check() {
  say "mpv UI:"
  if [[ -e $mpv/scripts/uosc/main.lua ]]; then row ok "uosc $(cat "$mpv/scripts/uosc/.version" 2>/dev/null || echo '?')"
  else row missing "uosc not installed"; fi
  if [[ -e $mpv/scripts/thumbfast.lua ]]; then row ok "thumbfast"
  else row missing "thumbfast not installed"; fi
  if [[ $(readlink -f "$mpv/mpv.conf") == "$repo/mpv/.config/mpv/mpv.conf" ]]; then row ok "settings linked"
  else row no "settings not linked: cd $repo && stow -t ~ mpv"; fi
  if [[ -e $HOME/.cache/wal/mpv.conf ]]; then row ok "colours from the wallpaper"
  else row no "no colours yet (theme-sync mpv, or the next wallpaper change)"; fi
}

fetch() { # url sha256 dest
  curl -fsSL -o "$3" "$1" || { echo "Download failed: $1" >&2; return 1; }
  echo "$2  $3" | sha256sum -c --quiet - || { echo "Checksum mismatch, not installing: $1" >&2; return 1; }
}

# ~/.config/mpv must be a real directory: if stow folded it into one link to
# the repo, the scripts would land in the repo. Unfold it first.
unfold() {
  [[ -L $mpv ]] || { mkdir -p "$mpv"; return 0; }
  rm "$mpv" && mkdir -p "$mpv" && (cd "$repo" && stow -t ~ mpv)
}

install_ui() {
  unfold || return 1
  local tmp
  tmp=$(mktemp -d) || return 1
  trap 'rm -rf "$tmp"' RETURN

  if [[ $(cat "$mpv/scripts/uosc/.version" 2>/dev/null) == "$UOSC_VERSION" ]]; then
    say "uosc $UOSC_VERSION already installed."
  else
    say "Downloading uosc $UOSC_VERSION..."
    fetch "$UOSC_URL" "$UOSC_SHA256" "$tmp/uosc.zip" || return 1
    mkdir -p "$tmp/uosc" && unzip -q "$tmp/uosc.zip" -d "$tmp/uosc" || return 1
    mkdir -p "$mpv/scripts" "$mpv/fonts"
    rm -rf "$mpv/scripts/uosc"
    mv "$tmp/uosc/scripts/uosc" "$mpv/scripts/uosc"
    cp -f "$tmp/uosc/fonts/"* "$mpv/fonts/"
    echo "$UOSC_VERSION" >"$mpv/scripts/uosc/.version"
  fi

  say "thumbfast ${THUMBFAST_COMMIT:0:7}..."
  fetch "$THUMBFAST_URL" "$THUMBFAST_SHA256" "$tmp/thumbfast.lua" || return 1
  mkdir -p "$mpv/scripts" && mv -f "$tmp/thumbfast.lua" "$mpv/scripts/thumbfast.lua"

  local sync
  sync=$(command -v theme-sync || echo "$repo/wal/.local/bin/theme-sync")
  if [[ -e $HOME/.cache/wal/colors.json ]]; then
    "$sync" mpv >/dev/null || echo "theme-sync mpv failed; uosc keeps its default colours." >&2
  fi
}

case ${1:-} in
  check) check ;;
  "")
    install_ui || exit 1
    echo
    check
    ;;
  *) echo "usage: $0 [check]" >&2; exit 2 ;;
esac
