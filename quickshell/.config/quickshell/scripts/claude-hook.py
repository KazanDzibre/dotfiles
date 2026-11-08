#!/usr/bin/env python3
"""Tell the bar's island what Claude Code is doing.

Wired up as a Claude Code hook in ~/.claude/settings.json. Reads the hook's JSON
on stdin and calls `qs ipc call claude event ...`. It must never get in Claude's
way, so every failure is swallowed.
"""
import json
import os
import subprocess
import sys
import time


def short(text, limit=44):
    text = " ".join(str(text or "").split()).lstrip("-")
    return text if len(text) <= limit else text[: limit - 1] + "…"


def describe(tool, args):
    name = os.path.basename(str(args.get("file_path") or args.get("notebook_path") or ""))
    if tool == "Read":
        return f"Reading {name}"
    if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        return f"Editing {name}"
    if tool == "Bash":
        return short(args.get("description") or "Running a command")
    if tool in ("Grep", "Glob"):
        return "Searching the code"
    if tool in ("WebSearch", "WebFetch"):
        return "Searching the web"
    if tool in ("Agent", "Task"):
        return short(args.get("description") or "Running an agent")
    return short(tool)


def terminal_window():
    """The Hyprland window this Claude runs in, found by walking up the parents."""
    try:
        clients = json.loads(subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=2).stdout)
        by_pid = {c["pid"]: c["address"] for c in clients}
        pid = os.getppid()
        while pid > 1:
            if pid in by_pid:
                return by_pid[pid]
            with open(f"/proc/{pid}/stat") as f:
                pid = int(f.read().rsplit(")", 1)[1].split()[1])
    except Exception:
        pass
    return "_"


def main():
    data = json.load(sys.stdin)
    event = data.get("hook_event_name", "")
    tool = data.get("tool_name", "")
    args = data.get("tool_input") or {}
    window = "_"
    if event == "UserPromptSubmit":
        kind, detail, window = "start", "Thinking", terminal_window()
    elif event == "PreToolUse":
        if tool == "AskUserQuestion":
            kind, detail, window = "waiting", "Has a question for you", terminal_window()
        else:
            kind, detail = "working", describe(tool, args)
    elif event == "PostToolUse":
        kind, detail = "working", "Thinking"
    elif event == "PermissionRequest":
        kind, detail, window = "waiting", "Wants to " + describe(tool, args).lower(), terminal_window()
    elif event == "Stop":
        kind, detail, window = "done", "_", terminal_window()
    elif event == "StopFailure":
        kind, detail, window = "failed", "_", terminal_window()
    elif event == "SessionEnd":
        kind, detail = "end", "_"
    else:
        return
    project = os.path.basename(str(data.get("cwd") or "").rstrip("/")) or "_"
    subprocess.run(
        ["qs", "ipc", "call", "claude", "event", data.get("session_id", "_"), kind, detail or "_", project, window, str(int(time.time() * 1000) % 2000000000)],
        capture_output=True, timeout=3,
    )


try:
    main()
except Exception:
    pass
