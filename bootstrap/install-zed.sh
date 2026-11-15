#!/usr/bin/env bash
# Everything the Zed config in zed/ needs on an Arch (or CachyOS) laptop, and
# the link that makes Zed use it.
#
#   bootstrap/install-zed.sh          install what's missing, link, then check
#   bootstrap/install-zed.sh check    report what's present, change nothing
#
# Run it as your normal user; it calls sudo for pacman. Safe to re-run.
#
# What Zed fetches by itself, so it isn't here: the extensions listed under
# "auto_install_extensions" in settings.json (themes, icon themes, language
# support) and most language servers (rust-analyzer, basedpyright, ruff,
# marksman, Roslyn for C#...). Those arrive the next time Zed starts.
set -uo pipefail

repo=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)

# package:why, in the order they're reported.
PACKAGES=(
  "zed:the editor (its command is zeditor on Arch)"
  "ttf-fantasque-nerd:the editor and terminal font, FantasqueSansM Nerd Font Mono"
  "stylua:formats Lua on save"
  "gnome-keyring:somewhere for Zed to keep logins and API keys (KWallet doesn't start under Hyprland)"
  "git:the git panel, gutter and blame"
  "nodejs:Prettier and the JSON/YAML/CSS servers"
  "rust:cargo and clippy, for Rust checks on save"
  "dotnet-sdk:the C# server and the dotnet build/test/run tasks"
  "stow:linking the config"
)

say() { printf '\033[1m%s\033[0m\n' "$*"; }
missing() { ! pacman -Qq "$1" >/dev/null 2>&1; }

check() {
  local entry p bad=0
  say "Packages:"
  for entry in "${PACKAGES[@]}"; do
    p=${entry%%:*}
    if missing "$p"; then printf '  missing  %-20s %s\n' "$p" "${entry#*:}"; bad=1
    else printf '  ok       %s\n' "$p"; fi
  done

  say "Font:"
  if [[ -n "$(fc-list 'FantasqueSansM Nerd Font Mono' family)" ]]; then echo "  ok"
  else echo "  FantasqueSansM Nerd Font Mono not found by fontconfig"; bad=1; fi

  say "Config link:"
  if [[ "$(readlink -f ~/.config/zed)" == "$repo/zed/.config/zed" ]]; then echo "  ~/.config/zed -> repo"
  else echo "  ~/.config/zed is not linked to the repo"; bad=1; fi

  ((bad)) && say "Something is missing (above)." || say "All set. Restart Zed to pick up anything new."
}

install() {
  local entry p need=()
  for entry in "${PACKAGES[@]}"; do
    p=${entry%%:*}
    missing "$p" && need+=("$p")
  done
  if ((${#need[@]})); then
    say "Installing: ${need[*]}"
    sudo pacman -S --needed "${need[@]}" || say "pacman reported a problem (see above); carrying on."
  else
    say "All packages already installed."
  fi
  fc-cache -f >/dev/null 2>&1

  # Link the whole directory (see the top of settings.json for why). A real
  # ~/.config/zed, e.g. the one Zed makes on first launch, is moved aside, not
  # deleted.
  if [[ "$(readlink -f ~/.config/zed)" != "$repo/zed/.config/zed" ]]; then
    if [[ -e ~/.config/zed && ! -L ~/.config/zed ]]; then
      local backup=~/.config/zed.before-stow-$(date +%Y%m%d-%H%M%S)
      mv ~/.config/zed "$backup" && say "Moved the old ~/.config/zed to $backup"
    fi
    # -t ~ matters: stow's default target is the repo's parent, not your home.
    stow -d "$repo" -t ~ zed && say "Linked ~/.config/zed to the repo."
  fi
}

case "${1:-all}" in
  check) check ;;
  all) install; echo; check ;;
  *) echo "usage: $0 [check]" >&2; exit 2 ;;
esac
