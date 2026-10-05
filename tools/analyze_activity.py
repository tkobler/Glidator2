#!/usr/bin/env python3
"""Per-lap analysis of a Garmin TCX activity (Python 3 standard library only).

Not part of the Connect IQ build: a reference tool to compare what the watch
shows with values recomputed from the recorded file.

For each lap it prints: duration, number of points, mean interval, recorded
distance, GPS distance (haversine), elevation gain (hysteresis threshold),
share of zero speed, position jumps, vertical speed over 60 s (three methods,
see below), pace over 60 s and heart rate min/max.

Vertical speed over a trailing 60 s window, evaluated at every trackpoint
(window = points with t_i - t <= 60 s, needs >= 3 points and >= 20 s covered):
  - "regression": least-squares slope of altitude against time;
  - "diff": (last altitude - first altitude) / (last time - first time),
    the method behind the figures of the corrections plan;
  - "watch": replay of HikeHistory.mc on the trackpoints (one sample at most
    every 5 s, reset after a gap > 15 s, regression over 60 s). The TCX is
    smart-recorded (points every 1-37 s) while the watch samples at 1 Hz, so
    this is an approximation of what the watch displayed.

Usage:
    python3 tools/analyze_activity.py ACTIVITY.tcx [--csv OUT.csv] [--gain-threshold 1.0]
"""

import argparse
import csv
import math
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import List, Optional

NS = {
    "tcx": "http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2",
    "ext": "http://www.garmin.com/xmlschemas/ActivityExtension/v2",
}

EARTH_RADIUS_M = 6371008.8

WINDOW_S = 60.0
MIN_POINTS = 3
MIN_COVERAGE_S = 20.0

# Same rule as audit 3b: a position step is a jump when it is longer than
# JUMP_BASE_M + JUMP_SPEED_MPS * dt.
JUMP_BASE_M = 50.0
JUMP_SPEED_MPS = 60.0

# HikeHistory.mc constants.
WATCH_MAX_SAMPLES = 60
WATCH_MIN_SPACING_S = 5.0
WATCH_MAX_GAP_S = 15.0


class _NotSampled:
    """Marks, in the watch series, a point the watch logic did not keep."""

    def __repr__(self):
        return "NOT_SAMPLED"


NOT_SAMPLED = _NotSampled()


@dataclass
class Point:
    t: float  # POSIX seconds
    lat: Optional[float] = None
    lon: Optional[float] = None
    alt: Optional[float] = None
    dist: Optional[float] = None
    hr: Optional[int] = None
    speed: Optional[float] = None


@dataclass
class Lap:
    start: Optional[str]
    total_time_s: Optional[float]
    distance_m: Optional[float]
    points: List[Point] = field(default_factory=list)


@dataclass
class Jump:
    index: int  # index of the point after the jump
    distance_m: float
    dt_s: float


# --------------------------------------------------------------------------
# Parsing


def _float(elem):
    if elem is None or elem.text is None or not elem.text.strip():
        return None
    try:
        return float(elem.text)
    except ValueError:
        return None


def _parse_time(text):
    text = text.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    d = datetime.fromisoformat(text)
    if d.tzinfo is None:
        d = d.replace(tzinfo=timezone.utc)
    return d.timestamp()


