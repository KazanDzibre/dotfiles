pragma Singleton

// Spotlight.qml — what the island's search finds, and how to open it.
//
// Replaces wofi on SUPER+SHIFT+D. Finds installed apps, open windows, clipboard
// history and simple sums; DynamicIsland.qml draws the box and the results.
//
// Apps you launch often rise to the top, and an empty search lists your most
// used ones. Those counts persist in Quickshell's cache.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

Singleton {
  id: root

  readonly property int maxResults: 6

  // Each screen's island opens its own search; this names the focused one.
  signal toggleRequested(string screenName)

  function toggle() {
    root.toggleRequested(Hyprland.focusedMonitor?.name ?? "");
  }

  IpcHandler {
    target: "spotlight"

    function toggle(): void {
      root.toggle();
    }
  }

  GlobalShortcut {
    appid: "quickshell"
    name: "spotlight"
    description: "Search apps, windows and clipboard in the island"
    onPressed: root.toggle()
  }

  // ------------------------------------------------------------------ usage
  property var usage: ({})

  FileView {
    id: usageFile
    path: Quickshell.cachePath("spotlight-usage.json")

    onLoaded: {
      try {
        root.usage = JSON.parse(text());
      } catch (e) {
        root.usage = {};
      }
    }
    // First run: create it, so this doesn't warn on every start. Deferred
    // because writing from inside the failed read's handler gets dropped.
    onLoadFailed: Qt.callLater(() => usageFile.setText("{}"))
  }

  function usageKey(entry) {
    return entry.id || entry.name;
  }

  function bump(entry) {
    const next = Object.assign({}, root.usage);
    const key = root.usageKey(entry);
    next[key] = (next[key] ?? 0) + 1;
    root.usage = next;
    usageFile.setText(JSON.stringify(next));
  }

  // ---------------------------------------------------------------- scoring
  // Best first: exact, start of the text, start of a word, anywhere, and last
  // (only if `loose`) the letters in order, close together: "ffx" finds
  // "firefox". 0 means no match.
  function score(text, q, loose) {
    if (!text)
      return 0;
    const t = String(text).toLowerCase();
    if (t === q)
      return 100;
    if (t.startsWith(q))
      return 80;
    if (t.split(/[\s\-_.\/]+/).some(w => w.startsWith(q)))
      return 65;
    if (t.includes(q))
      return 45;
    if (!loose || q.length < 2)
      return 0;
    let at = 0;
    let first = -1;
    for (const c of q) {
      at = t.indexOf(c, at);
      if (at < 0)
        return 0;
      if (first < 0)
        first = at;
      at++;
    }
    return at - first <= q.length * 2 + 1 ? 20 : 0;
  }

  // ------------------------------------------------------------------- sums
  // ---------------------------------------------------------------- answers
  // Time zones, unit conversions, dates and "x% of y", from scripts/answer.py.
  // Asynchronous, so the search shows its usual results straight away and the
  // answer joins them a few milliseconds later: search() reads `answer`, which
  // makes the island's results binding re-run when it lands.
  property var answer: null
  property string answerFor: ""
  property string pendingQuery: ""
  property string runningQuery: ""

  // Only worth spawning a process for text that could be a question.
  function answerable(q) {
    return /\d/.test(q) || /\btime\b/.test(q);
  }

  function ask(query) {
    const q = query.trim();
    root.pendingQuery = q;
    if (!root.answerable(q.toLowerCase())) {
      root.answer = null;
      root.answerFor = "";
      return;
    }
    askDelay.restart();
  }

  // Debounced, so typing does not start a process per keystroke.
  Timer {
    id: askDelay
    interval: 120
    onTriggered: root.startAnswer()
  }

  function startAnswer() {
    if (answerProc.running || root.pendingQuery.length === 0)
      return;
    root.runningQuery = root.pendingQuery;
    answerProc.command = ["python3", Quickshell.shellPath("scripts/answer.py"), root.runningQuery];
    answerProc.running = true;
  }

  Process {
    id: answerProc

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const parsed = JSON.parse(text);
          root.answer = parsed.title ? parsed : null;
        } catch (e) {
          root.answer = null;
        }
        root.answerFor = root.runningQuery.toLowerCase();
      }
    }

    // Typing carried on while this ran: answer the latest text too.
    onExited: {
      if (root.pendingQuery !== root.runningQuery)
        root.startAnswer();
    }
  }

  // A small parser rather than eval(): this text comes straight from the
  // keyboard, and only arithmetic should ever run. Returns null if it isn't
  // a sum.
  function calculate(input) {
    const src = input.replace(/\s+/g, "");
    if (!/^[0-9.+\-*\/%^()]+$/.test(src) || !/[+\-*\/%^]/.test(src) || !/[0-9]/.test(src))
      return null;

    let i = 0;
    function number() {
      const start = i;
      while (i < src.length && /[0-9.]/.test(src[i]))
        i++;
      if (start === i)
        throw new Error("number expected");
      const v = Number(src.slice(start, i));
      if (isNaN(v))
        throw new Error("bad number");
      return v;
    }
    function atom() {
      if (src[i] === "-") {
        i++;
        return -atom();
      }
      if (src[i] === "(") {
        i++;
        const v = sum();
        if (src[i] !== ")")
          throw new Error(") expected");
        i++;
        return v;
      }
      return number();
    }
    function power() {
      const base = atom();
      if (src[i] === "^") {
        i++;
        return Math.pow(base, power());
      }
      return base;
    }
    function product() {
      let v = power();
      while (src[i] === "*" || src[i] === "/" || src[i] === "%") {
        const op = src[i++];
        const r = power();
        v = op === "*" ? v * r : op === "/" ? v / r : v % r;
      }
      return v;
    }
    function sum() {
      let v = product();
      while (src[i] === "+" || src[i] === "-") {
        const op = src[i++];
        const r = product();
        v = op === "+" ? v + r : v - r;
      }
      return v;
    }

    try {
      const v = sum();
      if (i !== src.length || !isFinite(v))
        return null;
      return Number(v.toPrecision(12));
    } catch (e) {
      return null;
    }
  }

  // ----------------------------------------------------------------- search
  function appItem(entry, points) {
    return {
      kind: "app",
      label: "App",
      title: entry.name,
      sub: entry.comment || entry.genericName || "",
      icon: Icons.themeIcon(entry.icon),
      glyph: Icons.appGeneric,
      entry: entry,
      points: points
    };
  }

  function search(rawQuery) {
    const apps = Array.from(DesktopEntries.applications.values).filter(e => !e.noDisplay);
    const q = rawQuery.trim().toLowerCase();

    if (q.startsWith("?")) {
      const question = rawQuery.trim().substring(1).trim();
      return [{
        kind: "ask",
        label: "Ask AI",
        title: question || "Type your question",
        sub: AiChat.configured ? AiChat.modelLabel : "Needs QS_AI_API_KEY",
        icon: "",
        glyph: Icons.sparkle,
        question: question,
        points: 0
      }];
    }

    if (q.length === 0) {
      return apps.sort((a, b) => (root.usage[root.usageKey(b)] ?? 0) - (root.usage[root.usageKey(a)] ?? 0) || a.name.localeCompare(b.name)).slice(0, root.maxResults).map(e => root.appItem(e, 0));
    }

    const out = [];

    const answer = root.calculate(q);
    if (answer !== null) {
      out.push({
        kind: "calc",
        label: "Copy",
        title: "= " + answer,
        sub: rawQuery.trim(),
        icon: "",
        glyph: Icons.copy,
        value: String(answer),
        points: 1000
      });
    }

    if (root.answer && root.answerFor === q) {
      out.push({
        kind: "calc",
        label: "Copy",
        title: root.answer.title,
        sub: root.answer.sub,
        icon: "",
        glyph: Icons.copy,
        value: root.answer.value,
        points: 1000
      });
    }

    for (const e of apps) {
      const s = Math.max(root.score(e.name, q, true), root.score(e.genericName, q) * 0.7, root.score((e.keywords ?? []).join(" "), q) * 0.6);
      if (s > 0)
        out.push(root.appItem(e, s + Math.min((root.usage[root.usageKey(e)] ?? 0) * 3, 20)));
    }

    const windows = [];
    for (const t of Array.from(ToplevelManager.toplevels.values)) {
      const s = Math.max(root.score(t.title, q), root.score(t.appId, q));
      if (s > 0) {
        windows.push({
          kind: "window",
          label: "Window",
          title: t.title,
          sub: t.appId ?? "",
          icon: Icons.themeIconFor(t.appId ?? ""),
          glyph: Icons.windows,
          toplevel: t,
          points: s * 0.9 + 5
        });
      }
    }
    out.push(...windows.sort((a, b) => b.points - a.points).slice(0, 3));

    // Short queries would match most of the history, so wait for three letters.
    if (q.length >= 3) {
      const clips = Clipboard.entries.filter(c => c.toLowerCase().includes(q)).slice(0, 2);
      for (const c of clips) {
        out.push({
          kind: "clip",
          label: "Clipboard",
          title: Clipboard.preview(c),
          sub: "Copy again",
          icon: "",
          glyph: Icons.clipboard,
          value: c,
          points: 15
        });
      }
    }

    return out.sort((a, b) => b.points - a.points).slice(0, root.maxResults);
  }

  function run(item) {
    switch (item.kind) {
    case "app":
      root.bump(item.entry);
      // execute() ignores Terminal=true, so those need a terminal around them.
      if (item.entry.runInTerminal)
        Quickshell.execDetached(["alacritty", "-e"].concat(Array.from(item.entry.command).filter(a => !/^%[a-zA-Z]$/.test(a))));
      else
        item.entry.execute();
      break;
    case "window":
      item.toplevel.activate();
      break;
    case "calc":
    case "clip":
      Clipboard.copy(item.value);
      break;
    }
  }
}
