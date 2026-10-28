#!/usr/bin/env python3
"""Reference table ("etalon") of the hike lap of a Garmin activity, and test
extracts for the hike pages (Python 3 standard library only).

Not part of the Connect IQ build. Reads the GPX (positions, elevation, heart
rate, with the GPX line of every <trkpt>) and the TCX of the same activity
(laps, recorded distance), and:

  1. prints the TCX lap totals next to the values recomputed from the points;
  2. writes a minute-by-minute table of the hike lap (--minutes-csv);
  3. picks three extracts of N consecutive points -- regular climb, flat
     section, steep climb -- and writes them with the values the app's
     HikeHistory.mc should compute when fed with exactly those rows
     (--extracts-prefix);
  4. optionally (--sim-log) compares the altitudes a simulator log received
     with the GPX elevation at the nearest GPX point;
  5. optionally (--at SECONDS, repeatable) prints the values at a given time
     from the start of the hike lap.

Elevation gain is given three ways (cumulative, per point):
  - raw: sum of every positive elevation step;
  - h1: symmetric hysteresis of 1 m (analyze_activity.elevation_gain_m, the
    repository reference);
  - h3: the same hysteresis with 3 m, used as the "smoothed, Garmin-like"
    value. Garmin does not publish its totalAscent filter and neither file
    holds the watch's total ascent: h3 is a stated assumption, not a
    calibrated value.

Usage:
    python3 tools/etalon_marche.py GPX TCX [--lap 1] [--minutes-csv OUT.csv]
        [--extracts-prefix PREFIX] [--extract-points 40] [--sim-log LOG]
        [--at 253 ...]
"""

import argparse
import csv
import math
import os
import re
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import analyze_activity as aa  # noqa: E402

GPX_NS = {
    "gpx": "http://www.topografix.com/GPX/1/1",
    "tpx": "http://www.garmin.com/xmlschemas/TrackPointExtension/v1",
}

# HikeHistory.mc constants (source/HikeHistory.mc:10-14).
HH_MAX_SAMPLES = 60
HH_MIN_SPACING_MS = 5000
HH_MAX_GAP_MS = 15000
HH_MIN_POINTS = 3
HH_MIN_COVERAGE_MS = 20000
# WatchData.HIKE_WINDOW_MS (pace) and Preferences VS_WINDOW_DEFAULT_MS.
HH_WINDOW_MS = 60000

SMOOTH_THRESHOLD_M = 3.0


# --------------------------------------------------------------------------
# Parsing


class GpxPoint:
    __slots__ = ("index", "line", "t", "lat", "lon", "ele", "hr")

    def __init__(self, index, line, t, lat, lon, ele, hr):
        self.index = index
        self.line = line
        self.t = t
        self.lat = lat
        self.lon = lon
        self.ele = ele
        self.hr = hr


def _parse_time(text):
    text = text.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    d = datetime.fromisoformat(text)
    if d.tzinfo is None:
        d = d.replace(tzinfo=timezone.utc)
    return d.timestamp()


def _num(elem):
    if elem is None or elem.text is None or not elem.text.strip():
        return None
    return float(elem.text)


def trkpt_lines(path):
    """1-based line numbers of every '<trkpt ' in the file, in order."""
    lines = []
    with open(path, encoding="utf-8") as f:
        for no, line in enumerate(f, 1):
            if "<trkpt " in line:
                lines.append(no)
    return lines


def parse_gpx(path):
    root = ET.parse(path).getroot()
    lines = trkpt_lines(path)
    points = []
    for i, tp in enumerate(root.iterfind(".//gpx:trkpt", GPX_NS)):
        time_el = tp.find("gpx:time", GPX_NS)
        if time_el is None or not (time_el.text or "").strip():
            continue
        hr = _num(tp.find("gpx:extensions/tpx:TrackPointExtension/tpx:hr", GPX_NS))
        points.append(GpxPoint(
            index=i,
            line=lines[i] if i < len(lines) else None,
            t=_parse_time(time_el.text),
            lat=float(tp.get("lat")),
            lon=float(tp.get("lon")),
            ele=_num(tp.find("gpx:ele", GPX_NS)),
            hr=None if hr is None else int(round(hr)),
        ))
    return points


