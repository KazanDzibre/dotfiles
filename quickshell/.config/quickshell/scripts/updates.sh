#!/usr/bin/env bash
# updates.sh — pending package updates, on whichever distro this is.
#
# The shell is shared between the Arch laptop and the Ubuntu one, and Updates.qml
# used to hard-code `checkupdates` + `yay`, which meant a permanently empty
# badge on Ubuntu. Everything distro-specific lives here instead, so the QML
# stays identical on both. The manager is found by probing for its tool rather
# than reading /etc/os-release, which would misjudge Arch derivatives.
#
#   updates.sh manager   prints "pacman", "apt" or "none"
#   updates.sh check     prints "name old -> new" lines, then @@AUR@@, then the
#                        AUR (or nothing, on apt) -- the format Updates.qml parses
#   updates.sh upgrade   runs the upgrade in the foreground, for a terminal
#   updates.sh term      opens a terminal that runs `upgrade`
#
# Not `set -e`: a failing check should print what it has, not nothing.
set -uo pipefail

me=${0##*/}
AUR_HELPER=${QS_AUR_HELPER:-yay}

manager() {
    if command -v checkupdates >/dev/null 2>&1; then echo pacman
    elif command -v apt >/dev/null 2>&1; then echo apt
    else echo none; fi
}

case "${1:-}" in
manager) manager ;;

check)
    case "$(manager)" in
    pacman)
        # A throwaway db path: needs no root and never touches the real sync db.
        CHECKUPDATES_DB=$(mktemp -u) checkupdates 2>/dev/null
        echo '@@AUR@@'
        command -v "$AUR_HELPER" >/dev/null 2>&1 &&
            "$AUR_HELPER" -Qua 2>/dev/null | grep -v '\[ignored\]'
        ;;
    apt)
        # Reads the package lists as they are; no root. Ubuntu's update-notifier
        # refreshes them daily, so this is at most about a day stale.
        # "pkg/suite NEW arch [upgradable from: OLD]" -> "pkg OLD -> NEW"
        apt list --upgradable 2>/dev/null |
            sed -nE 's|^([^/]+)/[^ ]+ ([^ ]+) [^ ]+ \[upgradable from: ([^]]+)\].*|\1 \3 -> \2|p'
        echo '@@AUR@@'
        ;;
    *) echo '@@AUR@@' ;;
    esac
    ;;

upgrade)
    case "$(manager)" in
    pacman) command -v "$AUR_HELPER" >/dev/null 2>&1 && "$AUR_HELPER" -Syu || sudo pacman -Syu ;;
    apt) sudo apt update && sudo apt full-upgrade ;;
    *) echo "$me: no supported package manager found" >&2 ;;
    esac
    printf '\nDone — press enter to close.'
    read -r _
    ;;

term)
    self=$(readlink -f "$0")
    if command -v alacritty >/dev/null 2>&1; then exec alacritty -e "$self" upgrade
    elif command -v ptyxis >/dev/null 2>&1; then exec ptyxis -s -x "$self upgrade"
    elif command -v kitty >/dev/null 2>&1; then exec kitty "$self" upgrade
    elif command -v foot >/dev/null 2>&1; then exec foot "$self" upgrade
    elif command -v gnome-terminal >/dev/null 2>&1; then exec gnome-terminal -- "$self" upgrade
    fi
    echo "$me: no terminal emulator found" >&2
    exit 1
    ;;

*)
    echo "usage: $me manager|check|upgrade|term" >&2
    exit 2
    ;;
esac
