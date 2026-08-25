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

  // "topic:url" pairs. Every one of these was checked to actually parse; InfoQ,
  // blog.flutter.dev and Reddit's RSS were dropped because they 404 or block us.
  // dev.to's tag feeds are deliberately absent — they publish constantly and are
  // full of affiliate spam, which buried the .NET Blog and V8 entirely. Add them
  // back through QS_DEV_FEEDS if you want the volume.
  readonly property string devFeeds: envOr("QS_DEV_FEEDS", ["dotnet:https://devblogs.microsoft.com/dotnet/feed/", "dotnet:https://andrewlock.net/rss.xml", "dotnet:https://blog.jetbrains.com/dotnet/feed/", "dotnet:https://devblogs.microsoft.com/visualstudio/feed/", "flutter:https://medium.com/feed/flutter", "flutter:https://medium.com/feed/tag/flutter", "flutter:https://iirokrankka.com/feed.xml", "node:https://nodejs.org/en/feed/blog.xml", "node:https://medium.com/feed/tag/nodejs", "node:https://blog.logrocket.com/feed/", "js:https://v8.dev/blog.atom", "js:https://developer.chrome.com/static/blog/feed.xml", "js:https://react.dev/rss.xml", "js:https://github.blog/feed/", "js:https://css-tricks.com/feed/", "ai:https://openai.com/news/rss.xml", "ai:https://huggingface.co/blog/feed.xml", "ai:https://deepmind.google/blog/rss.xml", "ai:https://simonwillison.net/atom/everything/", "ai:https://blog.google/technology/ai/rss/", "general:https://news.ycombinator.com/rss", "general:https://lobste.rs/rss", "general:https://changelog.com/feed"].join("|"))

  property bool open: false
  property string tab: "stocks"          // "stocks" | "news" | "dev"

  readonly property var tabs: ["stocks", "news", "dev"]

  property var stocks: []
  property var news: []
  property var dev: []
  property bool loadingStocks: false
  property bool loadingNews: false
  property bool loadingDev: false
  property string stocksError: ""
  property string newsError: ""
  property string devError: ""

  // "" means everything; otherwise one of the topic ids the fetcher tags with.
  property string devTopic: ""

  readonly property var devTopics: [
    {
      id: "",
      label: "All"
    },
    {
      id: "dotnet",
      label: ".NET"
    },
    {
      id: "flutter",
      label: "Flutter"
    },
    {
      id: "node",
      label: "Node"
    },
    {
      id: "js",
      label: "JS"
    },
    {
      id: "ai",
      label: "AI"
    }
  ]

  readonly property var devFiltered: {
    if (root.devTopic.length === 0)
      return root.dev;
    return root.dev.filter(item => (item.topics ?? []).indexOf(root.devTopic) >= 0);
  }

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
    if (root.dev.length === 0)
      root.refreshDev();
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

  // ---------------------------------------------------------------- dev feed
  Process {
    id: devProc
    command: ["python3", Quickshell.shellPath("scripts/devnews.py"), root.devFeeds]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.dev = JSON.parse(text);
          root.devError = "";
        } catch (e) {
          root.devError = "Couldn't read tech headlines.";
        }
      }
    }

    onExited: root.loadingDev = false
  }

  function refreshDev() {
    if (devProc.running)
      return;
    root.loadingDev = true;
    devProc.running = true;
  }

  function refresh() {
    root.refreshStocks();
    root.refreshNews();
    root.refreshDev();
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

  // Blogs and release notes move slower still.
  Timer {
    running: root.open
    interval: 30 * 60 * 1000
    repeat: true
    onTriggered: root.refreshDev()
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
