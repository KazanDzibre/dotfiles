#!/usr/bin/env python3
"""Quick answers for the island search: time zones, unit conversion, dates and
"x% of y".

Plain arithmetic is not handled here: Spotlight.qml's calculator answers that
instantly and synchronously. This covers what QML cannot do well -- QML's
JavaScript has no way to format a time in an arbitrary time zone -- and is the
same stdlib-only, no-network shape as the other helpers.

The text is matched against a handful of patterns after dropping filler words,
so "time in tokyo", "tokyo time" and "what time is it in Tokyo?" all land on the
same answer. Anything that matches nothing prints {} and the search just shows
its usual results.

Usage: answer.py "time in tokyo"
Prints one JSON object: {"title": ..., "sub": ..., "value": ...} or {}.
"""
import difflib
import json
import re
import sys
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo, available_timezones

# --------------------------------------------------------------------- units
LENGTH = {"m": 1, "km": 1000, "cm": 0.01, "mm": 0.001, "mi": 1609.344, "ft": 0.3048, "in": 0.0254, "yd": 0.9144}
MASS = {"kg": 1, "g": 0.001, "mg": 1e-6, "lb": 0.45359237, "oz": 0.0283495, "st": 6.35029}
VOLUME = {"l": 1, "ml": 0.001, "gal": 3.78541, "qt": 0.946353, "pt": 0.473176, "cup": 0.24, "floz": 0.0295735}
SPEED = {"kmh": 1, "mph": 1.609344, "ms": 3.6, "kn": 1.852}
FAMILIES = [("length", LENGTH), ("mass", MASS), ("volume", VOLUME), ("speed", SPEED)]

ALIASES = {
    "kilometer": "km", "kilometre": "km", "kilometers": "km", "kilometres": "km", "kms": "km",
    "meter": "m", "metre": "m", "meters": "m", "metres": "m",
    "centimeter": "cm", "centimeters": "cm", "millimeter": "mm", "millimeters": "mm",
    "mile": "mi", "miles": "mi", "foot": "ft", "feet": "ft", "inch": "in", "inches": "in", "yard": "yd", "yards": "yd",
    "kilogram": "kg", "kilograms": "kg", "kilo": "kg", "kilos": "kg", "gram": "g", "grams": "g",
    "pound": "lb", "pounds": "lb", "lbs": "lb", "ounce": "oz", "ounces": "oz", "stone": "st",
    "liter": "l", "liters": "l", "litre": "l", "litres": "l", "milliliter": "ml", "milliliters": "ml",
    "gallon": "gal", "gallons": "gal", "cups": "cup", "quart": "qt", "pint": "pt",
    "km/h": "kmh", "kph": "kmh", "kmph": "kmh", "m/s": "ms", "knot": "kn", "knots": "kn",
}
TEMPS = {"c": "c", "f": "f", "k": "k", "celsius": "c", "fahrenheit": "f", "kelvin": "k",
         "°c": "c", "°f": "f", "degc": "c", "degf": "f", "degrees": None}


def fmt(value):
    if value != value or value in (float("inf"), float("-inf")):
        return "—"
    magnitude = abs(value)
    if magnitude >= 1e12 or (0 < magnitude < 1e-6):
        return f"{value:.3e}"
    places = 2 if magnitude >= 1000 else 3 if magnitude >= 1 else 6
    text = f"{value:,.{places}f}".rstrip("0").rstrip(".")
    return text or "0"


def number(text):
    return float(text.replace(",", "."))


def unit_answer(match):
    value = number(match.group(1))
    source, target = match.group(2), match.group(3)

    # "72 degrees f in c" -> drop the filler word.
    source = TEMPS.get(source, source) if source in TEMPS else source
    if source in ("c", "f", "k") and target in TEMPS and TEMPS[target] in ("c", "f", "k"):
        kind_from, kind_to = source, TEMPS[target]
        celsius = value if kind_from == "c" else (value - 32) * 5 / 9 if kind_from == "f" else value - 273.15
        out = celsius if kind_to == "c" else celsius * 9 / 5 + 32 if kind_to == "f" else celsius + 273.15
        symbol = "K" if kind_to == "k" else "°" + kind_to.upper()
        origin = "K" if kind_from == "k" else "°" + kind_from.upper()
        return {"title": f"= {fmt(out)} {symbol}", "sub": f"{fmt(value)} {origin}", "value": f"{fmt(out)} {symbol}"}

    source = ALIASES.get(source, source)
    target = ALIASES.get(target, target)
    for name, table in FAMILIES:
        if source in table and target in table:
            out = value * table[source] / table[target]
            return {"title": f"= {fmt(out)} {target}", "sub": f"{fmt(value)} {source} · {name}", "value": f"{fmt(out)} {target}"}
    return None