def _parse_root(root):
    laps = []
    for lap_el in root.iter("{%s}Lap" % NS["tcx"]):
        lap = Lap(
            start=lap_el.get("StartTime"),
            total_time_s=_float(lap_el.find("tcx:TotalTimeSeconds", NS)),
            distance_m=_float(lap_el.find("tcx:DistanceMeters", NS)),
        )
        for tp in lap_el.iterfind("tcx:Track/tcx:Trackpoint", NS):
            time_el = tp.find("tcx:Time", NS)
            if time_el is None or not (time_el.text or "").strip():
                continue
            lat = _float(tp.find("tcx:Position/tcx:LatitudeDegrees", NS))
            lon = _float(tp.find("tcx:Position/tcx:LongitudeDegrees", NS))
            if lat is None or lon is None:
                lat = lon = None
            hr = _float(tp.find("tcx:HeartRateBpm/tcx:Value", NS))
            lap.points.append(Point(
                t=_parse_time(time_el.text),
                lat=lat,
                lon=lon,
                alt=_float(tp.find("tcx:AltitudeMeters", NS)),
                dist=_float(tp.find("tcx:DistanceMeters", NS)),
                hr=None if hr is None else int(round(hr)),
                speed=_float(tp.find("tcx:Extensions/ext:TPX/ext:Speed", NS)),
            ))
        laps.append(lap)
    return laps


def parse_tcx_string(text):
    return _parse_root(ET.fromstring(text))


def parse_tcx(path):
    return _parse_root(ET.parse(path).getroot())


# --------------------------------------------------------------------------
# Basic measures


def haversine_m(lat1, lon1, lat2, lon2):
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lon2 - lon1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_RADIUS_M * math.asin(min(1.0, math.sqrt(h)))


def _positioned(points):
    return [(i, p) for i, p in enumerate(points) if p.lat is not None]


def gps_distance_m(points):
    """Sum of haversine steps between consecutive points that have a
    position (points without one are bridged). None if no position."""
    pos = _positioned(points)
    if not pos:
        return None
    total = 0.0
    for (_, a), (_, b) in zip(pos, pos[1:]):
        total += haversine_m(a.lat, a.lon, b.lat, b.lon)
    return total


def elevation_gain_m(alts, threshold=1.0):
    """Elevation gain with hysteresis: a rise is counted once the altitude is
    at least `threshold` above the reference; a drop of more than
    `threshold` moves the reference down. None values are skipped.

    Known asymmetry (kept as is for now): the test is `>=` going up but `>`
    going down, and on a descent the reference moves down in steps (only
    when the altitude is more than `threshold` below it) instead of
    following the running minimum. After a descent the reference can thus
    sit up to `threshold` above the true low point, so the next climb may
    be undercounted by up to `threshold`. The residual rise at the end of
    the series (below `threshold`) is not counted either."""
    values = [a for a in alts if a is not None]
    if not values:
        return None
    gain = 0.0
    ref = values[0]
    for a in values[1:]:
        if a - ref >= threshold:
            gain += a - ref
            ref = a
        elif ref - a > threshold:
            ref = a
    return gain


def zero_speed_count(points):
    """(points with speed == 0, points carrying a speed)."""
    with_speed = [p.speed for p in points if p.speed is not None]
    return sum(1 for s in with_speed if s == 0.0), len(with_speed)


def is_jump(distance_m, dt_s):
    return distance_m > JUMP_BASE_M + JUMP_SPEED_MPS * dt_s


def detect_jumps(points):
    pos = _positioned(points)
    jumps = []
    for (_, a), (j, b) in zip(pos, pos[1:]):
        d = haversine_m(a.lat, a.lon, b.lat, b.lon)
        dt = b.t - a.t
        if is_jump(d, dt):
            jumps.append(Jump(index=j, distance_m=d, dt_s=dt))
    return jumps


def percentile(values, p):
    """Linear-interpolation percentile (numpy's default), ignoring anything
    that is not a number (None, NOT_SAMPLED)."""
    v = sorted(x for x in values if isinstance(x, (int, float)) and not isinstance(x, bool))
    if not v:
        return None
    k = (len(v) - 1) * p / 100.0
    lo = int(math.floor(k))
    hi = min(lo + 1, len(v) - 1)
    return v[lo] + (v[hi] - v[lo]) * (k - lo)


