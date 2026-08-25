#!/usr/bin/env bash
# Removable storage as JSON, for the bar's eject button.
#
#   [{"path":"/dev/sda1","disk":"/dev/sda","label":"KINGSTON","size":"29.8G",
#     "mount":"/media/marko-ruzic/KINGSTON","mounted":true,"fs":"vfat"}]
#
# A device counts as removable if the kernel says rm/hotplug, or it arrived over
# USB -- USB SSDs often report rm=false but hotplug=true. Loop devices are
# excluded explicitly: this laptop has ~46 of them from snaps.
#
# Partitions with a filesystem are listed individually; a disk with no such
# partition (unpartitioned stick, blank card) is listed as itself so it can
# still be powered off.

set -uo pipefail

lsblk -J -b -o NAME,PATH,LABEL,SIZE,MOUNTPOINT,RM,HOTPLUG,TYPE,TRAN,FSTYPE,VENDOR,MODEL 2>/dev/null \
  | jq -c '
      def human:
        if . == null then "-"
        elif . >= 1099511627776 then ((. / 109951162777.6 | round / 10 | tostring) + "T")
        elif . >= 1073741824 then ((. / 107374182.4 | round / 10 | tostring) + "G")
        elif . >= 1048576    then ((. / 1048576 | round | tostring) + "M")
        else ((. / 1024 | round | tostring) + "K")
        end;

      def clean: (. // "") | gsub("^\\s+|\\s+$"; "");

      [ .blockdevices[]
        | select(.type == "disk")
        | select((.name // "") | startswith("loop") | not)
        | select((.rm == true) or (.hotplug == true) or (.tran == "usb"))
        | . as $disk
        | ( ($disk.vendor | clean) + " " + ($disk.model | clean) | clean ) as $hw
        | ( ($disk.children // []) | map(select((.fstype // "") != "")) ) as $parts
        | if ($parts | length) > 0
          then
            $parts[]
            | { path:    .path,
                disk:    $disk.path,
                label:   (if (.label | clean) != "" then (.label | clean)
                          elif $hw != "" then $hw
                          else .path end),
                size:    (.size | human),
                mount:   (.mountpoint // ""),
                mounted: ((.mountpoint // "") != ""),
                fs:      (.fstype // "") }
          else
            { path:    $disk.path,
              disk:    $disk.path,
              label:   (if $hw != "" then $hw else $disk.path end),
              size:    ($disk.size | human),
              mount:   ($disk.mountpoint // ""),
              mounted: (($disk.mountpoint // "") != ""),
              fs:      ($disk.fstype // "") }
          end
      ]'