# ----------------------------------------------------------------- time zones
# Names the tz database does not use, or uses for a region rather than a city.
PLACES = {
    "san francisco": "America/Los_Angeles", "seattle": "America/Los_Angeles", "silicon valley": "America/Los_Angeles",
    "portland": "America/Los_Angeles", "nyc": "America/New_York", "new york city": "America/New_York",
    "boston": "America/New_York", "miami": "America/New_York", "washington": "America/New_York",
    "usa": "America/New_York", "us": "America/New_York", "uk": "Europe/London", "england": "Europe/London",
    "japan": "Asia/Tokyo", "serbia": "Europe/Belgrade", "germany": "Europe/Berlin", "france": "Europe/Paris",
    "italy": "Europe/Rome", "spain": "Europe/Madrid", "india": "Asia/Kolkata", "delhi": "Asia/Kolkata",
    "mumbai": "Asia/Kolkata", "china": "Asia/Shanghai", "beijing": "Asia/Shanghai", "australia": "Australia/Sydney",
    "melbourne": "Australia/Melbourne", "korea": "Asia/Seoul", "uae": "Asia/Dubai", "utc": "UTC", "gmt": "UTC",
    "cet": "Europe/Berlin", "est": "America/New_York", "pst": "America/Los_Angeles",
}


def build_zone_index():
    index = {}
    for name in available_timezones():
        if "/" not in name or name.startswith(("Etc/", "SystemV/", "US/", "posix/", "right/")):
            continue
        index.setdefault(name.split("/")[-1].replace("_", " ").lower(), name)
    index.update(PLACES)
    return index


def find_zone(text):
    index = build_zone_index()
    key = re.sub(r"\s+", " ", text.strip().lower())
    if key in index:
        return index[key], key
    close = difflib.get_close_matches(key, index.keys(), n=1, cutoff=0.78)
    return (index[close[0]], close[0]) if close else (None, key)


def time_answer(place):
    zone, label = find_zone(place)
    if not zone:
        return None
    now = datetime.now(ZoneInfo(zone))
    here = datetime.now().astimezone()
    delta = (now.utcoffset() - here.utcoffset()).total_seconds() / 3600
    if delta == 0:
        relation = "same time as you"
    else:
        relation = f"{'+' if delta > 0 else '−'}{fmt(abs(delta))} h from you"
    clock = now.strftime("%H:%M")
    return {"title": clock, "sub": f"{label.title()} · {now.strftime('%a %-d %b')} · {relation}", "value": clock}


# ---------------------------------------------------------------------- dates
MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]


def days_until(day, month_text):
    month = next((i for i, m in enumerate(MONTHS) if month_text.startswith(m)), None)
    if month is None:
        return None
    today = datetime.now().date()
    try:
        target = today.replace(month=month + 1, day=int(day))
    except ValueError:
        return None
    if target < today:
        target = target.replace(year=today.year + 1)
    days = (target - today).days
    word = "day" if days == 1 else "days"
    return {"title": f"{days} {word}", "sub": target.strftime("%A %-d %B %Y"), "value": f"{days} {word}"}


def date_offset(count, direction):
    when = datetime.now().date() + timedelta(days=count if direction != "ago" else -count)
    text = when.strftime("%a %-d %b")
    return {"title": text, "sub": when.strftime("%A %-d %B %Y"), "value": text}


# ------------------------------------------------------------------- matching
FILLER = re.compile(r"^(?:what(?:'s|s| is)?|whats|convert|how (?:much|many) is|tell me|show me|current)\s+", re.I)


def answer(raw):
    text = raw.strip().lower().rstrip("?!. ")
    text = re.sub(r"\s+", " ", text)
    text = FILLER.sub("", text)
    text = re.sub(r"^(?:the|is|it)\s+", "", text)
    if not text:
        return None

    m = re.match(r"^([\d.,]+)\s*(?:%|percent)\s*of\s*([\d.,]+)$", text)
    if m:
        pct, base = number(m.group(1)), number(m.group(2))
        out = pct / 100 * base
        return {"title": f"= {fmt(out)}", "sub": f"{fmt(pct)}% of {fmt(base)}", "value": fmt(out)}

    m = re.match(r"^([\d.,]+)\s*(?:degrees?\s*)?([a-z°/]+)\s+(?:in|to|into|as)\s+(?:degrees?\s*)?([a-z°/]+)$", text)
    if m:
        out = unit_answer(m)
        if out:
            return out

    m = re.match(r"^(?:days?|how long) (?:until|till|to) (\d{1,2})(?:st|nd|rd|th)?\s+([a-z]+)$", text) \
        or re.match(r"^(?:days?|how long) (?:until|till|to) ([a-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?$", text)
    if m:
        a, b = m.group(1), m.group(2)
        day, month = (a, b) if a.isdigit() else (b, a)
        out = days_until(day, month)
        if out:
            return out

    m = re.match(r"^in (\d{1,4}) days?$", text) or re.match(r"^(\d{1,4}) days? from (?:now|today)$", text)
    if m:
        return date_offset(int(m.group(1)), "ahead")
    m = re.match(r"^(\d{1,4}) days? ago$", text)
    if m:
        return date_offset(int(m.group(1)), "ago")

    for pattern in (r"^time (?:is it )?(?:in|at|for) (.+)$", r"^(.+?) time$", r"^time (.+)$"):
        m = re.match(pattern, text)
        if m:
            place = re.sub(r"^(?:the|it|now)\s+", "", m.group(1)).strip()
            out = time_answer(place)
            if out:
                return out
    return None


def main():
    query = " ".join(sys.argv[1:])
    try:
        result = answer(query) or {}
    except Exception:
        result = {}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
