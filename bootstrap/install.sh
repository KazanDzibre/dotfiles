#!/usr/bin/env bash
# Bring an Ubuntu 26.04 box up to this repo's desktop: Hyprland + the Quickshell
# bar, pywal-driven colours, rofi, neovim, Ptyxis.
#
# Run it as your normal user. It calls sudo only for apt and `cmake --install`,
# and will prompt for a password when it gets there -- so run it from a real
# terminal, not from a tool that has no tty.
#
#   bootstrap/install.sh            everything, in order
#   bootstrap/install.sh apt        distro packages only
#   bootstrap/install.sh brave      Brave, and make it the default browser
#   bootstrap/install.sh python     pywal16 + waypaper via pipx
#   bootstrap/install.sh fonts      the two Nerd Fonts the configs name
#   bootstrap/install.sh quickshell build and install quickshell from source
#   bootstrap/install.sh stow       symlink the config packages into $HOME
#   bootstrap/install.sh theme      apply the Ptyxis terminal settings
#   bootstrap/install.sh check      report what is present, change nothing
#
# Every phase is idempotent: re-running it is the normal way to fix a partial
# install. Nothing here is destructive -- `stow` refuses rather than clobbering
# an existing real file, and that refusal is reported, not worked around.
#
# Deliberately not `set -e`: a phase that fails should say so and let the rest
# run, because a missing Nerd Font should not stop the compositor from being
# installed.
set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
BUILD_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nuketown-build"
FONT_DIR="$HOME/.local/share/fonts"

# Packages that are stow packages in this repo. `reference` and `bootstrap` are
# not -- the first is frozen prior art, the second is this script.
STOW_PACKAGES=(hypr quickshell nvim rofi wal waypaper ptyxis env screensaver fish starship)

