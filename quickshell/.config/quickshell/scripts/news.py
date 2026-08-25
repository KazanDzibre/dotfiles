#!/usr/bin/env python3
"""Headline fetcher for the dashboard.

Reads plain RSS/Atom, so any feed works and nothing needs an API key. Feeds are
passed pipe-separated because URLs may contain commas.

Usage: news.py "https://feeds.bbci.co.uk/news/world/rss.xml|https://news.ycombinator.com/rss"
Prints a JSON array of {title, link, source, date}.
"""
import html
import json
import sys
import urllib.request
import xml.etree.ElementTree as ET

ATOM = "{http://www.w3.org/2005/Atom}"
PER_FEED = 12


def text_of(node, *names):
    for name in names:
        found = node.findtext(name)
        if found:
            return html.unescape(found.strip())
    return ""


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=12) as response:
        root = ET.fromstring(response.read())

    channel = root.find("channel")
    if channel is not None:                       # RSS 2.0
        source = text_of(channel, "title") or url
        items = channel.findall("item")
    else:                                          # Atom
        source = text_of(root, ATOM + "title") or url
        items = root.findall(ATOM + "entry")

    out = []
    for item in items[:PER_FEED]:
        link = text_of(item, "link", ATOM + "link")
        if not link:
            anchor = item.find(ATOM + "link")
            if anchor is not None:
                link = anchor.get("href", "")
        out.append({
            "title": text_of(item, "title", ATOM + "title"),
            "link": link,
            "source": source,
            "date": text_of(item, "pubDate", "published", ATOM + "updated"),
        })
    return out


def main():
    feeds = [f.strip() for f in (sys.argv[1] if len(sys.argv) > 1 else "").split("|")]
    out = []
    for feed in feeds:
        if not feed:
            continue
        try:
            out.extend(fetch(feed))
        except Exception as exc:
            # Surface the failure in the list rather than silently showing fewer
            # stories than the user configured.
            out.append({"title": "Feed unavailable", "link": "", "source": feed,
                        "date": "", "error": str(exc)[:80]})
    print(json.dumps(out))


if __name__ == "__main__":
    main()
