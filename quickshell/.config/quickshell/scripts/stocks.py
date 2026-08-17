#!/usr/bin/env python3
"""Quote fetcher for the dashboard.

Yahoo Finance's v8 chart endpoint needs no API key and no session crumb, unlike
the v7 quote endpoint, which is why it is used here. One request per symbol.

Usage: stocks.py AAPL,MSFT,BTC-USD
Prints a JSON array; every symbol always yields an entry, carrying an "error"
key if its request failed, so the UI can show which one broke.
"""
import json
import sys
import urllib.parse
import urllib.request

URL = ("https://query1.finance.yahoo.com/v8/finance/chart/"
       "{sym}?interval=15m&range=1d")


def fetch(symbol):
    request = urllib.request.Request(
        URL.format(sym=urllib.parse.quote(symbol)),
        headers={"User-Agent": "Mozilla/5.0"},
    )
    with urllib.request.urlopen(request, timeout=12) as response:
        payload = json.load(response)

    result = payload["chart"]["result"][0]
    meta = result["meta"]

    closes = []
    try:
        quote = result["indicators"]["quote"][0]
        closes = [c for c in (quote.get("close") or []) if c is not None]
    except (KeyError, IndexError, TypeError):
        pass

    price = meta.get("regularMarketPrice")
    previous = meta.get("chartPreviousClose") or meta.get("previousClose")

    return {
        "symbol": meta.get("symbol", symbol),
        "name": meta.get("shortName") or meta.get("longName") or meta.get("symbol", symbol),
        "price": price,
        "previous": previous,
        "currency": meta.get("currency", ""),
        # Trimmed: the sparkline is ~90px wide, more points than that is waste.
        "spark": closes[-48:],
    }


def main():
    symbols = [s.strip() for s in (sys.argv[1] if len(sys.argv) > 1 else "").split(",")]
    out = []
    for symbol in symbols:
        if not symbol:
            continue
        try:
            out.append(fetch(symbol))
        except Exception as exc:  # network, parse, missing fields — all reported the same
            out.append({"symbol": symbol, "name": symbol, "error": str(exc)[:80]})
    print(json.dumps(out))


if __name__ == "__main__":
    main()
