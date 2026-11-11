#!/usr/bin/env python3
"""Upcoming events from a Google Calendar, for the island.

Reads secret iCal addresses from ~/.local/share/quickshell/calendar-url, one
per line, so several accounts or calendars merge into one list (the file is
kept out of the dotfiles: anyone with a link can read that calendar). Fetches
each and prints one JSON object:

  {"events": [{"id", "title", "start", "end", "allDay", "where", "link", "cal"}]}

`cal` is which line of the file the event came from (0 = the first), so each
account can have its own colour.

`start`/`end` are epoch milliseconds. Covers the start of last month through
about three months ahead (enough for the Today card's month grid), repeating
events expanded. A calendar that fails is skipped; only if all of them fail
does it print {"error": "..."}, and the island keeps what it had.

Needs python-icalendar and python-recurring-ical-events.

Not named calendar.py on purpose: that would shadow the standard library's
`calendar` module, which the iCal libraries import.
"""
import datetime as dt
import json
import os
import re
import sys
import urllib.request

URL_FILE = os.path.expanduser("~/.local/share/quickshell/calendar-url")
CALL = re.compile(r"https://(?:meet\.google\.com|[\w.-]*zoom\.us|teams\.microsoft\.com|teams\.live\.com)/[^\s<>\"\\]+")
ANY_URL = re.compile(r"https?://[^\s<>\"\\]+")


def fail(message):
    print(json.dumps({"error": message}), flush=True)
    sys.exit(0)


def millis(value, end_of_day=False):
    """A DATE or DATE-TIME from the calendar, as epoch ms in local time."""
    if isinstance(value, dt.datetime):
        if value.tzinfo is None:
            value = value.astimezone()
        return int(value.timestamp() * 1000)
    day = dt.datetime.combine(value, dt.time.min).astimezone()
    return int(day.timestamp() * 1000)


def call_link(event):
    for key in ("X-GOOGLE-CONFERENCE", "LOCATION", "DESCRIPTION", "URL"):
        text = str(event.get(key, "") or "")
        m = CALL.search(text)
        if m:
            return m.group(0).rstrip(").,")
    m = ANY_URL.search(str(event.get("LOCATION", "") or ""))
    return m.group(0).rstrip(").,") if m else ""


def where(event, link):
    place = str(event.get("LOCATION", "") or "").strip()
    if place and not ANY_URL.fullmatch(place):
        return place.split("\n")[0]
    if "meet.google.com" in link:
        return "Google Meet"
    if "zoom.us" in link:
        return "Zoom"
    if "teams." in link:
        return "Teams"
    return ""


def main():
    try:
        import icalendar
        import recurring_ical_events
    except ImportError:
        fail("needs python-icalendar and python-recurring-ical-events")

    try:
        with open(URL_FILE) as f:
            urls = [line.strip() for line in f if line.strip()]
    except OSError:
        fail("no calendar link saved")
    urls = [u for u in urls if "/private-" in u or not u.startswith("https://calendar.google.com/")]
    if not urls:
        fail("no secret iCal address saved")

    today = dt.date.today()
    start = today.replace(day=1) - dt.timedelta(days=31)
    end = today + dt.timedelta(days=100)

    found = []
    problems = []
    for index, url in enumerate(urls):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "quickshell-island"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                cal = icalendar.Calendar.from_ical(resp.read())
            found += [(index, ev) for ev in recurring_ical_events.of(cal).between(start, end)]
        except Exception as e:  # offline, timeout, revoked link, bad data
            problems.append(type(e).__name__)
    if problems and len(problems) == len(urls):
        fail("could not fetch the calendar: " + ", ".join(sorted(set(problems))))

    events = []
    seen = set()
    for index, ev in found:
        if str(ev.get("STATUS", "")).upper() == "CANCELLED":
            continue
        begin = ev.get("DTSTART").dt
        finish = ev.get("DTEND").dt if ev.get("DTEND") else begin
        all_day = not isinstance(begin, dt.datetime)
        link = call_link(ev)
        # A meeting you were invited to shows up in both accounts: keep one.
        key = (str(ev.get("SUMMARY", "")).strip(), millis(begin))
        if key in seen:
            continue
        seen.add(key)
        events.append({
            "id": str(ev.get("UID", "")) + "@" + str(millis(begin)),
            "title": str(ev.get("SUMMARY", "") or "Busy").strip(),
            "start": millis(begin),
            "end": millis(finish),
            "allDay": all_day,
            "where": where(ev, link),
            "link": link,
            "cal": index,
        })
    events.sort(key=lambda e: (e["start"], e["title"]))
    print(json.dumps({"events": events}), flush=True)


if __name__ == "__main__":
    main()
