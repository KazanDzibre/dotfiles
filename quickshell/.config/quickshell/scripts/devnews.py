#!/usr/bin/env python3
"""Tech headlines, filtered to the stack you actually work in.

Reuses the RSS/Atom parser in news.py rather than reimplementing it — this file
only adds the things a developer feed needs that a general one doesn't:

  * topic tagging, so a headline can be labelled dotnet / flutter / node / js / ai
  * keyword filtering for general feeds (Hacker News, Lobsters), which carry
    everything and would otherwise drown the list
  * a real date sort, because several of these feeds serve their whole archive
    (nodejs.org returns ~1000 items) and feed order can't be trusted
  * concurrency, because sixteen feeds fetched one after another is a slow panel

Feeds are "topic:url", pipe-separated. A topic of "general" means the feed is
not about one subject, so its items are only kept when the title matches a
tracked keyword.

Usage: devnews.py "dotnet:https://…|general:https://news.ycombinator.com/rss"
Prints a JSON array of {title, link, source, date, topics}.
"""
import concurrent.futures
import json
import re
import sys
from email.utils import parsedate_to_datetime
from datetime import datetime, timezone

from news import fetch          # same directory; keeps RSS parsing in one place

LIMIT = 60
PER_FEED = 10

# Without this, whichever source posts most often owns the whole list. Community
# feeds publish dozens of times a day while the .NET Blog or V8 publish weekly,
# so a pure date sort buries exactly the sources worth reading.
PER_SOURCE = 4

# Floor per topic, so a quiet week for Flutter still leaves its filter usable.
MIN_PER_TOPIC = 8

TOPICS = {
    "dotnet": [".net", "dotnet", "c#", "csharp", "asp.net", "blazor", "maui",
               "entity framework", "nuget", "roslyn"],
    "flutter": ["flutter", "dart", "pub.dev"],
    "node": ["node.js", "nodejs", "express", "npm", "deno", "bun", "pnpm"],
    "js": ["javascript", "typescript", "ecmascript", "react", "vue", "angular",
           "svelte", "v8", "webassembly", "wasm", "vite", "next.js"],
    "ai": ["ai", "llm", "gpt", "claude", "gemini", "openai", "anthropic",
           "machine learning", "neural", "transformer", "copilot", "agentic"],
}


def _pattern(keyword):
    """Word-boundary match, except where the keyword itself contains
    punctuation — \b behaves badly around '.net' and 'c#'."""
    escaped = re.escape(keyword)
    if keyword.isalnum():
        return re.compile(r"\b" + escaped + r"\b", re.I)
    return re.compile(escaped, re.I)


MATCHERS = {topic: [_pattern(k) for k in words] for topic, words in TOPICS.items()}


def tag(title):
    return [topic for topic, pats in MATCHERS.items()
            if any(p.search(title) for p in pats)]


def parse_date(raw):
    """RSS is RFC 822, Atom is ISO 8601. Anything unparseable sorts last."""
    if not raw:
        return datetime.min.replace(tzinfo=timezone.utc)
    try:
        parsed = parsedate_to_datetime(raw)
    except (TypeError, ValueError):
        try:
            parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        except ValueError:
            return datetime.min.replace(tzinfo=timezone.utc)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def collect(spec):
    topic, _, url = spec.partition(":")
    if not url:
        return []
    try:
        items = fetch(url)
    except Exception:
        # One dead feed shouldn't blank the panel; the others still render.
        return []

    out = []
    for item in items[:PER_FEED]:
        title = item.get("title", "")
        if not title:
            continue
        topics = tag(title)
        if topic == "general":
            if not topics:
                continue                      # off-topic for this list
        elif topic not in topics:
            topics.append(topic)              # trust the feed's own subject
        item["topics"] = topics
        out.append(item)
    return out


def balance(items):
    """Pick a readable spread: every topic gets a floor, no source dominates.

    AI publishes many times a day and Flutter perhaps weekly, so filling purely
    by date starves the quieter topics — and the topic filter in the UI would
    then show almost nothing.
    """
    per_source = {}
    chosen = []
    picked = set()

    def take(item):
        source = item.get("source", "")
        if per_source.get(source, 0) >= PER_SOURCE:
            return False
        per_source[source] = per_source.get(source, 0) + 1
        chosen.append(item)
        picked.add(id(item))
        return True

    def fill(predicate, quota):
        count = 0
        for item in items:
            if count >= quota or len(chosen) >= LIMIT:
                return
            if id(item) not in picked and predicate(item) and take(item):
                count += 1

    for topic in TOPICS:
        fill(lambda i, t=topic: t in i["topics"], MIN_PER_TOPIC)
    fill(lambda i: True, LIMIT)

    return chosen


def main():
    specs = [s.strip() for s in (sys.argv[1] if len(sys.argv) > 1 else "").split("|") if s.strip()]

    gathered = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for chunk in pool.map(collect, specs):
            gathered.extend(chunk)

    # Same story often appears on several feeds; keep the first of each title.
    seen = set()
    unique = []
    for item in gathered:
        key = re.sub(r"\W+", "", item["title"]).lower()[:80]
        if key in seen:
            continue
        seen.add(key)
        unique.append(item)

    unique.sort(key=lambda i: parse_date(i.get("date")), reverse=True)

    chosen = balance(unique)
    chosen.sort(key=lambda i: parse_date(i.get("date")), reverse=True)
    print(json.dumps(chosen))


if __name__ == "__main__":
    main()
