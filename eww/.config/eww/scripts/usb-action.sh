#!/usr/bin/env bash
# Actions for the bar's removable-device popup.
#
#   usb-action.sh mount <partition>    mount a partition (nothing automounts here)
#   usb-action.sh eject <disk>         safe removal: unmount everything, power off
#
# udisksctl talks to udisks2 over D-Bus as the logged-in user, so none of this
# needs root -- unlike `umount`, which would.

set -uo pipefail

action="${1:-}"
target="${2:-}"
[ -n "$target" ] || { echo "usb-action: no device given" >&2; exit 1; }

note()  { notify-send -t 4000 "Removable media" "$1" >/dev/null 2>&1; }
fail()  { notify-send -u critical -t 6000 "Removable media" "$1" >/dev/null 2>&1; }

case "$action" in
    mount)
        if out="$(udisksctl mount -b "$target" 2>&1)"; then
            note "${out}"
        else
            fail "Could not mount $target — ${out}"
            exit 1
        fi
        ;;

    eject)
        # Unmount every mounted partition on this disk before powering it down;
        # power-off on a disk with a mounted filesystem fails, and yanking it
        # then risks the unflushed writes this button exists to prevent.
        mounted="$(lsblk -nro PATH,MOUNTPOINT "$target" 2>/dev/null \
                   | awk 'NF > 1 { print $1 }')"

        while read -r part; do
            [ -n "$part" ] || continue
            if ! out="$(udisksctl unmount -b "$part" 2>&1)"; then
                fail "Could not unmount $part — ${out}"
                exit 1
            fi
        done <<<"$mounted"

        # Not every device supports power-off (card readers, some hubs). The
        # filesystems are already flushed and unmounted by this point, so treat
        # that as success rather than alarming the user.
        if out="$(udisksctl power-off -b "$target" 2>&1)"; then
            note "Safe to remove $target"
        else
            note "$target unmounted — safe to remove"
        fi
        ;;

    *)
        echo "usb-action: unknown action '$action' (want mount|eject)" >&2
        exit 1
        ;;
esac
