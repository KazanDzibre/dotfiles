// AiChat.qml — a native assistant, no browser involved.
//
// Talks the OpenAI-compatible /chat/completions API through scripts/chat.py,
// which every mainstream provider implements — so switching between OpenRouter,
// Groq, Kimi/Moonshot, DeepSeek or a local Ollama is three environment
// variables, not a rewrite.
//
//   QS_AI_API_URL   default OpenRouter's endpoint
//   QS_AI_API_KEY   required — the one thing the browser version didn't need
//   QS_AI_MODEL     default a free OpenRouter model
//   QS_AI_SYSTEM    optional system prompt
//
// The key is read by the script from the environment rather than passed as an
// argument, so it never shows up in `ps`.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  function envOr(name, fallback) {
    const value = Quickshell.env(name);
    return value && value.length > 0 ? value : fallback;
  }

  // Every one of these speaks the same OpenAI-compatible API, so switching is a
  // single environment variable. Model defaults are a starting point, not
  // gospel — providers retire model names, and QS_AI_MODEL overrides them. If
  // one is stale the API says so and the panel shows its error verbatim.
  readonly property var providers: ({
      openrouter: {
        label: "OpenRouter",
        url: "https://openrouter.ai/api/v1/chat/completions",
        model: "nvidia/nemotron-3.5-lightning:free",
        keyed: true
      },
      groq: {
        label: "Groq",
        url: "https://api.groq.com/openai/v1/chat/completions",
        model: "llama-3.3-70b-versatile",
        keyed: true
      },
      xai: {
        label: "xAI Grok",
        url: "https://api.x.ai/v1/chat/completions",
        model: "grok-3",
        keyed: true
      },
      gemini: {
        label: "Gemini",
        url: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
        model: "gemini-2.0-flash",
        keyed: true
      },
      ollama: {
        label: "Ollama",
        url: "http://localhost:11434/v1/chat/completions",
        model: "llama3.2",
        keyed: false
      }
    })

  // Groq by default: free tier, and the fastest of the hosted options. An
  // unrecognised QS_AI_PROVIDER falls back here rather than failing.
  readonly property string providerId: {
    const name = String(envOr("QS_AI_PROVIDER", "groq")).toLowerCase();
    return root.providers[name] !== undefined ? name : "groq";
  }
  readonly property var provider: root.providers[root.providerId]

  // Explicit URL/model still win, so an unlisted provider needs no code change.
  readonly property string apiUrl: envOr("QS_AI_API_URL", root.provider.url)
  readonly property string model: envOr("QS_AI_MODEL", root.provider.model)
  readonly property string systemPrompt: envOr("QS_AI_SYSTEM", "You are a concise assistant embedded in a Linux status bar on Arch with Hyprland. Prefer short, direct answers and real commands over prose.")

  readonly property bool needsKey: root.provider.keyed && !root.apiUrl.startsWith("http://localhost") && !root.apiUrl.startsWith("http://127.0.0.1")

  readonly property bool configured: {
    if (!root.needsKey)
      return true;
    const key = Quickshell.env("QS_AI_API_KEY");
    return key !== null && key !== undefined && String(key).length > 0;
  }

  // Short model label for the header.
  readonly property string modelLabel: {
    const parts = root.model.split("/");
    return parts[parts.length - 1].replace(":free", "");
  }

  property bool open: false
  property var messages: []       // {role, content}
  property string partial: ""     // the reply currently streaming in
  property bool streaming: false
  property string error: ""

  function toggle() {
    root.open = !root.open;
  }

  function close() {
    root.open = false;
  }

  function reset() {
    root.messages = [];
    root.partial = "";
    root.error = "";
  }

  function send(text) {
    const trimmed = (text ?? "").trim();
    if (trimmed.length === 0 || root.streaming)
      return;

    root.error = "";

    const next = root.messages.slice();
    next.push({
      role: "user",
      content: trimmed
    });
    root.messages = next;

    root.partial = "";
    root.streaming = true;

    // Bounded transcript: a bar widget has no business shipping an unbounded
    // history on every request.
    const payload = [
      {
        role: "system",
        content: root.systemPrompt
      }
    ].concat(root.messages.slice(-20));

    // URL and model as arguments, key left in the environment.
    chat.command = ["python3", Quickshell.shellPath("scripts/chat.py"), root.apiUrl, root.model, JSON.stringify(payload)];
    chat.running = true;
  }

  function stop() {
    if (chat.running)
      chat.signal(15);      // SIGTERM
    root.finish();
  }

  Process {
    id: chat

    stdout: SplitParser {
      splitMarker: "\u001E"
      onRead: record => root.ingest(record)
    }

    // If the process dies without sending its completion record, still commit
    // whatever arrived rather than leaving the UI spinning.
    onExited: {
      if (root.streaming)
        root.finish();
    }
  }

  function ingest(record) {
    if (!record || record.length === 0)
      return;

    const kind = record.charAt(0);
    const payload = record.substring(1);

    if (kind === "T")
      root.partial += payload;
    else if (kind === "D")
      root.finish();
    else if (kind === "E") {
      root.error = payload;
      root.partial = "";
      root.streaming = false;
    }
  }

  function finish() {
    if (root.partial.length > 0) {
      const next = root.messages.slice();
      next.push({
        role: "assistant",
        content: root.partial
      });
      root.messages = next;
    }
    root.partial = "";
    root.streaming = false;
  }
}
