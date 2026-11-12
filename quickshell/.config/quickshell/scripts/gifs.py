#!/usr/bin/env python3
"""GIF search for the island, from the GIPHY API.

Usage: gifs.py "cats typing"      search
       gifs.py                    trending

Reads the key from QS_GIPHY_API_KEY (a free key from developers.giphy.com;
set it the same way as QS_AI_API_KEY). Prints one JSON object:
  {"results": [{"title", "thumb", "url"}, ...]}  or  {"error": "..."}
`url` is the plain media link, which chat apps unfurl into the animation.
"""
import json
import os
import sys
import urllib.parse
import urllib.request

LIMIT = 6


def main():
    key = os.environ.get("QS_GIPHY_API_KEY", "").strip()
    if not key:
        print(json.dumps({"error": "Set QS_GIPHY_API_KEY"}))
        return
    query = " ".join(sys.argv[1:]).strip()
    params = {"api_key": key, "limit": LIMIT, "rating": "pg-13", "bundle": "messaging_non_clips"}
    if query:
        params["q"] = query
        endpoint = "search"
    else:
        endpoint = "trending"
    url = f"https://api.giphy.com/v1/gifs/{endpoint}?" + urllib.parse.urlencode(params)
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "quickshell"}), timeout=8) as r:
            data = json.load(r)
    except Exception as exc:
        print(json.dumps({"error": f"GIPHY unreachable ({type(exc).__name__})"}))
        return
    out = []
    for g in data.get("data", []):
        img = g.get("images", {})
        full = (img.get("original") or {}).get("url", "")
        thumb = (img.get("fixed_width_small_still") or img.get("fixed_width_small") or img.get("fixed_width") or {}).get("url", "")
        if full:
            out.append({"title": g.get("title") or "GIF", "thumb": thumb, "url": full.split("?")[0]})
    print(json.dumps({"results": out}, ensure_ascii=False))


if __name__ == "__main__":
    main()
