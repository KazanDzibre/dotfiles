#!/usr/bin/env bash
# Claude Code -> the island: the hooks that make the bar's Claude bubble work.
#
#   bootstrap/install-claude-hooks.sh          add the hooks to ~/.claude/settings.json
#   bootstrap/install-claude-hooks.sh check    report whether they are there, change nothing
#
# The island learns what Claude Code is doing from quickshell's
# scripts/claude-hook.py, which Claude Code runs on its events (a prompt, each
# tool, a question or permission request, finishing, the session ending).
# Those hooks live in ~/.claude/settings.json, outside this repo, so a new
# machine has none and the bubble just never appears. This merges them in: it
# keeps every other setting and hook, adds each of ours only if it is not
# already there, and is safe to re-run. A running Claude Code only reads its
# hooks at start, so open a new session afterwards.
set -uo pipefail

SETTINGS=$HOME/.claude/settings.json
HOOK='python3 ~/.config/quickshell/scripts/claude-hook.py'
EVENTS=(UserPromptSubmit PreToolUse PostToolUse PermissionRequest Stop StopFailure SessionEnd)

say() { printf '\033[1m%s\033[0m\n' "$*"; }
row() { printf '  %-8s %s\n' "$1" "$2"; }

command -v python3 >/dev/null 2>&1 || { echo "install-claude-hooks: python3 not found" >&2; exit 1; }

# Prints the events that already run the hook, one per line.
present() {
  [[ -f $SETTINGS ]] || return 0
  python3 - "$SETTINGS" "$HOOK" "${EVENTS[@]}" <<'PY'
import json, sys
path, cmd, events = sys.argv[1], sys.argv[2], sys.argv[3:]
# Any command that runs claude-hook.py counts, however it's spelled (~ or
# "$HOME", quoted or not), so hooks added by hand aren't added a second time.
def ours(command):
    return "claude-hook.py" in command
try:
    hooks = json.load(open(path)).get("hooks", {})
except Exception:
    sys.exit(0)
for ev in events:
    for group in hooks.get(ev, []):
        if any(ours(h.get("command", "")) for h in group.get("hooks", [])):
            print(ev)
            break
PY
}

check() {
  say "Claude Code hooks for the island:"
  [[ -e $HOME/.config/quickshell/scripts/claude-hook.py ]] \
    && row ok "script found (stow the quickshell package)" \
    || row missing "~/.config/quickshell/scripts/claude-hook.py (stow quickshell)"
  local have ev
  have=$(present)
  for ev in "${EVENTS[@]}"; do
    if grep -qx "$ev" <<<"$have"; then row ok "$ev"; else row missing "$ev"; fi
  done
}

install() {
  mkdir -p "$(dirname "$SETTINGS")"
  [[ -f $SETTINGS ]] || echo '{}' >"$SETTINGS"
  # A settings file that is not valid JSON is left exactly as it is.
  python3 - "$SETTINGS" "$HOOK" "${EVENTS[@]}" <<'PY' || { echo "install-claude-hooks: $SETTINGS is not valid JSON, left unchanged" >&2; exit 1; }
import json, sys
path, cmd, events = sys.argv[1], sys.argv[2], sys.argv[3:]
# Any command that runs claude-hook.py counts, however it's spelled (~ or
# "$HOME", quoted or not), so hooks added by hand aren't added a second time.
def ours(command):
    return "claude-hook.py" in command
data = json.load(open(path))
hooks = data.setdefault("hooks", {})
for ev in events:
    groups = hooks.setdefault(ev, [])
    if not any(ours(h.get("command", "")) for g in groups for h in g.get("hooks", [])):
        groups.append({"hooks": [{"type": "command", "command": cmd}]})
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
  check
  echo
  echo "Open a new Claude Code session: a running one keeps the hooks it started with."
}

case "${1:-install}" in
  check) check ;;
  install) install ;;
  *) echo "usage: $0 [check]" >&2; exit 2 ;;
esac
