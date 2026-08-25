#!/usr/bin/env python3
"""Streaming chat client for the assistant panel.

Speaks the OpenAI-compatible /chat/completions API, which Groq, OpenRouter,
xAI (Grok), Gemini's compatibility shim, DeepSeek and a local Ollama all
implement — so the provider is configuration, not code.

Endpoint and model arrive as arguments because they are not secrets and the
caller already resolved them. The API key arrives through the environment so it
never appears in argv, and therefore never in `ps` output.

    QS_AI_API_KEY   required, except for a localhost endpoint

Usage: chat.py <url> <model> '<json array of {role, content} messages>'

Output is record-separated so the caller can stream it. Each record is one type
character followed by its payload:

    T<text>   a chunk of the reply
    D         the reply is complete
    E<text>   something went wrong
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

RS = "\036"
TIMEOUT = 90
USER_AGENT = "quickshell-bar/1.0"


def emit(kind, payload=""):
    sys.stdout.write(kind + payload + RS)
    sys.stdout.flush()


def build_request(url, model, key, messages):
    body = json.dumps({
        "model": model,
        "messages": messages,
        "stream": True,
    }).encode()

    headers = {
        "Content-Type": "application/json",
        # Mandatory, not cosmetic. urllib's default "Python-urllib/3.x" is
        # fingerprinted and blocked by Groq's Cloudflare with a 403 whose body
        # is "error code: 1010" — which looks exactly like an auth failure but
        # is not. Any ordinary User-Agent gets through.
        "User-Agent": USER_AGENT,
        # OpenRouter asks for these; harmless everywhere else.
        "HTTP-Referer": "https://github.com/quickshell-mirror/quickshell",
        "X-Title": "Quickshell Bar",
    }
    if key:
        headers["Authorization"] = "Bearer " + key

    return urllib.request.Request(url, data=body, headers=headers)


def stream(request):
    """Emit every content delta in the SSE response."""
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        for raw in response:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue

            data = line[5:].strip()
            if data == "[DONE]":
                return

            try:
                chunk = json.loads(data)
            except ValueError:
                continue

            for choice in chunk.get("choices", []):
                piece = (choice.get("delta") or {}).get("content")
                if piece:
                    emit("T", piece)


def describe(exc):
    """Turn an HTTPError into something worth showing a human."""
    try:
        return "%s — %s" % (exc.code, str(json.load(exc)["error"]["message"])[:200])
    except Exception:
        reason = exc.reason if isinstance(exc.reason, str) else str(exc.code)
        return "%s — %s" % (exc.code, reason)


def main():
    url = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("QS_AI_API_URL", "")
    model = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("QS_AI_MODEL", "")
    key = os.environ.get("QS_AI_API_KEY", "").strip()

    # A local provider (Ollama, llama.cpp, LM Studio) has no key and doesn't
    # want an Authorization header; everything hosted does.
    local = urllib.parse.urlparse(url).hostname in ("localhost", "127.0.0.1", "::1")

    if not key and not local:
        emit("E", "No API key. Set QS_AI_API_KEY in your environment.")
        return

    try:
        messages = json.loads(sys.argv[3]) if len(sys.argv) > 3 else []
    except (ValueError, IndexError):
        emit("E", "Malformed request.")
        return

    try:
        stream(build_request(url, model, key, messages))
    except urllib.error.HTTPError as exc:
        emit("E", describe(exc))
        return
    except Exception as exc:
        emit("E", str(exc)[:200])
        return

    emit("D")


if __name__ == "__main__":
    main()
