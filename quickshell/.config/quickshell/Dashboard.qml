// Dashboard.qml — data and state for the left-hand drawer.
//
// Both feeds are free and keyless: Yahoo Finance's v8 chart endpoint for
// quotes, and plain RSS for headlines. The fetching lives in scripts/ rather
// than inline shell, because parsing XML and JSON in a one-liner is how you end
// up with a widget that breaks on the first apostrophe in a headline.
//
// Nothing is fetched unless the drawer is open — this is a panel you glance at,
// not a background service.
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

  readonly property string symbols: envOr("QS_STOCKS", "AAPL,MSFT,NVDA,GOOGL,BTC-USD")
  readonly property string feeds: envOr("QS_NEWS_FEEDS", "https://feeds.bbci.co.uk/news/world/rss.xml|https://news.ycombinator.com/rss")

  property bool open: false
  property string tab: "stocks"          // "stocks" | "news"

  property var stocks: []
  property var news: []
  property bool loadingStocks: false
  property bool loadingNews: false
  property string stocksError: ""
  property string newsError: ""

  function toggle() {
    root.open = !root.open;
  }

  function close() {
    root.open = false;
  }

  function show(which) {
    root.tab = which;
    root.open = true;
  }

  onOpenChanged: {
    if (!open)
      return;
    // Refresh on open if we have nothing, so the panel is never blank.
    if (root.stocks.length === 0)
      root.refreshStocks();
    if (root.news.length === 0)
      root.refreshNews();
  }

  // ------------------------------------------------------------------ quotes
  Process {
    id: stocksProc
    command: ["python3", Quickshell.shellPath("scripts/stocks.py"), root.symbols]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.stocks = JSON.parse(text);
          root.stocksError = "";
        } catch (e) {
          root.stocksError = "Couldn't read quotes.";
        }
      }
    }

    onExited: root.loadingStocks = false
  }

  function refreshStocks() {
    if (stocksProc.running)
      return;
    root.loadingStocks = true;
    stocksProc.running = true;
  }

  // --------------------------------------------------------------- headlines
  Process {
    id: newsProc
    command: ["python3", Quickshell.shellPath("scripts/news.py"), root.feeds]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.news = JSON.parse(text);
          root.newsError = "";
        } catch (e) {
          root.newsError = "Couldn't read headlines.";
        }
      }
    }

    onExited: root.loadingNews = false
  }

  function refreshNews() {
    if (newsProc.running)
      return;
    root.loadingNews = true;
    newsProc.running = true;
  }

  function refresh() {
    root.refreshStocks();
    root.refreshNews();
  }

  // Markets move faster than headlines, and both only tick while you're looking.
  Timer {
    running: root.open
    interval: 5 * 60 * 1000
    repeat: true
    onTriggered: root.refreshStocks()
  }

  Timer {
    running: root.open
    interval: 15 * 60 * 1000
    repeat: true
    onTriggered: root.refreshNews()
  }

  Process {
    id: opener
  }

  function openLink(url) {
    if (!url || url.length === 0)
      return;
    opener.command = ["xdg-open", url];
    opener.startDetached();
  }

  // ------------------------------------------------------------------ helpers
  function changePercent(quote) {
    if (!quote || quote.price === undefined || !quote.previous)
      return 0;
    return (quote.price - quote.previous) / quote.previous * 100;
  }

  function formatPrice(value) {
    if (value === undefined || value === null)
      return "—";
    if (value >= 1000)
      return value.toLocaleString(Qt.locale(), "f", 0);
    if (value >= 10)
      return value.toFixed(2);
    return value.toFixed(4);
  }

  // RSS dates are RFC 822; show something short and human instead.
  function relativeDate(raw) {
    if (!raw || raw.length === 0)
      return "";
    const then = new Date(raw);
    if (isNaN(then.getTime()))
      return "";
    const minutes = Math.max(0, (Time.now.getTime() - then.getTime()) / 60000);
    if (minutes < 60)
      return Math.floor(minutes) + "m ago";
    const hours = minutes / 60;
    if (hours < 24)
      return Math.floor(hours) + "h ago";
    return Math.floor(hours / 24) + "d ago";
  }
}