# --------------------------------------------------------------------------
# Series


def cumulative_distance(points):
    out = [0.0]
    for a, b in zip(points, points[1:]):
        out.append(out[-1] + aa.haversine_m(a.lat, a.lon, b.lat, b.lon))
    return out


def raw_gain_series(alts):
    """Cumulative sum of the positive steps (None values are bridged)."""
    out = []
    gain = 0.0
    prev = None
    for a in alts:
        if a is not None:
            if prev is not None and a > prev:
                gain += a - prev
            prev = a
        out.append(gain)
    return out


def gain_series(alts, threshold):
    """Cumulative version of analyze_activity.elevation_gain_m: the value at
    point i is elevation_gain_m(alts[:i + 1], threshold)."""
    out = []
    gain = 0.0
    climbing = False
    ref = None
    for a in alts:
        if a is not None:
            if ref is None:
                ref = a
            elif climbing:
                if a > ref:
                    gain += a - ref
                    ref = a
                elif ref - a > threshold:
                    climbing = False
                    ref = a
            else:
                if a < ref:
                    ref = a
                elif a - ref > threshold:
                    gain += a - ref
                    climbing = True
                    ref = a
        out.append(gain)
    return out


def last_index_at_or_before(times, t):
    """Largest i with times[i] <= t (times sorted), or None."""
    lo, hi = 0, len(times)
    while lo < hi:
        mid = (lo + hi) // 2
        if times[mid] <= t:
            lo = mid + 1
        else:
            hi = mid
    return lo - 1 if lo > 0 else None


def interpolate(times, values, t):
    """Linear interpolation of values (no None) at t, clamped at the ends."""
    i = last_index_at_or_before(times, t)
    if i is None:
        return values[0]
    if i >= len(times) - 1 or times[i] == t:
        return values[i]
    t0, t1 = times[i], times[i + 1]
    return values[i] + (values[i + 1] - values[i]) * (t - t0) / (t1 - t0)


def regression_slope(ts, ys):
    """(slope, r2) of the least-squares line of ys against ts."""
    n = len(ts)
    mt = sum(ts) / n
    my = sum(ys) / n
    sxx = sum((t - mt) ** 2 for t in ts)
    if sxx <= 0:
        return None, None
    sxy = sum((t - mt) * (y - my) for t, y in zip(ts, ys))
    syy = sum((y - my) ** 2 for y in ys)
    slope = sxy / sxx
    r2 = (sxy * sxy) / (sxx * syy) if syy > 0 else 1.0
    return slope, r2


# --------------------------------------------------------------------------
# HikeHistory.mc replay (same rules, in double precision; the watch uses
# 32-bit Float, so compare with a tolerance).


class HikeHistoryReplay:
    def __init__(self):
        self.samples = []  # (t_ms, alt, dist)
        self.last_time = None

    def reset(self):
        self.samples = []
        self.last_time = None

    def add(self, t_ms, alt, dist):
        """Returns True when the sample is kept."""
        if t_ms is None or alt is None:
            return False
        if self.last_time is not None:
            dt = t_ms - self.last_time
            if dt < 0 or dt > HH_MAX_GAP_MS:
                self.reset()
            elif dt < HH_MIN_SPACING_MS:
                return False
        self.samples.append((t_ms, float(alt), None if dist is None else float(dist)))
        if len(self.samples) > HH_MAX_SAMPLES:
            self.samples.pop(0)
        self.last_time = t_ms
        return True

    def vertical_speed_mh(self, now_ms, window_ms=HH_WINDOW_MS):
        w = [s for s in self.samples if now_ms - s[0] <= window_ms]
        if len(w) < HH_MIN_POINTS or w[-1][0] - w[0][0] < HH_MIN_COVERAGE_MS:
            return None
        slope, _ = regression_slope([(s[0] - now_ms) / 1000.0 for s in w], [s[1] for s in w])
        return None if slope is None else slope * 3600.0

    def speed_mps(self, now_ms, window_ms=HH_WINDOW_MS):
        w = [s for s in self.samples if s[2] is not None and now_ms - s[0] <= window_ms]
        if len(w) < HH_MIN_POINTS or w[-1][0] - w[0][0] < HH_MIN_COVERAGE_MS or w[-1][2] < w[0][2]:
            return None
        return (w[-1][2] - w[0][2]) / ((w[-1][0] - w[0][0]) / 1000.0)


