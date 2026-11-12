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
    const gif = root.gifTerm(q.toLowerCase());
    if (gif !== null && root.gifConfigured) {
      root.gifPending = gif;
      if (gif !== root.gifsFor)
        gifDelay.restart();
    }
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
  //
  // % reads like a phone calculator: after a number it is a percentage, and
  // after + or - it is a percentage *of what came before* (200 + 15% = 230,
  // 200 - 10% = 180, 200 * 15% = 30). Between two operands it is still modulo
  // (15 % 4 = 3).
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
    // Whether the character after a % begins another operand, which makes that
    // % a modulo rather than a percent sign.
    function startsOperand(c) {
      return c !== undefined && /[0-9.(]/.test(c);
    }
    let pctFlag = false;   // the term just read ended in a percent sign
    let pctLone = false;   // ...and was the whole product, not part of one
    function power() {
      let base = atom();
      pctFlag = false;
      if (src[i] === "%" && !startsOperand(src[i + 1])) {
        i++;
        base = base / 100;
        pctFlag = true;
      }
      if (src[i] === "^") {
        i++;
        return Math.pow(base, power());
      }
      return base;
    }
    function product() {
      let v = power();
      let lone = pctFlag;
      while (src[i] === "*" || src[i] === "/" || src[i] === "%") {
        const op = src[i++];
        const r = power();
        v = op === "*" ? v * r : op === "/" ? v / r : v % r;
        lone = false;
      }
      pctLone = lone;
      return v;
    }
    function sum() {
      let v = product();
      while (src[i] === "+" || src[i] === "-") {
        const op = src[i++];
        const r = product();
        // "200 + 15%" adds 15% of 200, not 0.15.
        const amount = pctLone ? v * r : r;
        v = op === "+" ? v + amount : v - amount;
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

  // --------------------------------------------------------------- commands
  // Typed words that do something rather than find something. Matching a word
  // or one of its aliases exactly puts it first; the start of the word is
  // enough to list it alongside the apps.
  readonly property var commands: [
    {
      word: "pick",
      also: ["color", "colour", "eyedropper", "picker"],
      title: "Pick a colour",
      sub: "Click anywhere on screen · copies its hex",
      glyph: Icons.eyedropper,
      action: "pick"
    },
    {
      word: "help",
      also: ["shortcuts", "commands", "cheatsheet", "keys"],
      title: "Shortcuts and commands",
      sub: "Everything the island and the bar respond to",
      glyph: Icons.keyboard,
      action: "panel"
    },
    {
      word: "notes",
      also: [],
      title: "Open your notes",
      sub: "In Neovim" + (Notes.open > 0 ? " · " + Notes.open + " open" : ""),
      glyph: Icons.note,
      action: "notes"
    },
    {
      word: "noted",
      also: ["todo", "todos"],
      title: "Tick off notes",
      sub: Notes.open === 0 ? "Nothing open" : Notes.open + " open · in the island",
      glyph: Icons.note,
      action: "list"
    }
  ]

  function commandItem(c, points) {
    return {
      kind: "command",
      label: "Run",
      title: c.title,
      sub: c.sub,
      icon: "",
      glyph: c.glyph,
      action: c.action,
      points: points
    };
  }

  // Shown for `help`: the commands, then examples that fill the search in.
  function helpItems() {
    const hint = (title, sub, example) => ({
          kind: "hint",
          label: "Try",
          title: title,
          sub: sub,
          icon: "",
          glyph: Icons.lightbulb,
          example: example,
          points: 0
        });
    return [root.commandItem(root.commands[1], 0), root.commandItem(root.commands[0], 0), hint("note call the bank", "Save a quick note · note at 15:00 … reminds you", "note "), hint("?how do I…", "Ask the AI anything", "?"), hint("200 + 15%", "Sums, copied with Enter", "200 + 15%"), hint("time in tokyo", "Also 5 km to mi, days until…", "time in tokyo"), hint(":fire", "Find an emoji · Enter copies it", ":"), hint("gif cats", "Search GIFs · Enter copies the link", "gif ")];
  }

  // ------------------------------------------------------------------ emoji
  // ":fire" or "emoji fire". The list is scripts/emoji.tsv (character, name,
  // group, keywords), searched here rather than in a helper process so the
  // results follow every keystroke. Enter copies the emoji; the ones used
  // most recently come first when nothing has been typed after the colon.
  property var emojis: []
  property var emojiRecent: []

  FileView {
    id: emojiFile
    path: Quickshell.shellPath("scripts/emoji.tsv")

    onLoaded: {
      const rows = [];
      for (const line of text().split("\n")) {
        const f = line.split("\t");
        if (f.length >= 4)
          rows.push({
            char: f[0],
            name: f[1],
            group: f[2],
            words: f[3].split(" ").filter(w => w.length > 0),
            hay: (f[1] + " " + f[3]).toLowerCase()
          });
      }
      root.emojis = rows;
    }
  }

  FileView {
    id: emojiRecentFile
    path: Quickshell.cachePath("emoji-recent.json")

    onLoaded: {
      try {
        const saved = JSON.parse(text());
        root.emojiRecent = Array.isArray(saved) ? saved.slice(0, 12) : [];
      } catch (e) {
        root.emojiRecent = [];
      }
    }
    onLoadFailed: Qt.callLater(() => emojiRecentFile.setText("[]"))
  }

  // The text after the trigger, or null if this isn't an emoji search.
  function emojiTerm(q) {
    if (q.startsWith(":"))
      return q.substring(1).trim();
    if (q === "emoji" || q.startsWith("emoji "))
      return q.substring(5).trim();
    return null;
  }

  function emojiItem(e, points) {
    return {
      kind: "emoji",
      label: "Copy",
      title: e.name,
      sub: e.group,
      icon: "",
      glyph: "",
      emoji: e.char,
      value: e.char,
      points: points
    };
  }

  function emojiScore(e, tokens, whole) {
    let total = 0;
    for (const t of tokens) {
      if (!e.hay.includes(t))
        return 0;
      if (e.name === whole)
        total += 100;
      else if (e.name.startsWith(t))
        total += 80;
      else if (e.words.some(w => w.toLowerCase() === t))
        total += 60;
      else if (e.words.some(w => w.toLowerCase().startsWith(t)))
        total += 45;
      else
        total += 20;
    }
    return total / tokens.length;
  }

  function emojiResults(term) {
    if (term.length === 0)
      return root.emojiRecent.map(c => root.emojis.find(e => e.char === c)).filter(e => e).slice(0, root.maxResults).map((e, i) => root.emojiItem(e, 100 - i));
    const tokens = term.toLowerCase().split(/\s+/);
    const hits = [];
    for (const e of root.emojis) {
      const s = root.emojiScore(e, tokens, term.toLowerCase());
      if (s > 0)
        hits.push(root.emojiItem(e, s + (root.emojiRecent.includes(e.char) ? 15 : 0)));
    }
    return hits.sort((a, b) => b.points - a.points).slice(0, root.maxResults);
  }

  function rememberEmoji(c) {
    root.emojiRecent = [c].concat(root.emojiRecent.filter(x => x !== c)).slice(0, 12);
    emojiRecentFile.setText(JSON.stringify(root.emojiRecent));
  }

  // --------------------------------------------------------------------- gifs
  // "gif cats" searches GIPHY through scripts/gifs.py (bare "gif" is trending).
  // Needs QS_GIPHY_API_KEY. Enter copies the media link, which chat apps
  // unfurl into the animation. Debounced harder than answers, since each
  // search is a network request.
  property var gifs: []
  property string gifsFor: ""
  property string gifError: ""
  property string gifPending: ""
  property string gifRunning: ""
  readonly property bool gifConfigured: Quickshell.env("QS_GIPHY_API_KEY") !== null && Quickshell.env("QS_GIPHY_API_KEY") !== ""

  // The search text after "gif", or null if this isn't a gif search.
  function gifTerm(q) {
    if (q === "gif" || q === "gifs")
      return "";
    if (q.startsWith("gif "))
      return q.substring(4).trim();
    return null;
  }

  Timer {
    id: gifDelay
    interval: 450
    onTriggered: root.startGif()
  }

  function startGif() {
    if (gifProc.running || !root.gifConfigured || root.gifPending === null)
      return;
    root.gifRunning = root.gifPending;
    gifProc.command = ["python3", Quickshell.shellPath("scripts/gifs.py")].concat(root.gifRunning.length > 0 ? [root.gifRunning] : []);
    gifProc.running = true;
  }

  Process {
    id: gifProc

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const parsed = JSON.parse(text);
          root.gifError = parsed.error ?? "";
          root.gifs = parsed.results ?? [];
        } catch (e) {
          root.gifError = "No answer from GIPHY";
          root.gifs = [];
        }
        root.gifsFor = root.gifRunning;
      }
    }

    onExited: {
      if (root.gifPending !== root.gifRunning)
        root.startGif();
    }
  }

  function gifResults(term) {
    if (!root.gifConfigured)
      return [root.gifNote("Set QS_GIPHY_API_KEY", "Free key at developers.giphy.com")];
    if (root.gifError.length > 0 && root.gifsFor === term)
      return [root.gifNote(root.gifError, "")];
    if (root.gifsFor !== term && root.gifs.length === 0)
      return [root.gifNote("Searching…", term || "Trending")];
    return root.gifs.map((g, i) => ({
          kind: "gif",
          label: "Copy",
          title: g.title,
          sub: "GIPHY",
          icon: "",
          glyph: Icons.copy,
          thumb: g.thumb,
          value: g.url,
          points: 100 - i
        }));
  }

  function gifNote(title, sub) {
    return {
      kind: "hint",
      label: "GIF",
      title: title,
      sub: sub,
      icon: "",
      glyph: Icons.lightbulb,
      example: "gif ",
      points: 0
    };
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

    if (q === "help")
      return root.helpItems();

    const gifTerm = root.gifTerm(q);
    if (gifTerm !== null)
      return root.gifResults(gifTerm);

    const emojiTerm = root.emojiTerm(q);
    if (emojiTerm !== null)
      return root.emojiResults(emojiTerm);

    // "note …" saves whatever follows; nothing else competes with it.
    if (q === "note" || q.startsWith("note ")) {
      const text = rawQuery.trim().substring(4).trim();
      return [{
        kind: "note",
        label: "Save",
        title: text ? "Save note" : "Type the note after “note”",
        sub: text || "note at 15:00 … also reminds you then",
        icon: "",
        glyph: Icons.note,
        text: text,
        points: 0
      }];
    }

    const out = [];

    for (const c of root.commands) {
      if (c.word === q || c.also.includes(q))
        out.push(root.commandItem(c, 1100));
      else if (q.length >= 2 && (c.word.startsWith(q) || c.also.some(a => a.startsWith(q))))
        out.push(root.commandItem(c, 90));
    }

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
        Quickshell.execDetached(["sh", "-c", 'if command -v alacritty >/dev/null; then exec alacritty -e "$@"; elif command -v ptyxis >/dev/null; then exec ptyxis -s -x "$*"; elif command -v kitty >/dev/null; then exec kitty "$@"; else exec foot "$@"; fi', "sh"].concat(Array.from(item.entry.command).filter(a => !/^%[a-zA-Z]$/.test(a))));
      else
        item.entry.execute();
      break;
    case "window":
      item.toplevel.activate();
      break;
    case "gif":
    case "emoji":
      if (item.kind === "emoji")
        root.rememberEmoji(item.value);
      Clipboard.copy(item.value);
      break;
    case "calc":
    case "clip":
      Clipboard.copy(item.value);
      break;
    case "command":
      if (item.action === "pick")
        ScreenTools.pick();
      break;
    }
  }
}