say()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    warning:\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m    failed:\033[0m %s\n' "$*" >&2; FAILURES+=("$*"); }

FAILURES=()

have() { command -v "$1" >/dev/null 2>&1; }

# Phases that install system-wide need sudo, and sudo needs somewhere to ask for
# the password. It cannot do that when this script is run from a tool or editor
# with no controlling terminal -- including Claude Code's `!` prefix, which runs
# in its own session. Failing here, before a 61-package transaction, beats
# failing halfway through it.
require_sudo() {
    sudo -n true 2>/dev/null && return 0    # credentials already cached
    [ -t 0 ] && return 0                    # a real terminal: sudo can prompt

    cat >&2 <<'MSG'
    This phase needs sudo, and there is no terminal for it to ask on.

    Run it from a real terminal window:

        cd ~/Nuketown/dotfiles && bootstrap/install.sh <phase>

    Or cache the credentials there first, then re-run from anywhere within
    the sudo timeout:

        sudo -v
MSG
    return 1
}

# ---------------------------------------------------------------------- apt
#
# Grouped by what each group is for, because in a year the interesting question
# about any line here will be "what breaks if I drop this".
apt_packages() {
    cat <<'PKGS'
stow git curl unzip jq fontconfig xdg-utils

hyprland hyprpaper hypridle hyprlock xdg-desktop-portal-hyprland
xdg-desktop-portal-gtk xwayland

rofi neovim ptyxis fish starship
wl-clipboard cliphist grim slurp brightnessctl playerctl pamixer cava
network-manager-gnome blueman imagemagick
mate-polkit

# cmatrix drives the only enabled screensaver effect
# (screensaver/.config/screensaver/config.toml). The screensaver skips an effect
# whose program is missing without complaining, so without this it shows nothing.
cmatrix

python3-pip python3-venv pipx

build-essential cmake ninja-build pkg-config
qt6-base-dev qt6-base-private-dev
qt6-declarative-dev qt6-declarative-private-dev
qt6-shadertools-dev qt6-svg-dev qt6-wayland
libcli11-dev libdrm-dev libjemalloc-dev spirv-tools
libwayland-dev wayland-protocols libxkbcommon-dev libxcb1-dev
libgbm-dev libegl-dev libgles-dev mesa-common-dev
libdbus-1-dev libpipewire-0.3-dev libpam0g-dev
libpolkit-agent-1-dev libglib2.0-dev libunwind-dev
PKGS
}

phase_apt() {
    say "Installing distro packages"

    require_sudo || { fail "phase_apt: no terminal for sudo"; return 1; }
    local pkgs
    mapfile -t pkgs < <(apt_packages | tr ' ' '\n' | grep -v '^$')
    note "${#pkgs[@]} packages"

    # One transaction, so a single unavailable package is visible immediately
    # rather than after twenty successful installs.
    sudo apt-get update || { fail "apt-get update"; return 1; }
    sudo apt-get install -y "${pkgs[@]}" || { fail "apt-get install"; return 1; }
}

# -------------------------------------------------------------------- brave
#
# Brave is the default browser, and it is not in Ubuntu's archive -- it comes
# from Brave's own apt repo, so that repo has to exist before apt can see the
# package. The signing key goes to /usr/share/keyrings and the sources entry
# is pinned to it with signed-by, rather than into the deprecated apt-key
# trust store where it would be trusted for every repo on the box.
#
# The default is then set with `xdg-settings`, NOT by stowing a mimeapps.list.
# ~/.config/mimeapps.list is a file the desktop itself writes to, and GIO
# replaces it by rename -- which would quietly swap a stow symlink for a real
# file and leave the repo looking deployed when it is not. xdg-settings edits
# it in place and is idempotent, so re-running this phase is harmless.
#
# This covers everything that opens a link through xdg-open (the dashboard's
# news and weather items, notifications, other apps). hyprland.conf exports
# BROWSER separately, for the CLI and TUI tools that read that instead.
phase_brave() {
    say "Installing Brave and making it the default browser"

    require_sudo || { fail "phase_brave: no terminal for sudo"; return 1; }

    have curl || { fail "curl missing -- run the apt phase first"; return 1; }

    if have brave-browser; then
        note "brave-browser already installed"
    else
        local keyring=/usr/share/keyrings/brave-browser-archive-keyring.gpg
        sudo curl -fsSLo "$keyring" \
            https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
            || { fail "download of the Brave signing key"; return 1; }
        echo "deb [signed-by=$keyring arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" \
            | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null

        sudo apt-get update || { fail "apt-get update after adding the Brave repo"; return 1; }
        sudo apt-get install -y brave-browser || { fail "apt-get install brave-browser"; return 1; }
    fi

    # xdg-settings handles http/https and text/html in one call. The xdg-mime
    # lines after it are the handlers it leaves alone -- without them a local
    # .html file or an ftp:// link still opens in whatever was there before.
    if have xdg-settings; then
        xdg-settings set default-web-browser brave-browser.desktop \
            || fail "xdg-settings refused -- is brave-browser.desktop installed?"
    else
        fail "xdg-settings missing (xdg-utils) -- default browser not set"
    fi

    if have xdg-mime; then
        xdg-mime default brave-browser.desktop \
            text/html application/xhtml+xml \
            x-scheme-handler/http x-scheme-handler/https x-scheme-handler/ftp \
            || warn "xdg-mime refused one of the handlers"
    fi

    note "default browser: $(xdg-settings get default-web-browser 2>/dev/null || echo unknown)"
}

# ------------------------------------------------------------------- python
#
# Neither pywal nor waypaper is packaged for Ubuntu, and 26.04 enforces PEP 668
# -- so `pip install --user` is refused system-wide. pipx is the supported route:
# each tool gets its own venv and a shim in ~/.local/bin, which is exactly where
# waypaper/wallpaper_update.sh already looks for `wal`.
#
# pywal16 rather than pywal: the original is unmaintained and does not run on
# current Python. pywal16 is a drop-in fork -- same `wal` command, same
# ~/.cache/wal outputs (colors.json, colors.scss, colors-rofi-dark.rasi) that
# Theme.qml, eww.scss and pywal.rasi all read.
phase_python() {
    say "Installing pywal16 and waypaper"

    have pipx || { fail "pipx missing -- run the apt phase first"; return 1; }

    pipx install pywal16 || warn "pywal16 install reported a problem (already installed?)"

    # --system-site-packages is load-bearing. waypaper depends on PyGObject,
    # and building that in an isolated venv needs cairo and girepository dev
    # headers -- it fails with 'Dependency "cairo" not found' otherwise. Ubuntu
    # already ships a working python3-gi built against the system GTK, so the
    # venv is told to see it rather than compiling its own.
    pipx install --system-site-packages waypaper \
        || warn "waypaper install reported a problem (already installed?)"

    # pipx puts shims in ~/.local/bin; make sure that is on PATH for future
    # shells. pipx writes to the shell rc itself, so this is just the report.
    pipx ensurepath >/dev/null 2>&1

    if [ ! -x "$HOME/.local/bin/wal" ]; then
        fail "$HOME/.local/bin/wal not present -- wallpaper_update.sh hardcodes that path"
    fi
}

# -------------------------------------------------------------------- fonts
#
# Two are needed, and they are named in the configs rather than discovered:
#   FantasqueSansM Nerd Font  -- Theme.qml (the Quickshell bar)
#   JetBrainsMono Nerd Font   -- eww.scss and rofi/pywal.rasi
#
# Ubuntu ships fonts-jetbrains-mono, but NOT the Nerd Font patched build, and
# only the patched build has the glyphs every icon in the bar uses. So they come
# from the nerd-fonts releases.
#
# The release tag is looked up rather than pinned: a pinned tag rots, and a
# wrong one fails as a 404 halfway through.
phase_fonts() {
    say "Installing Nerd Fonts"

    have curl || { fail "curl missing -- run the apt phase first"; return 1; }

    local tag
    tag="$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
           | grep -m1 '"tag_name"' | cut -d'"' -f4)"
    if [ -z "$tag" ]; then
        warn "could not resolve the latest nerd-fonts tag, falling back to v3.4.0"
        tag="v3.4.0"
    fi
    note "nerd-fonts $tag"

    mkdir -p "$FONT_DIR"
    local font tmp
    for font in FantasqueSansMono JetBrainsMono; do
        # fc-list is the real test: the font may have been installed by hand.
        if fc-list 2>/dev/null | grep -qi "${font%Mono} .*Nerd Font\|${font}.*Nerd"; then
            note "$font already present"
            continue
        fi
        tmp="$(mktemp -d)"
        if curl -fsSL -o "$tmp/$font.zip" \
             "https://github.com/ryanoasis/nerd-fonts/releases/download/$tag/$font.zip"; then
            unzip -qo "$tmp/$font.zip" -d "$FONT_DIR/$font" -x 'README*' 'LICENSE*' \
                && note "installed $font"
        else
            fail "download of $font.zip failed"
        fi
        rm -rf "$tmp"
    done

    fc-cache -f >/dev/null 2>&1
    note "font cache rebuilt"
}