# --------------------------------------------------------------------------
# Display rules of the hike pages (source/Utils.mc).


def _finite(v):
    return v is not None and not math.isnan(v) and not math.isinf(v)


def fmt_altitude(v):  # formatHikeAltitude, Utils.mc:36
    if not _finite(v) or v < -100.0 or v > 6000.0:
        return "--"
    return str(int(math.floor(v + 0.5)))  # Math.round: halves up


def fmt_ascent(v):  # formatHikeAscent, Utils.mc:168
    if not _finite(v) or v < 0.0 or v > 20000.0:
        return "--"
    return str(int(v + 0.5))


def fmt_distance_km(v):  # formatDistanceKm, Utils.mc:270
    if not _finite(v) or v < 0.0:
        return "--"
    if v == 0.0:
        return "0.0"
    return "%.1f" % (v / 1000.0)


def fmt_heart_rate(v):  # formatHeartRate, Utils.mc:192
    if not _finite(v) or v < 25.0 or v > 250.0:
        return "--"
    return str(int(math.floor(v + 0.5)))


def fmt_vertical_speed(v):  # formatVerticalSpeed, Utils.mc:304
    if not _finite(v):
        return "--"
    mag = abs(v)
    if mag > 3000.0:
        return "--"
    tens = int(mag / 10.0 + 0.5)
    if tens == 0:
        return "0"
    return ("-" if v < 0 else "+") + str(tens * 10)