def _slope_per_s(ts, ys, t_ref):
    n = len(ts)
    xs = [t - t_ref for t in ts]
    y0 = ys[0]
    mx = sum(xs) / n
    my = sum(y - y0 for y in ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    if sxx <= 0.0:
        return None
    sxy = sum((x - mx) * ((y - y0) - my) for x, y in zip(xs, ys))
    return sxy / sxx


# --------------------------------------------------------------------------
# 60 s series


def _trailing_windows(points, attr, window_s):
    """For each point, yields (index, [window samples (t, value)]) where the
    window holds the points with a value and t_i - t <= window_s. Points
    without a value yield None as window."""
    samples = []
    start = 0
    for i, p in enumerate(points):
        v = getattr(p, attr)
        if v is None:
            yield i, None
            continue
        samples.append((p.t, v))
        while p.t - samples[start][0] > window_s:
            start += 1
        yield i, samples[start:]


def _enough(window, min_points, min_coverage_s):
    return len(window) >= min_points and window[-1][0] - window[0][0] >= min_coverage_s


def vertical_speed_series(points, method="regression", window_s=WINDOW_S,
                          min_points=MIN_POINTS, min_coverage_s=MIN_COVERAGE_S):
    """Vertical speed (m/h) at every point over a trailing window."""
    if method not in ("regression", "diff"):
        raise ValueError("unknown method: %r" % method)
    out = []
    for i, w in _trailing_windows(points, "alt", window_s):
        if w is None or not _enough(w, min_points, min_coverage_s):
            out.append(None)
            continue
        if method == "regression":
            s = _slope_per_s([t for t, _ in w], [a for _, a in w], w[-1][0])
            out.append(None if s is None else s * 3600.0)
        else:
            out.append((w[-1][1] - w[0][1]) / (w[-1][0] - w[0][0]) * 3600.0)
    return out


def watch_vertical_speed_series(points, window_s=WINDOW_S):
    """Replays HikeHistory.mc. Returns, per point, NOT_SAMPLED if the watch
    logic would drop it, else the vertical speed (m/h) or None."""
    out = []
    buf = []  # accepted (t, alt), at most WATCH_MAX_SAMPLES
    last_t = None
    for p in points:
        if p.alt is None:
            out.append(NOT_SAMPLED)
            continue
        if last_t is not None:
            dt = p.t - last_t
            if dt < 0 or dt > WATCH_MAX_GAP_S:
                buf = []
            elif dt < WATCH_MIN_SPACING_S:
                out.append(NOT_SAMPLED)
                continue
        buf.append((p.t, p.alt))
        if len(buf) > WATCH_MAX_SAMPLES:
            buf.pop(0)
        last_t = p.t
        w = [s for s in buf if p.t - s[0] <= window_s]
        if not _enough(w, MIN_POINTS, MIN_COVERAGE_S):
            out.append(None)
            continue
        s = _slope_per_s([t for t, _ in w], [a for _, a in w], p.t)
        out.append(None if s is None else s * 3600.0)
    return out


def speed_series(points, window_s=WINDOW_S, min_points=MIN_POINTS,
                 min_coverage_s=MIN_COVERAGE_S):
    """Horizontal speed (m/s) at every point: delta recorded distance / delta t
    over a trailing window. None if the distance went down."""
    out = []
    for i, w in _trailing_windows(points, "dist", window_s):
        if w is None or not _enough(w, min_points, min_coverage_s) or w[-1][1] < w[0][1]:
            out.append(None)
            continue
        out.append((w[-1][1] - w[0][1]) / (w[-1][0] - w[0][0]))
    return out


def format_pace(speed_mps):
    """min:sec per km, '-' if no speed or zero."""
    if speed_mps is None or speed_mps <= 0.0:
        return "-"
    total = int(round(1000.0 / speed_mps))
    return "%d:%02d" % (total // 60, total % 60)


# --------------------------------------------------------------------------
# Summary and report


def _stats(values):
    nums = [v for v in values if isinstance(v, (int, float))]
    return {
        "n": len(nums),
        "median": percentile(nums, 50),
        "p5": percentile(nums, 5),
        "p95": percentile(nums, 95),
    }


def summarize_lap(lap, gain_threshold=1.0):
    pts = lap.points
    span = pts[-1].t - pts[0].t if pts else 0.0
    intervals = [b.t - a.t for a, b in zip(pts, pts[1:])]
    recorded = lap.distance_m
    if recorded is None:
        dists = [p.dist for p in pts if p.dist is not None]
        recorded = dists[-1] - dists[0] if dists else None
    zero, with_speed = zero_speed_count(pts)
    hrs = [p.hr for p in pts if p.hr is not None]
    vs_reg = vertical_speed_series(pts, "regression")
    vs_diff = vertical_speed_series(pts, "diff")
    vs_watch = watch_vertical_speed_series(pts)
    speeds = speed_series(pts)
    return {
        "start": lap.start,
        "points": len(pts),
        "duration_s": lap.total_time_s if lap.total_time_s is not None else span,
        "span_s": span,
        "mean_interval_s": span / len(intervals) if intervals else None,
        "max_interval_s": max(intervals) if intervals else None,
        "recorded_distance_m": recorded,
        "gps_distance_m": gps_distance_m(pts),
        "gain_threshold_m": gain_threshold,
        "elevation_gain_m": elevation_gain_m([p.alt for p in pts], gain_threshold),
        "zero_speed": zero,
        "with_speed": with_speed,
        "jumps": detect_jumps(pts),
        "vs_regression": _stats(vs_reg),
        "vs_diff": _stats(vs_diff),
        "vs_watch": _stats(vs_watch),
        "speed60_median_mps": percentile(speeds, 50),
        "hr_min": min(hrs) if hrs else None,
        "hr_max": max(hrs) if hrs else None,
        "series": {
            "vs_regression": vs_reg,
            "vs_diff": vs_diff,
            "vs_watch": vs_watch,
            "speed": speeds,
        },
    }


def _fmt(v, spec="%.1f", unit=""):
    return "-" if v is None else (spec % v) + unit


def _hms(s):
    s = int(round(s))
    return "%d:%02d:%02d" % (s // 3600, s % 3600 // 60, s % 60)


def _fmt_vs(st):
    if st["median"] is None:
        return "- (aucune fenetre valide)"
    return "mediane %+.0f m/h, p5 %+.0f, p95 %+.0f (n=%d)" % (
        st["median"], st["p5"], st["p95"], st["n"])


def format_report(summaries):
    lines = []
    for k, s in enumerate(summaries, 1):
        lines.append("Lap %d - debut %s" % (k, s["start"] or "?"))
        lines.append("  Duree                  : %s s (%s), etendue des points %.1f s"
                     % (_fmt(s["duration_s"]), _hms(s["duration_s"] or 0.0), s["span_s"]))
        lines.append("  Points                 : %d, intervalle moyen %s, max %s"
                     % (s["points"], _fmt(s["mean_interval_s"], "%.2f", " s"),
                        _fmt(s["max_interval_s"], "%.0f", " s")))
        lines.append("  Distance enregistree   : %s" % _fmt(s["recorded_distance_m"], unit=" m"))
        gps = s["gps_distance_m"]
        rec = s["recorded_distance_m"]
        rel = ""
        if gps is not None and rec:
            rel = " (%+.1f %% vs enregistree)" % (100.0 * (gps - rec) / rec)
        lines.append("  Distance GPS           : %s%s" % (_fmt(gps, unit=" m"), rel))
        lines.append("  D+ (seuil %.1f m)       : %s"
                     % (s["gain_threshold_m"], _fmt(s["elevation_gain_m"], unit=" m")))
        zs = s["with_speed"]
        pct = " (%.1f %%)" % (100.0 * s["zero_speed"] / zs) if zs else ""
        lines.append("  Vitesse a 0            : %d / %d%s" % (s["zero_speed"], zs, pct))
        lines.append("  Sauts de position      : %d (regle > %.0f m + %.0f m/s x dt)"
                     % (len(s["jumps"]), JUMP_BASE_M, JUMP_SPEED_MPS))
        for j in s["jumps"][:10]:
            lines.append("    point %d : %.0f m en %.0f s" % (j.index, j.distance_m, j.dt_s))
        if len(s["jumps"]) > 10:
            lines.append("    ... %d autres" % (len(s["jumps"]) - 10))
        lines.append("  VS 60 s regression     : %s" % _fmt_vs(s["vs_regression"]))
        lines.append("  VS 60 s dalt/dt        : %s" % _fmt_vs(s["vs_diff"]))
        lines.append("  VS montre (HikeHistory): %s" % _fmt_vs(s["vs_watch"]))
        sp = s["speed60_median_mps"]
        lines.append("  Pace 60 s              : mediane %s min/km (vitesse %s)"
                     % (format_pace(sp), _fmt(sp, "%.2f", " m/s")))
        lines.append("  FC                     : min %s, max %s"
                     % (_fmt(s["hr_min"], "%d", " bpm"), _fmt(s["hr_max"], "%d", " bpm")))
        lines.append("")
    return "\n".join(lines)


CSV_COLUMNS = ["lap", "time", "elapsed_s", "altitude_m", "distance_m",
               "vs60_regression_mh", "vs60_diff_mh", "vs_watch_mh",
               "speed60_mps", "pace60_min_km"]


def _cell(v, spec="%.2f"):
    if v is None or v is NOT_SAMPLED:
        return ""
    return spec % v


def write_csv(laps, summaries, out):
    w = csv.writer(out)
    w.writerow(CSV_COLUMNS)
    t0 = None
    for k, (lap, s) in enumerate(zip(laps, summaries), 1):
        ser = s["series"]
        for i, p in enumerate(lap.points):
            if t0 is None:
                t0 = p.t
            sp = ser["speed"][i]
            w.writerow([
                k,
                datetime.fromtimestamp(p.t, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "%.0f" % (p.t - t0),
                _cell(p.alt, "%.1f"),
                _cell(p.dist),
                _cell(ser["vs_regression"][i], "%.1f"),
                _cell(ser["vs_diff"][i], "%.1f"),
                _cell(ser["vs_watch"][i], "%.1f"),
                _cell(sp, "%.3f"),
                "" if sp is None or sp <= 0 else format_pace(sp),
            ])


def main(argv=None):
    parser = argparse.ArgumentParser(description="Per-lap analysis of a TCX activity.")
    parser.add_argument("tcx", help="TCX file")
    parser.add_argument("--csv", help="export the 60 s series (one row per trackpoint)")
    parser.add_argument("--gain-threshold", type=float, default=1.0,
                        help="hysteresis threshold for D+ in m (default 1.0)")
    args = parser.parse_args(argv)

    try:
        laps = parse_tcx(args.tcx)
    except OSError as e:
        print("error: cannot read %s: %s" % (args.tcx, e), file=sys.stderr)
        return 2
    except ET.ParseError as e:
        print("error: invalid XML in %s: %s" % (args.tcx, e), file=sys.stderr)
        return 2

    summaries = [summarize_lap(lap, args.gain_threshold) for lap in laps]
    print("%s : %d lap(s), %d points" % (args.tcx, len(laps), sum(len(l.points) for l in laps)))
    print("Fenetres de %.0f s glissantes (fin au point), >= %d points et >= %.0f s couverts.\n"
          % (WINDOW_S, MIN_POINTS, MIN_COVERAGE_S))
    print(format_report(summaries))

    if args.csv:
        with open(args.csv, "w", newline="") as f:
            write_csv(laps, summaries, f)
        print("Serie 60 s exportee : %s" % args.csv)
    return 0


if __name__ == "__main__":
    sys.exit(main())