# --------------------------------------------------------------- quickshell
#
# Not packaged for Ubuntu, so it is built. Every dependency IS packaged, and
# Ubuntu 26.04 carries Qt 6.10.2 -- comfortably past the 6.6 minimum.
#
# Two things about this build are worth knowing:
#
#   * Quickshell uses private Qt APIs and must be rebuilt after every Qt update,
#     or it crashes on an ABI mismatch. That is why this phase is re-runnable and
#     why `check` reports the Qt version it was built against.
#   * The crash handler pulls cpptrace and libunwind in with CMake FetchContent,
#     which needs network during configure. Neither is packaged for Ubuntu. If
#     that step fails, re-run with CRASH_HANDLER=OFF in the environment.
phase_quickshell() {
    say "Building quickshell from source"

    require_sudo || { fail "phase_quickshell: no terminal for sudo"; return 1; }

    have cmake && have ninja || { fail "cmake/ninja missing -- run the apt phase first"; return 1; }

    mkdir -p "$BUILD_DIR"
    local src="$BUILD_DIR/quickshell"

    if [ -d "$src/.git" ]; then
        note "updating existing checkout"
        git -C "$src" pull --ff-only || warn "pull failed; building whatever is checked out"
    else
        git clone https://github.com/quickshell-mirror/quickshell.git "$src" \
            || { fail "git clone of quickshell"; return 1; }
    fi

    local flags=(
        -DCMAKE_BUILD_TYPE=Release
        -DDISTRIBUTOR="nuketown-dotfiles"

        # cpptrace is not packaged for Ubuntu and this version of quickshell
        # does not vendor it, so configure fails outright on
        # "Could not find a package configuration file provided by cpptrace".
        # The crash handler only produces nicer backtraces; losing it costs
        # nothing at runtime. Set CRASH_HANDLER=ON in the environment and
        # install cpptrace yourself if you want it back.
        -DCRASH_HANDLER="${CRASH_HANDLER:-OFF}"

        # Without this, configure only *warns* -- "QML modules will not be
        # installed" -- and then installs a binary that cannot load its own
        # modules. Point it at the directory Qt already searches, so nothing
        # has to be added to QML_IMPORT_PATH later.
        -DINSTALL_QMLDIR="$(qmake6 -query QT_INSTALL_QML)"
    )

    cmake -GNinja -B "$src/build" -S "$src" "${flags[@]}" \
        || { fail "cmake configure -- read the last error above; a missing pkg-config module means the apt phase needs that -dev package"; return 1; }
    cmake --build "$src/build" || { fail "quickshell build"; return 1; }
    sudo cmake --install "$src/build" || { fail "quickshell install"; return 1; }

    note "installed $(qs --version 2>/dev/null || echo 'quickshell (version unknown)')"
}