def fmt_pace(v):  # formatPace, Utils.mc:538
    if not _finite(v) or v <= 0.0:
        return "--:--"
    pace = 1000.0 / v
    if pace >= 3600.5:
        return "--:--"
    total = int(pace + 0.5)
    if total <= 0:
        return "--:--"
    return "%d:%02d" % (total // 60, total % 60)


# --------------------------------------------------------------------------
# Hike lap model


class HikeLap:
    """GPX points of one TCX lap, with the TCX recorded distance matched by
    time, and the cumulative series."""

    def __init__(self, gpx_points, tcx_lap, t_end):
        self.t0 = aa._parse_time(tcx_lap.start)
        self.t_end = t_end
        self.tcx = [p for p in tcx_lap.points if p.dist is not None]
        self.tcx_t = [p.t for p in self.tcx]
        self.pts = [p for p in gpx_points if self.t0 <= p.t < t_end]
        self.times = [p.t for p in self.pts]
        alts = [p.ele for p in self.pts]
        self.dist_gps = cumulative_distance(self.pts)
        self.gain_raw = raw_gain_series(alts)
        self.gain_h1 = gain_series(alts, 1.0)
        self.gain_h3 = gain_series(alts, SMOOTH_THRESHOLD_M)
        apts = [aa.Point(t=p.t, lat=p.lat, lon=p.lon, alt=p.ele, hr=p.hr) for p in self.pts]
        self.vs60 = aa.vertical_speed_series(apts, "regression")
        self.tcx_speed60 = aa.speed_series(self.tcx)

    def tcx_dist_at(self, t):
        i = last_index_at_or_before(self.tcx_t, t)
        return None if i is None else self.tcx[i].dist

    def tcx_index_at(self, t):
        return last_index_at_or_before(self.tcx_t, t)

    def replay_1hz(self):
        """HikeHistory fed every second (as onSensor() does) with the TCX
        altitude and distance interpolated linearly. Returns a dict
        s -> (vs_mh, speed_mps) for the minute marks and the lap end."""
        tt = [p.t for p in self.tcx if p.alt is not None]
        alts = [p.alt for p in self.tcx if p.alt is not None]
        dists = [p.dist for p in self.tcx if p.alt is not None]
        span = int(self.t_end - self.t0)
        hh = HikeHistoryReplay()
        out = {}
        for s in range(0, span + 1):
            t = self.t0 + s
            hh.add(s * 1000, interpolate(tt, alts, t), interpolate(tt, dists, t))
            if s % 60 == 0 or s == span:
                out[s] = (hh.vertical_speed_mh(s * 1000), hh.speed_mps(s * 1000))
        return out


def iso(t):
    return datetime.fromtimestamp(t, tz=timezone.utc).strftime("%H:%M:%SZ")


def _c(v, spec="%.1f"):
    return "" if v is None else spec % v


MINUTE_COLUMNS = [
    "minute", "t_s", "heure_utc", "i_gpx", "ligne_gpx", "t_point_s",
    "altitude_m", "fc_bpm", "fc_moy_min_bpm",
    "dist_tcx_m", "dist_gps_m",
    "dplus_brut_m", "dplus_h1_m", "dplus_h3_m",
    "vs_min_mh", "vs60_reg_mh", "vs_app_1hz_mh",
    "pace_min_gps", "pace60_tcx", "pace_app_1hz",
    "aff_altitude", "aff_dplus_h3", "aff_distance", "aff_fc", "aff_vs", "aff_pace",
]


def minute_rows(lap):
    replay = lap.replay_1hz()
    rows = []
    span = int(lap.t_end - lap.t0)
    marks = list(range(0, span + 1, 60))
    if marks[-1] != span:
        marks.append(span)
    prev = None
    for s in marks:
        t = lap.t0 + s
        i = last_index_at_or_before(lap.times, t)
        p = lap.pts[i]
        in_min = [q.hr for q in lap.pts if t - 60 < q.t <= t and q.hr is not None]
        hr_mean = sum(in_min) / len(in_min) if in_min else None
        dist_tcx = lap.tcx_dist_at(t)
        j = lap.tcx_index_at(t)
        sp60 = lap.tcx_speed60[j] if j is not None else None
        vs_min = pace_min = None
        if prev is not None:
            pi = prev
            dt = lap.pts[i].t - lap.pts[pi].t
            if dt > 0:
                vs_min = (p.ele - lap.pts[pi].ele) / dt * 3600.0
                d = lap.dist_gps[i] - lap.dist_gps[pi]
                pace_min = fmt_pace(d / dt) if d > 0 else "--:--"
        vs_app, sp_app = replay.get(s, (None, None))
        rows.append({
            "minute": "%.2f" % (s / 60.0) if s % 60 else str(s // 60),
            "t_s": s,
            "heure_utc": iso(t),
            "i_gpx": p.index,
            "ligne_gpx": p.line,
            "t_point_s": "%.0f" % (p.t - lap.t0),
            "altitude_m": _c(p.ele),
            "fc_bpm": "" if p.hr is None else p.hr,
            "fc_moy_min_bpm": _c(hr_mean, "%.0f"),
            "dist_tcx_m": _c(dist_tcx, "%.1f"),
            "dist_gps_m": _c(lap.dist_gps[i], "%.1f"),
            "dplus_brut_m": _c(lap.gain_raw[i]),
            "dplus_h1_m": _c(lap.gain_h1[i]),
            "dplus_h3_m": _c(lap.gain_h3[i]),
            "vs_min_mh": _c(vs_min, "%.0f"),
            "vs60_reg_mh": _c(lap.vs60[i], "%.0f"),
            "vs_app_1hz_mh": _c(vs_app, "%.0f"),
            "pace_min_gps": "" if pace_min is None else pace_min,
            "pace60_tcx": "" if sp60 is None else fmt_pace(sp60),
            "pace_app_1hz": fmt_pace(sp_app),
            "aff_altitude": fmt_altitude(p.ele),
            "aff_dplus_h3": fmt_ascent(lap.gain_h3[i]),
            "aff_distance": fmt_distance_km(dist_tcx),
            "aff_fc": fmt_heart_rate(p.hr),
            "aff_vs": fmt_vertical_speed(vs_app),
            "aff_pace": fmt_pace(sp_app),
        })
        prev = i
    return rows


# --------------------------------------------------------------------------
# Extracts


class Window:
    def __init__(self, lap, a, n):
        self.a = a
        self.b = a + n - 1  # inclusive, indices in lap.pts
        pts = lap.pts[a:a + n]
        self.dt_max = max(q.t - p.t for p, q in zip(pts, pts[1:]))
        self.duration = pts[-1].t - pts[0].t
        slope, r2 = regression_slope([p.t - pts[0].t for p in pts], [p.ele for p in pts])
        self.slope_mh = None if slope is None else slope * 3600.0
        self.r2 = r2
        eles = [p.ele for p in pts]
        self.ele_range = max(eles) - min(eles)
        d0 = lap.tcx_dist_at(pts[0].t)
        d1 = lap.tcx_dist_at(pts[-1].t)
        self.speed = None if d0 is None or d1 is None or self.duration <= 0 else (d1 - d0) / self.duration
        self.hr_ok = all(p.hr is not None for p in pts)

    def overlaps(self, other):
        return not (self.b < other.a or other.b < self.a)


def pick_extracts(lap, n):
    """Picks, among the windows of n consecutive points of the lap with no
    gap > 15 s (HikeHistory reset), heart rate on every point and at least
    60 s covered, in this order and without overlap:
      - montee-raide: steepest regression slope with R2 >= 0.95 (<= 3000 m/h);
      - montee-reguliere: slope 500..700 m/h, moving (> 0.2 m/s), best R2
        then closest to 600 m/h;
      - replat: elevation range <= 2 m while walking (>= 0.4 m/s), fastest;
        relaxed to <= 3 m and >= 0.3 m/s, then to the smallest range at
        >= 0.3 m/s if nothing fits."""
    wins = []
    for a in range(0, len(lap.pts) - n + 1):
        w = Window(lap, a, n)
        if w.dt_max <= HH_MAX_GAP_MS / 1000.0 and w.hr_ok and w.duration >= 60 and w.slope_mh is not None:
            wins.append(w)
    chosen = {}

    def best(key, cond, score):
        cands = [w for w in wins if cond(w) and not any(w.overlaps(c) for c in chosen.values())]
        if cands:
            chosen[key] = max(cands, key=score)

    best("montee-raide", lambda w: w.r2 >= 0.95 and w.slope_mh <= 3000.0, lambda w: w.slope_mh)
    best("montee-reguliere", lambda w: 500.0 <= w.slope_mh <= 700.0 and (w.speed or 0) > 0.2,
         lambda w: (w.r2, -abs(w.slope_mh - 600.0)))
    best("replat", lambda w: w.ele_range <= 2.0 and (w.speed or 0) >= 0.4,
         lambda w: (w.speed, -w.ele_range))
    if "replat" not in chosen:
        best("replat", lambda w: w.ele_range <= 3.0 and (w.speed or 0) >= 0.3,
             lambda w: (w.speed, -w.ele_range))
    if "replat" not in chosen:
        best("replat", lambda w: (w.speed or 0) >= 0.3, lambda w: -w.ele_range)
    return chosen


EXTRACT_COLUMNS = [
    "i_gpx", "ligne_gpx", "t_s", "t_tour_s", "heure_utc", "lat", "lon", "ele", "hr",
    "dist_m", "hh_garde", "dplus_brut_m", "dplus_h1_m",
    "hh_vs_mh", "hh_vitesse_mps", "aff_altitude", "aff_fc", "aff_vs", "aff_pace",
]


def extract_rows(lap, w):
    pts = lap.pts[w.a:w.b + 1]
    t_first = pts[0].t
    d_first = lap.tcx_dist_at(t_first)
    alts = [p.ele for p in pts]
    raw = raw_gain_series(alts)
    h1 = gain_series(alts, 1.0)
    hh = HikeHistoryReplay()
    rows = []
    for k, p in enumerate(pts):
        t_ms = int(round((p.t - t_first) * 1000))
        d = lap.tcx_dist_at(p.t)
        dist = None if d is None or d_first is None else d - d_first
        kept = hh.add(t_ms, p.ele, dist)
        vs = hh.vertical_speed_mh(t_ms)
        sp = hh.speed_mps(t_ms)
        rows.append({
            "i_gpx": p.index,
            "ligne_gpx": p.line,
            "t_s": "%.0f" % (p.t - t_first),
            "t_tour_s": "%.0f" % (p.t - lap.t0),
            "heure_utc": iso(p.t),
            "lat": "%.6f" % p.lat,
            "lon": "%.6f" % p.lon,
            "ele": "%.1f" % p.ele,
            "hr": p.hr,
            "dist_m": _c(dist, "%.2f"),
            "hh_garde": 1 if kept else 0,
            "dplus_brut_m": "%.1f" % raw[k],
            "dplus_h1_m": "%.1f" % h1[k],
            "hh_vs_mh": _c(vs, "%.1f"),
            "hh_vitesse_mps": _c(sp, "%.4f"),
            "aff_altitude": fmt_altitude(p.ele),
            "aff_fc": fmt_heart_rate(p.hr),
            "aff_vs": fmt_vertical_speed(vs),
            "aff_pace": fmt_pace(sp),
        })
    return rows


# --------------------------------------------------------------------------
# Simulator log


SIM_RE = re.compile(r"^DIAG t=(\d+) pos\.alt=(\S+) acc=(\S+) ll=\[(\S+), (\S+)\].*act\.hr=(\S+) "
                    r"act\.dist=(\S+).*sen\.hr=(\S+)")


def sim_log_report(path, gpx_points):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = SIM_RE.match(line)
            if m:
                rows.append(m.groups())
    if not rows:
        return ["journal simulateur : aucune ligne DIAG reconnue"]
    acc = {}
    hr_null = sum(1 for r in rows if r[5] == "null" and r[7] == "null")
    pairs = []
    nearest_d = []
    seen = set()
    for r in rows:
        key = (r[3], r[4], r[1])
        if key in seen:
            continue
        seen.add(key)
        lat, lon, alt = float(r[3]), float(r[4]), float(r[1])
        best = min(gpx_points, key=lambda p: (p.lat - lat) ** 2 + ((p.lon - lon) * 0.69) ** 2)
        nearest_d.append(aa.haversine_m(lat, lon, best.lat, best.lon))
        pairs.append((best.ele, alt))
    for r in rows:
        acc[r[2]] = acc.get(r[2], 0) + 1
    slope, r2 = regression_slope([p[0] for p in pairs], [p[1] for p in pairs])
    mx = sum(p[0] for p in pairs) / len(pairs)
    my = sum(p[1] for p in pairs) / len(pairs)
    out = [
        "journal simulateur : %d lignes DIAG, accuracy %s, FC null (activite et capteur) sur %d lignes"
        % (len(rows), ", ".join("%s x%d" % kv for kv in sorted(acc.items())), hr_null),
        "  couples distincts (position, altitude) : %d ; distance au point GPX le plus proche : mediane %.1f m, max %.1f m"
        % (len(pairs), aa.percentile(nearest_d, 50), max(nearest_d)),
        "  altitude recue : %.1f .. %.1f m ; altitude GPX au point le plus proche : %.1f .. %.1f m"
        % (min(p[1] for p in pairs), max(p[1] for p in pairs), min(p[0] for p in pairs), max(p[0] for p in pairs)),
        "  regression alt_sim = a x ele_gpx + b : a = %.4f, b = %.1f m, R2 = %.4f"
        % (slope, my - slope * mx, r2),
    ]
    return out


# --------------------------------------------------------------------------
# Report


_TCX_HR = {}


def read_tcx_lap_hr(path):
    """Average / maximum heart rate of each lap (not read by analyze_activity)."""
    ns = {"tcx": aa.NS["tcx"]}
    root = ET.parse(path).getroot()
    for lap in root.iter("{%s}Lap" % aa.NS["tcx"]):
        avg = lap.find("tcx:AverageHeartRateBpm/tcx:Value", ns)
        mx = lap.find("tcx:MaximumHeartRateBpm/tcx:Value", ns)
        _TCX_HR[(lap.get("StartTime"), "avg")] = None if avg is None else avg.text
        _TCX_HR[(lap.get("StartTime"), "max")] = None if mx is None else mx.text


def totals_report(lap, tcx_lap):
    pts = lap.pts
    hrs = [p.hr for p in pts if p.hr is not None]
    # Time-weighted HR (each point holds until the next one).
    tw = sum(p.hr * (q.t - p.t) for p, q in zip(pts, pts[1:]) if p.hr is not None)
    tw_d = sum(q.t - p.t for p, q in zip(pts, pts[1:]) if p.hr is not None)
    speeds = [p.speed for p in tcx_lap.points if p.speed is not None]
    tcx_d = [p.dist for p in tcx_lap.points if p.dist is not None]
    elev = [p.ele for p in pts]
    if hrs:
        hr_line = (
            "  FC : moyenne des points %.1f, moyenne ponderee par le temps %.1f, max %d bpm (TCX : moyenne %s, max %s) ; min %d"
            % (sum(hrs) / len(hrs), tw / tw_d if tw_d else float("nan"), max(hrs),
               _TCX_HR.get((tcx_lap.start, "avg"), "?"), _TCX_HR.get((tcx_lap.start, "max"), "?"), min(hrs)))
    else:
        hr_line = "  FC : aucune (trace sans frequence cardiaque)"
    return [
        "Tour %s : %d points GPX (index %d..%d, lignes %s..%s), %s -> %s"
        % (tcx_lap.start, len(pts), pts[0].index, pts[-1].index, pts[0].line, pts[-1].line,
           iso(pts[0].t), iso(pts[-1].t)),
        "  intervalle moyen %.2f s, max %.0f s, intervalles > 15 s : %d"
        % ((pts[-1].t - pts[0].t) / (len(pts) - 1),
           max(q.t - p.t for p, q in zip(pts, pts[1:])),
           sum(1 for p, q in zip(pts, pts[1:]) if q.t - p.t > 15)),
        "  duree : TCX TotalTimeSeconds %.3f s ; etendue des points %.0f s"
        % (tcx_lap.total_time_s, pts[-1].t - pts[0].t),
        "  distance : TCX lap %.2f m ; TCX dernier-premier point %.2f m ; GPS (haversine GPX) %.1f m (%+.2f %%)"
        % (tcx_lap.distance_m, tcx_d[-1] - tcx_d[0], lap.dist_gps[-1],
           100.0 * (lap.dist_gps[-1] - tcx_lap.distance_m) / tcx_lap.distance_m),
        "  altitude GPX : min %.1f, max %.1f, debut %.1f, fin %.1f m (fin - debut %+.1f m)"
        % (min(elev), max(elev), elev[0], elev[-1], elev[-1] - elev[0]),
        "  D+ : brut %.1f m ; hysteresis 1 m %.1f m ; hysteresis 3 m %.1f m ; hysteresis 5 m %.1f m (aucun total dans le TCX)"
        % (lap.gain_raw[-1], lap.gain_h1[-1], lap.gain_h3[-1], gain_series(elev, 5.0)[-1]),
        hr_line,
        "  vitesse : max du champ Speed %.3f m/s ; moyenne distance/duree %.4f m/s"
        % (max(speeds), tcx_lap.distance_m / tcx_lap.total_time_s),
    ]


def at_report(lap, s):
    t = lap.t0 + s
    i = last_index_at_or_before(lap.times, t)
    p = lap.pts[i]
    d = lap.tcx_dist_at(t)
    return ("  t = %d s (%s) : point GPX %d (ligne %s, t=%.0f s), alt %.1f m, distance TCX %s m, "
            "distance GPS %.1f m, D+ brut %.1f, h1 %.1f, h3 %.1f m, FC %s"
            % (s, iso(t), p.index, p.line, p.t - lap.t0, p.ele, _c(d), lap.dist_gps[i],
               lap.gain_raw[i], lap.gain_h1[i], lap.gain_h3[i], p.hr))


def write_csv(path, columns, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=columns, lineterminator="\n")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Reference table and test extracts of a hike lap.")
    ap.add_argument("gpx")
    ap.add_argument("tcx")
    ap.add_argument("--lap", type=int, default=1, help="TCX lap of the hike (1-based, default 1)")
    ap.add_argument("--minutes-csv")
    ap.add_argument("--extracts-prefix", help="writes PREFIX-<kind>.csv for the three extracts")
    ap.add_argument("--extract-points", type=int, default=40)
    ap.add_argument("--sim-log")
    ap.add_argument("--at", type=int, action="append", default=[])
    args = ap.parse_args(argv)

    gpx = parse_gpx(args.gpx)
    laps = aa.parse_tcx(args.tcx)
    read_tcx_lap_hr(args.tcx)
    tcx_all = [p for lap in laps for p in lap.points]
    print("GPX : %d points, %s -> %s, intervalle moyen %.2f s ; ele %.1f..%.1f m ; FC sur %d points"
          % (len(gpx), iso(gpx[0].t), iso(gpx[-1].t), (gpx[-1].t - gpx[0].t) / (len(gpx) - 1),
             min(p.ele for p in gpx), max(p.ele for p in gpx), sum(1 for p in gpx if p.hr is not None)))
    print("TCX : %d tours, %d points (%s)" % (len(laps), len(tcx_all),
                                              ", ".join(str(len(l.points)) for l in laps)))
    # GPX / TCX consistency, matched by time.
    tcx_by_t = {}
    for p in tcx_all:
        tcx_by_t.setdefault(p.t, []).append(p)
    dup = [t for t, v in tcx_by_t.items() if len(v) > 1]
    diff_ele = diff_hr = missing = 0
    for p in gpx:
        q = tcx_by_t.get(p.t)
        if not q:
            missing += 1
            continue
        if q[0].alt != p.ele:
            diff_ele += 1
        if q[0].hr != p.hr:
            diff_hr += 1
    print("GPX vs TCX par horodatage : %d instants TCX en double (%s), %d points GPX sans point TCX, "
          "%d altitudes differentes, %d FC differentes"
          % (len(dup), ", ".join(iso(t) for t in dup), missing, diff_ele, diff_hr))

    k = args.lap - 1
    t_end = aa._parse_time(laps[k + 1].start) if k + 1 < len(laps) else gpx[-1].t + 1
    lap = HikeLap(gpx, laps[k], t_end)
    print()
    print("\n".join(totals_report(lap, laps[k])))
    for s in args.at:
        print(at_report(lap, s))

    if args.minutes_csv:
        rows = minute_rows(lap)
        write_csv(args.minutes_csv, MINUTE_COLUMNS, rows)
        print("\nTable minute par minute : %d lignes -> %s" % (len(rows), args.minutes_csv))

    if args.extracts_prefix:
        chosen = pick_extracts(lap, args.extract_points)
        print("\nExtraits (%d points chacun) :" % args.extract_points)
        for kind in ("montee-reguliere", "replat", "montee-raide"):
            w = chosen.get(kind)
            if w is None:
                print("  %s : aucune fenetre ne remplit les criteres" % kind)
                continue
            rows = extract_rows(lap, w)
            path = "%s-%s.csv" % (args.extracts_prefix, kind)
            write_csv(path, EXTRACT_COLUMNS, rows)
            a, b = lap.pts[w.a], lap.pts[w.b]
            last = rows[-1]
            print("  %s : GPX index %d..%d (lignes %s..%s), %s -> %s (tour +%.0f..+%.0f s), %.0f s, "
                  "pente %+.0f m/h (R2 %.3f), amplitude %.1f m, vitesse %.2f m/s, dt max %.0f s, "
                  "D+ brut %s m, h1 %s m, gardes HikeHistory %d, VS a la fin %s m/h, vitesse %s m/s -> %s"
                  % (kind, a.index, b.index, a.line, b.line, iso(a.t), iso(b.t), a.t - lap.t0, b.t - lap.t0,
                     w.duration, w.slope_mh, w.r2, w.ele_range, w.speed or 0.0, w.dt_max,
                     last["dplus_brut_m"], last["dplus_h1_m"], sum(r["hh_garde"] for r in rows),
                     last["hh_vs_mh"], last["hh_vitesse_mps"], path))

    if args.sim_log:
        print()
        print("\n".join(sim_log_report(args.sim_log, gpx)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