# ---------------------------------------------------------------------- stow
#
# Dry run first and report, because the failure worth catching is a real file
# already sitting where a symlink should go -- stow declines, and silently
# skipping that would leave a config that looks deployed but is not.
phase_stow() {
    say "Linking config packages into \$HOME"

    have stow || { fail "stow missing -- run the apt phase first"; return 1; }

    local pkg
    for pkg in "${STOW_PACKAGES[@]}"; do
        if [ ! -d "$REPO/$pkg" ]; then
            warn "no such package: $pkg (skipped)"
            continue
        fi
        if ! stow -n -d "$REPO" -t "$HOME" "$pkg" 2>/dev/null; then
            fail "$pkg conflicts with something already in \$HOME -- resolve by hand:
        stow -n -v -d '$REPO' -t '$HOME' $pkg"
            continue
        fi
        stow -R -d "$REPO" -t "$HOME" "$pkg" && note "linked $pkg"
    done
}

# --------------------------------------------------------------------- theme
#
# Ptyxis stores its settings in dconf, so there is no file for stow to link --
# the ptyxis package ships a script that writes them instead. Runs after stow,
# because the script it calls is the one stow just linked into ~/.local/bin.
#
# It only *selects* the pywal palette; the palette itself is generated on the
# first wallpaper change, so a complaint about a missing palette here is
# expected on a fresh machine and resolves itself once waypaper has run.
phase_theme() {
    say "Applying Ptyxis terminal settings"

    local script="$HOME/.local/bin/ptyxis-theme.sh"
    [ -x "$script" ] || script="$REPO/ptyxis/.local/bin/ptyxis-theme.sh"
    [ -x "$script" ] || { fail "ptyxis-theme.sh not found"; return 1; }

    "$script" || fail "ptyxis-theme.sh reported a problem"
}

# --------------------------------------------------------------------- check
phase_check() {
    say "What is present"

    local c
    for c in hyprland quickshell qs rofi nvim stow wal waypaper brave-browser \
             wl-copy cliphist grim slurp brightnessctl playerctl pamixer ptyxis; do
        printf '    %-14s %s\n' "$c" "$(command -v "$c" || echo '-- missing')"
    done

    printf '\n    Qt:            %s\n' "$(qmake6 -query QT_VERSION 2>/dev/null || echo 'unknown')"
    printf '    Nerd Fonts:    %s\n' "$(fc-list 2>/dev/null | grep -ci 'nerd font') matching faces"
    printf '    pywal cache:   %s\n' "$([ -f "$HOME/.cache/wal/colors.json" ] && echo present || echo 'absent (run wal -i <image> once)')"
    printf '    web browser:   %s\n' "$(xdg-settings get default-web-browser 2>/dev/null || echo 'unknown (xdg-utils missing)')"

    # Hyprland can check its own config without running. Worth doing here: a
    # config error does not stop the session starting, it just silently drops
    # the offending line, so a broken rule looks like "that feature never
    # worked" rather than like an error.
    if have hyprland && [ -f "$HOME/.config/hypr/hyprland.conf" ]; then
        local cfg
        cfg="$(hyprland --verify-config -c "$HOME/.config/hypr/hyprland.conf" 2>&1 | grep -c 'Config error')"
        printf '    hypr config:   %s\n' "$([ "$cfg" -eq 0 ] && echo 'ok' || echo "$cfg error(s) -- run: hyprland --verify-config -c ~/.config/hypr/hyprland.conf")"
    fi

    printf '\n    stow links:\n'
    for c in "${STOW_PACKAGES[@]}"; do
        local target
        # Each package is checked at the one path it actually owns. ptyxis is
        # the odd one: it ships a script, not a config directory, because
        # Ptyxis keeps its settings in dconf. Its palettes directory is
        # deliberately NOT stowed -- the wallpaper hook writes a generated file
        # there, which would dirty the repo if it were a link.
        case "$c" in
            ptyxis) target="$HOME/.local/bin/ptyxis-theme.sh" ;;
            fish)   target="$HOME/.config/fish" ;;
            starship) target="$HOME/.config/starship.toml" ;;
            env)    target="$HOME/.config/environment.d" ;;
            hypr)   target="$HOME/.config/hypr" ;;
            *)      target="$HOME/.config/$c" ;;
        esac
        if [ -L "$target" ]; then
            printf '      %-12s -> %s\n' "$c" "$(readlink "$target")"
        elif [ -e "$target" ]; then
            printf '      %-12s %s\n' "$c" "EXISTS but is not a symlink"
        else
            printf '      %-12s %s\n' "$c" "not linked"
        fi
    done
}

# ---------------------------------------------------------------------- main
main() {
    case "${1:-all}" in
        apt)        phase_apt ;;
        brave)      phase_brave ;;
        python)     phase_python ;;
        fonts)      phase_fonts ;;
        quickshell) phase_quickshell ;;
        stow)       phase_stow ;;
        theme)      phase_theme ;;
        check)      phase_check; return 0 ;;
        all)
            phase_apt
            phase_brave
            phase_python
            phase_fonts
            phase_quickshell
            phase_stow
            phase_theme
            phase_check
            ;;
        *)
            echo "install: unknown phase '$1'" >&2
            sed -n '3,20p' "$0" >&2
            return 2
            ;;
    esac

    if [ "${#FAILURES[@]}" -gt 0 ]; then
        printf '\n\033[1;31m%s phase(s) reported a failure:\033[0m\n' "${#FAILURES[@]}" >&2
        printf '  - %s\n' "${FAILURES[@]}" >&2
        printf '\nRe-running a phase is safe; fix the cause and run it again.\n' >&2
        return 1
    fi

    say "Done. Log out and pick Hyprland at the GDM session chooser."
    note "First run: set a wallpaper with waypaper -- that is what generates the palette everything reads."
}

main "$@"
