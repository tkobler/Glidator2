"""Tests for tools/analyze_activity.py (Python 3 stdlib only).

Run from the repository root:
    python3 -m unittest tools/test_analyze_activity.py
or  python3 tools/test_analyze_activity.py
"""

import io
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import analyze_activity as aa  # noqa: E402

SALVAN_TCX = os.path.join(HERE, "..", "garmin_data", "activity_24346302742.tcx")

T0 = 1789294723.0  # 2026-09-13T10:18:43Z


def _iso(t):
    import datetime as _dt
    d = _dt.datetime.fromtimestamp(t, tz=_dt.timezone.utc)
    return d.strftime("%Y-%m-%dT%H:%M:%S.000Z")


def make_tcx(laps):
    """Builds a small TCX string. laps: list of dicts with keys
    'points' (list of dicts: t, lat, lon, alt, dist, hr, speed -- any may be
    missing or None), and optional 'total_time' and 'distance'."""
    out = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<TrainingCenterDatabase'
        ' xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2"'
        ' xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">',
        '<Activities><Activity Sport="Other"><Id>x</Id>',
    ]
    for lap in laps:
        pts = lap.get("points", [])
        start = pts[0]["t"] if pts else T0
        out.append('<Lap StartTime="%s">' % _iso(start))
        if lap.get("total_time") is not None:
            out.append("<TotalTimeSeconds>%s</TotalTimeSeconds>" % lap["total_time"])
        if lap.get("distance") is not None:
            out.append("<DistanceMeters>%s</DistanceMeters>" % lap["distance"])
        if lap.get("no_track"):
            out.append("</Lap>")
            continue
        out.append("<Track>")
        for p in pts:
            out.append("<Trackpoint><Time>%s</Time>" % _iso(p["t"]))
            if p.get("lat") is not None and p.get("lon") is not None:
                out.append(
                    "<Position><LatitudeDegrees>%r</LatitudeDegrees>"
                    "<LongitudeDegrees>%r</LongitudeDegrees></Position>" % (p["lat"], p["lon"])
                )
            if p.get("alt") is not None:
                out.append("<AltitudeMeters>%r</AltitudeMeters>" % p["alt"])
            if p.get("dist") is not None:
                out.append("<DistanceMeters>%r</DistanceMeters>" % p["dist"])
            if p.get("hr") is not None:
                out.append("<HeartRateBpm><Value>%d</Value></HeartRateBpm>" % p["hr"])
            if p.get("speed") is not None:
                out.append(
                    "<Extensions><ns3:TPX><ns3:Speed>%r</ns3:Speed></ns3:TPX></Extensions>" % p["speed"]
                )
            out.append("</Trackpoint>")
        out.append("</Track></Lap>")
    out.append("</Activity></Activities></TrainingCenterDatabase>")
    return "\n".join(out)


# 1 degree of latitude ~ 111 195 m (mean Earth radius 6 371 008.8 m).
M_PER_DEG_LAT = 6371008.8 * 3.141592653589793 / 180.0


def climb_points(duration_s=600, step_s=1, rate_mh=600.0, quantum=0.2, speed=0.0,
                 horizontal_mps=0.5, steps=None):
    """Steady climb, altitude quantised like the barometer (0.2 m)."""
    pts = []
    t = 0.0
    i = 0
    while t <= duration_s:
        alt = 1500.0 + rate_mh * t / 3600.0
        if quantum:
            alt = round(alt / quantum) * quantum
        pts.append({
            "t": T0 + t,
            "lat": 46.0 + horizontal_mps * t / M_PER_DEG_LAT,
            "lon": 7.0,
            "alt": alt,
            "dist": horizontal_mps * t,
            "hr": 120 + (i % 10),
            "speed": speed,
        })
        t += steps[i % len(steps)] if steps else step_s
        i += 1
    return pts


class ParseTest(unittest.TestCase):
    def test_parses_laps_points_and_fields(self):
        pts = [
            {"t": T0, "lat": 46.0, "lon": 7.0, "alt": 1815.0, "dist": 1.5, "hr": 83, "speed": 1.2},
            {"t": T0 + 4, "lat": 46.0001, "lon": 7.0, "alt": 1815.2, "dist": 8.0, "hr": 86, "speed": 0.0},
        ]
        laps = aa.parse_tcx_string(make_tcx([
            {"points": pts, "total_time": 4.5, "distance": 8.0},
            {"points": [dict(pts[1], t=T0 + 100)], "total_time": 1.0, "distance": 0.0},
        ]))
        self.assertEqual(len(laps), 2)
        lap = laps[0]
        self.assertEqual(lap.start, "2026-09-13T10:18:43.000Z")
        self.assertAlmostEqual(lap.total_time_s, 4.5)
        self.assertAlmostEqual(lap.distance_m, 8.0)
        self.assertEqual(len(lap.points), 2)
        p = lap.points[1]
        self.assertAlmostEqual(p.t - lap.points[0].t, 4.0)
        self.assertAlmostEqual(p.lat, 46.0001)
        self.assertAlmostEqual(p.lon, 7.0)
        self.assertAlmostEqual(p.alt, 1815.2)
        self.assertAlmostEqual(p.dist, 8.0)
        self.assertEqual(p.hr, 86)
        self.assertEqual(p.speed, 0.0)

    def test_missing_fields_are_none(self):
        laps = aa.parse_tcx_string(make_tcx([{"points": [{"t": T0}]}]))
        p = laps[0].points[0]
        self.assertIsNone(p.lat)
        self.assertIsNone(p.lon)
        self.assertIsNone(p.alt)
        self.assertIsNone(p.dist)
        self.assertIsNone(p.hr)
        self.assertIsNone(p.speed)
        self.assertIsNone(laps[0].total_time_s)
        self.assertIsNone(laps[0].distance_m)

    def test_lap_without_track(self):
        laps = aa.parse_tcx_string(make_tcx([{"no_track": True, "total_time": 10}]))
        self.assertEqual(len(laps), 1)
        self.assertEqual(laps[0].points, [])

    def test_no_lap(self):
        self.assertEqual(aa.parse_tcx_string(make_tcx([])), [])

    def test_trackpoint_without_time_is_skipped(self):
        text = make_tcx([{"points": [{"t": T0, "alt": 1.0}, {"t": T0 + 1, "alt": 2.0}]}])
        text = text.replace("<Time>%s</Time>" % _iso(T0 + 1), "", 1)
        laps = aa.parse_tcx_string(text)
        self.assertEqual(len(laps[0].points), 1)

    def test_parse_file(self):
        with tempfile.NamedTemporaryFile("w", suffix=".tcx", delete=False) as f:
            f.write(make_tcx([{"points": climb_points(10)}]))
            path = f.name
        try:
            laps = aa.parse_tcx(path)
            self.assertEqual(len(laps[0].points), 11)
        finally:
            os.unlink(path)


class HaversineAndDistanceTest(unittest.TestCase):
    def test_zero(self):
        self.assertEqual(aa.haversine_m(46.0, 7.0, 46.0, 7.0), 0.0)

    def test_one_degree_latitude(self):
        self.assertAlmostEqual(aa.haversine_m(46.0, 7.0, 47.0, 7.0), M_PER_DEG_LAT, delta=0.01)

    def test_gps_distance_sums_segments(self):
        pts = aa.parse_tcx_string(make_tcx([{"points": climb_points(100, horizontal_mps=1.0)}]))[0].points
        self.assertAlmostEqual(aa.gps_distance_m(pts), 100.0, delta=0.01)

    def test_gps_distance_skips_points_without_position(self):
        raw = climb_points(100, horizontal_mps=1.0)
        for p in raw[10:20]:
            p["lat"] = None
        pts = aa.parse_tcx_string(make_tcx([{"points": raw}]))[0].points
        # The segment over the hole is still counted (straight line).
        self.assertAlmostEqual(aa.gps_distance_m(pts), 100.0, delta=0.01)

    def test_gps_distance_none_without_positions(self):
        raw = climb_points(10)
        for p in raw:
            p["lat"] = None
        pts = aa.parse_tcx_string(make_tcx([{"points": raw}]))[0].points
        self.assertIsNone(aa.gps_distance_m(pts))

    def test_gps_distance_single_point(self):
        pts = aa.parse_tcx_string(make_tcx([{"points": climb_points(0)}]))[0].points
        self.assertEqual(aa.gps_distance_m(pts), 0.0)


class ElevationGainTest(unittest.TestCase):
    """Symmetric hysteresis: the reference follows the running maximum while
    climbing and the running minimum while descending; the direction flips
    when the altitude moves strictly more than `threshold` away from the
    reference. Expected values below are computed by hand (threshold 1 m
    unless stated)."""

    def test_steady_climb(self):
        alts = [1500.0 + 0.2 * i for i in range(51)]  # +10 m
        self.assertAlmostEqual(aa.elevation_gain_m(alts), 10.0, delta=1.0)

    def test_noise_below_threshold_is_ignored(self):
        alts = [1500.0, 1500.4, 1499.8, 1500.6, 1500.0, 1500.8, 1500.2] * 20
        self.assertEqual(aa.elevation_gain_m(alts), 0.0)

    def test_noise_counted_with_lower_threshold(self):
        alts = [1500.0, 1500.6, 1500.0, 1500.6, 1500.0]
        self.assertAlmostEqual(aa.elevation_gain_m(alts, threshold=0.5), 1.2, places=6)
        self.assertEqual(aa.elevation_gain_m(alts, threshold=1.0), 0.0)

    def test_exactly_threshold_does_not_count(self):
        # Strict comparison on both sides (was `>=` going up before the
        # symmetric version): a rise of exactly the threshold is noise.
        self.assertEqual(aa.elevation_gain_m([1500.0, 1501.0]), 0.0)

    def test_just_above_threshold_counts(self):
        self.assertAlmostEqual(aa.elevation_gain_m([1500.0, 1501.5]), 1.5)

    def test_rising_ramp_0_to_100(self):
        # 0 -> 1: not > 1, 2: +2 (now climbing), then +1 per step -> 100.
        self.assertAlmostEqual(aa.elevation_gain_m([float(i) for i in range(101)]), 100.0)

    def test_falling_ramp_100_to_0(self):
        self.assertEqual(aa.elevation_gain_m([float(i) for i in range(100, -1, -1)]), 0.0)

    def test_sawtooth_amplitude_below_threshold(self):
        self.assertEqual(aa.elevation_gain_m([0.0, 0.5] * 50), 0.0)

    def test_sawtooth_amplitude_equal_to_threshold(self):
        self.assertEqual(aa.elevation_gain_m([0.0, 1.0] * 50), 0.0)

    def test_sawtooth_amplitude_above_threshold(self):
        # Three rises of 3 m.
        self.assertAlmostEqual(aa.elevation_gain_m([0.0, 3.0, 0.0, 3.0, 0.0, 3.0, 0.0]), 9.0)

    def test_reference_follows_minimum_on_descent(self):
        # Descent in 0.6 m steps down to 97.0, then back up to 100.0: the
        # climb is counted from the true low point, 3.0 m (the asymmetric
        # version left the reference at 97.6 and counted 2.4 m).
        alts = [100.0, 99.4, 98.8, 98.2, 97.6, 97.0, 100.0]
        self.assertAlmostEqual(aa.elevation_gain_m(alts), 3.0)

    def test_reference_follows_maximum_on_climb(self):
        # +2 confirms the climb, then the extra 0.5 m is counted (the
        # asymmetric version needed another full threshold: 2.0 m).
        self.assertAlmostEqual(aa.elevation_gain_m([0.0, 2.0, 2.5]), 2.5)

    def test_noisy_climb(self):
        # 1.2 confirms the climb (+1.2); dips of 0.2 m do not flip it; new
        # maxima 1.8, 2.4, 3.0 add 0.6 each -> 3.0 = max - min.
        alts = [0.0, 0.6, 1.2, 1.0, 1.8, 2.4, 2.2, 3.0]
        self.assertAlmostEqual(aa.elevation_gain_m(alts), 3.0)

    def test_noisy_plateau_after_climb(self):
        # +10, then noise of +-0.4 m: only the new maximum 10.4 adds 0.4.
        alts = [0.0, 10.0, 9.6, 10.4, 9.8, 10.2, 9.7]
        self.assertAlmostEqual(aa.elevation_gain_m(alts), 10.4)

    def test_descent_then_climb(self):
        # 50 -> 30 (descent), +1.5 (climb), -2 (descent to 29.5), +15.5.
        alts = [50.0, 40.0, 30.0, 31.5, 29.5, 45.0]
        self.assertAlmostEqual(aa.elevation_gain_m(alts), 17.0)

    def test_threshold_is_a_parameter(self):
        alts = [0.0, 3.0, 0.0, 3.0, 0.0]
        self.assertEqual(aa.elevation_gain_m(alts, threshold=5.0), 0.0)
        self.assertAlmostEqual(aa.elevation_gain_m(alts, threshold=2.0), 6.0)
        self.assertEqual(aa.elevation_gain_m(alts, threshold=3.0), 0.0)

    def test_zero_threshold_sums_every_rise(self):
        self.assertAlmostEqual(aa.elevation_gain_m([0.0, 1.0, 0.5, 2.0], threshold=0.0), 2.5)

    def test_negative_threshold_rejected(self):
        with self.assertRaises(ValueError):
            aa.elevation_gain_m([0.0, 1.0], threshold=-1.0)

    def test_climb_descent_climb(self):
        alts = [100.0, 110.0, 105.0, 120.0]
        self.assertAlmostEqual(aa.elevation_gain_m(alts), 25.0)

    def test_none_values_are_skipped(self):
        self.assertAlmostEqual(aa.elevation_gain_m([100.0, None, 102.0, None]), 2.0)

    def test_empty_and_single(self):
        self.assertIsNone(aa.elevation_gain_m([]))
        self.assertIsNone(aa.elevation_gain_m([None, None]))
        self.assertEqual(aa.elevation_gain_m([100.0]), 0.0)


class ZeroSpeedTest(unittest.TestCase):
    def test_counts_zero_speed(self):
        raw = climb_points(9, speed=1.0)
        for p in raw[:4]:
            p["speed"] = 0.0
        pts = aa.parse_tcx_string(make_tcx([{"points": raw}]))[0].points
        self.assertEqual(aa.zero_speed_count(pts), (4, 10))

    def test_missing_speed_not_in_denominator(self):
        raw = climb_points(9, speed=0.0)
        for p in raw[:3]:
            p["speed"] = None
        pts = aa.parse_tcx_string(make_tcx([{"points": raw}]))[0].points
        self.assertEqual(aa.zero_speed_count(pts), (7, 7))

    def test_no_points(self):
        self.assertEqual(aa.zero_speed_count([]), (0, 0))


class JumpTest(unittest.TestCase):
    def _pts(self, raw):
        return aa.parse_tcx_string(make_tcx([{"points": raw}]))[0].points

    def test_no_jump_on_clean_track(self):
        self.assertEqual(aa.detect_jumps(self._pts(climb_points(100))), [])

    def test_injected_jump_detected(self):
        raw = climb_points(100)
        for p in raw[50:]:
            p["lat"] += 500.0 / M_PER_DEG_LAT  # +500 m from point 50 on
        jumps = aa.detect_jumps(self._pts(raw))
        self.assertEqual(len(jumps), 1)
        j = jumps[0]
        self.assertEqual(j.index, 50)
        self.assertAlmostEqual(j.distance_m, 500.5, delta=0.5)
        self.assertAlmostEqual(j.dt_s, 1.0)

    def test_threshold_grows_with_dt(self):
        # 150 m in 2 s: limit 50 + 120 = 170 m -> not a jump.
        raw = [{"t": T0, "lat": 46.0, "lon": 7.0},
               {"t": T0 + 2, "lat": 46.0 + 150.0 / M_PER_DEG_LAT, "lon": 7.0}]
        self.assertEqual(aa.detect_jumps(self._pts(raw)), [])
        # Same 150 m in 1 s: limit 110 m -> jump.
        raw[1]["t"] = T0 + 1
        self.assertEqual(len(aa.detect_jumps(self._pts(raw))), 1)

    def test_strictly_greater_than_limit(self):
        self.assertFalse(aa.is_jump(110.0, 1.0))
        self.assertTrue(aa.is_jump(110.01, 1.0))
        self.assertTrue(aa.is_jump(50.01, 0.0))
        self.assertFalse(aa.is_jump(50.0, 0.0))

    def test_points_without_position_are_bridged(self):
        raw = climb_points(20)
        raw[5]["lat"] = None
        self.assertEqual(aa.detect_jumps(self._pts(raw)), [])

    def test_no_position_at_all(self):
        raw = climb_points(20)
        for p in raw:
            p["lat"] = None
        self.assertEqual(aa.detect_jumps(self._pts(raw)), [])


class PercentileTest(unittest.TestCase):
    def test_empty(self):
        self.assertIsNone(aa.percentile([], 50))

    def test_single(self):
        self.assertEqual(aa.percentile([3.0], 5), 3.0)
        self.assertEqual(aa.percentile([3.0], 95), 3.0)

    def test_linear_interpolation(self):
        v = [4.0, 1.0, 3.0, 2.0, 5.0]
        self.assertEqual(aa.percentile(v, 0), 1.0)
        self.assertEqual(aa.percentile(v, 50), 3.0)
        self.assertEqual(aa.percentile(v, 100), 5.0)
        self.assertAlmostEqual(aa.percentile(v, 5), 1.2)
        self.assertAlmostEqual(aa.percentile([1.0, 2.0], 50), 1.5)

    def test_ignores_none(self):
        self.assertEqual(aa.percentile([None, 2.0, None], 50), 2.0)


class VerticalSpeedTest(unittest.TestCase):
    def _pts(self, raw):
        return aa.parse_tcx_string(make_tcx([{"points": raw}]))[0].points

    def test_synthetic_600_mh_regression(self):
        vs = aa.vertical_speed_series(self._pts(climb_points(600)), method="regression")
        self.assertAlmostEqual(aa.percentile(vs, 50), 600.0, delta=5.0)

    def test_synthetic_600_mh_diff(self):
        vs = aa.vertical_speed_series(self._pts(climb_points(600)), method="diff")
        self.assertAlmostEqual(aa.percentile(vs, 50), 600.0, delta=5.0)

    def test_synthetic_600_mh_irregular_sampling(self):
        pts = self._pts(climb_points(1200, steps=[1, 3, 6, 2, 4, 5, 1, 2]))
        for method in ("regression", "diff"):
            vs = aa.vertical_speed_series(pts, method=method)
            self.assertAlmostEqual(aa.percentile(vs, 50), 600.0, delta=5.0, msg=method)

    def test_descent_is_negative(self):
        vs = aa.vertical_speed_series(self._pts(climb_points(600, rate_mh=-1200.0)))
        self.assertAlmostEqual(aa.percentile(vs, 50), -1200.0, delta=5.0)

    def test_flat_is_zero(self):
        vs = aa.vertical_speed_series(self._pts(climb_points(300, rate_mh=0.0)))
        self.assertEqual(aa.percentile(vs, 50), 0.0)

    def test_series_aligned_with_points_and_null_at_start(self):
        pts = self._pts(climb_points(100))
        vs = aa.vertical_speed_series(pts)
        self.assertEqual(len(vs), len(pts))
        # Less than 20 s covered at the start -> None.
        self.assertTrue(all(v is None for v in vs[:20]))
        self.assertIsNotNone(vs[20])

    def test_window_uses_only_last_60_s(self):
        # Flat for 300 s then 600 m/h: 60 s after the change, fully 600 m/h.
        raw = climb_points(300, rate_mh=0.0, quantum=None)
        for p in climb_points(300, quantum=None)[1:]:
            q = dict(p)
            q["t"] = p["t"] + 300
            q["alt"] = p["alt"]
            raw.append(q)
        pts = self._pts(raw)
        vs = aa.vertical_speed_series(pts, method="regression")
        self.assertAlmostEqual(vs[300], 0.0, delta=1e-6)
        self.assertAlmostEqual(vs[360], 600.0, delta=1e-6)
        self.assertAlmostEqual(vs[-1], 600.0, delta=1e-6)

    def test_non_linear_window_separates_regression_from_diff(self):
        # Hand computed: t = 0, 10, 20, 30 s, alt = 0, 0, 0, 3 m.
        # Regression: mean t 15, mean a 0.75, sxy = 45, sxx = 500,
        # slope 0.09 m/s = 324 m/h. Endpoints: 3 m / 30 s = 360 m/h.
        raw = [{"t": T0 + t, "alt": a} for t, a in ((0, 0.0), (10, 0.0), (20, 0.0), (30, 3.0))]
        pts = self._pts(raw)
        self.assertAlmostEqual(aa.vertical_speed_series(pts, method="regression")[-1], 324.0, places=6)
        self.assertAlmostEqual(aa.vertical_speed_series(pts, method="diff")[-1], 360.0, places=6)
        # The watch replay keeps all 4 samples (10 s apart) and regresses too.
        self.assertAlmostEqual(aa.watch_vertical_speed_series(pts)[-1], 324.0, places=6)

    def test_time_gap_longer_than_window(self):
        raw = climb_points(60)
        later = climb_points(60)
        for p in later:
            p["t"] += 600
        pts = self._pts(raw + later)
        vs = aa.vertical_speed_series(pts)
        # Just after the gap, only 1 point in the window -> None.
        self.assertIsNone(vs[61])
        self.assertIsNotNone(vs[-1])

    def test_altitude_missing(self):
        raw = climb_points(100)
        for p in raw:
            p["alt"] = None
        vs = aa.vertical_speed_series(self._pts(raw))
        self.assertTrue(all(v is None for v in vs))
        self.assertIsNone(aa.percentile(vs, 50))

    def test_some_altitudes_missing(self):
        raw = climb_points(600)
        for p in raw[::3]:
            p["alt"] = None
        vs = aa.vertical_speed_series(self._pts(raw))
        self.assertAlmostEqual(aa.percentile(vs, 50), 600.0, delta=5.0)

    def test_single_point_and_empty(self):
        self.assertEqual(aa.vertical_speed_series(self._pts(climb_points(0))), [None])
        self.assertEqual(aa.vertical_speed_series([]), [])

    def test_unknown_method(self):
        with self.assertRaises(ValueError):
            aa.vertical_speed_series(self._pts(climb_points(10)), method="magic")


class WatchMethodTest(unittest.TestCase):
    """Replays HikeHistory.mc: one sample every >= 5 s, reset on a gap > 15 s,
    regression over 60 s, None if < 3 samples or < 20 s covered."""

    def _pts(self, raw):
        return aa.parse_tcx_string(make_tcx([{"points": raw}]))[0].points

    def test_synthetic_600_mh(self):
        vs = aa.watch_vertical_speed_series(self._pts(climb_points(600)))
        self.assertAlmostEqual(aa.percentile(vs, 50), 600.0, delta=5.0)

    def test_sampling_every_5_s(self):
        pts = self._pts(climb_points(60))
        vs = aa.watch_vertical_speed_series(pts)
        self.assertEqual(len(vs), len(pts))
        accepted = [i for i, v in enumerate(vs) if v is not aa.NOT_SAMPLED]
        self.assertEqual(accepted, list(range(0, 61, 5)))
        # Samples at 0, 5, 10, 15: 15 s covered -> None; at 20 s -> value.
        self.assertIsNone(vs[15])
        self.assertIsNotNone(vs[20])

    def test_gap_over_15_s_resets(self):
        raw = climb_points(60)
        later = climb_points(60)
        for p in later:
            p["t"] += 76  # 16 s after the last point
        pts = self._pts(raw + later)
        vs = aa.watch_vertical_speed_series(pts)
        self.assertIsNone(vs[61])         # first sample after reset
        self.assertIsNone(vs[61 + 15])    # 15 s covered after reset
        self.assertIsNotNone(vs[61 + 20])

    def test_gap_of_exactly_15_s_does_not_reset(self):
        raw = climb_points(60)
        later = climb_points(60)
        for p in later:
            p["t"] += 75
        pts = self._pts(raw + later)
        vs = aa.watch_vertical_speed_series(pts)
        self.assertIsNotNone(vs[61])

    def test_altitude_missing_is_ignored(self):
        raw = climb_points(60)
        for p in raw:
            p["alt"] = None
        vs = aa.watch_vertical_speed_series(self._pts(raw))
        self.assertTrue(all(v is aa.NOT_SAMPLED for v in vs))

    def test_empty(self):
        self.assertEqual(aa.watch_vertical_speed_series([]), [])


class SpeedSeriesTest(unittest.TestCase):
    def _pts(self, raw):
        return aa.parse_tcx_string(make_tcx([{"points": raw}]))[0].points

    def test_constant_speed(self):
        sp = aa.speed_series(self._pts(climb_points(600, horizontal_mps=0.5)))
        self.assertAlmostEqual(aa.percentile(sp, 50), 0.5, places=6)
        self.assertIsNone(sp[0])

    def test_distance_missing(self):
        raw = climb_points(100)
        for p in raw:
            p["dist"] = None
        self.assertTrue(all(v is None for v in aa.speed_series(self._pts(raw))))

    def test_distance_going_down_gives_none(self):
        raw = climb_points(100)
        for p in raw[50:]:
            p["dist"] -= 100.0
        sp = aa.speed_series(self._pts(raw))
        self.assertIsNone(sp[60])

    def test_pace_formatting(self):
        self.assertEqual(aa.format_pace(1000.0 / 600.0), "10:00")
        self.assertEqual(aa.format_pace(0.5), "33:20")
        self.assertEqual(aa.format_pace(0.0), "-")
        self.assertEqual(aa.format_pace(None), "-")


class SummaryTest(unittest.TestCase):
    def test_summary_fields(self):
        raw = climb_points(600, speed=0.0)
        for p in raw[:100]:
            p["speed"] = 1.0
        lap = aa.parse_tcx_string(make_tcx([{"points": raw, "total_time": 600.5, "distance": 300.0}]))[0]
        s = aa.summarize_lap(lap)
        self.assertEqual(s["points"], 601)
        self.assertAlmostEqual(s["duration_s"], 600.5)
        self.assertAlmostEqual(s["span_s"], 600.0)
        self.assertAlmostEqual(s["mean_interval_s"], 1.0)
        self.assertAlmostEqual(s["recorded_distance_m"], 300.0)
        self.assertAlmostEqual(s["gps_distance_m"], 300.0, delta=0.1)
        self.assertAlmostEqual(s["elevation_gain_m"], 100.0, delta=1.0)
        self.assertEqual(s["zero_speed"], 501)
        self.assertEqual(s["with_speed"], 601)
        self.assertEqual(s["jumps"], [])
        self.assertAlmostEqual(s["vs_regression"]["median"], 600.0, delta=5.0)
        self.assertAlmostEqual(s["vs_diff"]["median"], 600.0, delta=5.0)
        self.assertAlmostEqual(s["vs_watch"]["median"], 600.0, delta=5.0)
        self.assertAlmostEqual(s["speed60_median_mps"], 0.5, places=6)
        self.assertEqual(s["hr_min"], 120)
        self.assertEqual(s["hr_max"], 129)

    def test_threshold_parameter(self):
        alts = [1500.0, 1500.6, 1500.0, 1500.6, 1500.0]
        raw = [{"t": T0 + i, "alt": a} for i, a in enumerate(alts)]
        lap = aa.parse_tcx_string(make_tcx([{"points": raw}]))[0]
        self.assertEqual(aa.summarize_lap(lap)["elevation_gain_m"], 0.0)
        self.assertAlmostEqual(aa.summarize_lap(lap, gain_threshold=0.5)["elevation_gain_m"], 1.2)

    def test_without_hr(self):
        raw = climb_points(30)
        for p in raw:
            p["hr"] = None
        lap = aa.parse_tcx_string(make_tcx([{"points": raw}]))[0]
        s = aa.summarize_lap(lap)
        self.assertIsNone(s["hr_min"])
        self.assertIsNone(s["hr_max"])
        self.assertIn("FC", aa.format_report([s]))

    def test_recorded_distance_fallback_to_points(self):
        lap = aa.parse_tcx_string(make_tcx([{"points": climb_points(100, horizontal_mps=1.0)}]))[0]
        self.assertAlmostEqual(aa.summarize_lap(lap)["recorded_distance_m"], 100.0)

    def test_single_point_lap(self):
        lap = aa.parse_tcx_string(make_tcx([{"points": climb_points(0)}]))[0]
        s = aa.summarize_lap(lap)
        self.assertEqual(s["points"], 1)
        self.assertEqual(s["span_s"], 0.0)
        self.assertIsNone(s["mean_interval_s"])
        self.assertIsNone(s["vs_regression"]["median"])
        self.assertIsNone(s["speed60_median_mps"])
        aa.format_report([s])  # must not raise

    def test_empty_lap(self):
        lap = aa.parse_tcx_string(make_tcx([{"no_track": True}]))[0]
        s = aa.summarize_lap(lap)
        self.assertEqual(s["points"], 0)
        self.assertIsNone(s["gps_distance_m"])
        self.assertIsNone(s["elevation_gain_m"])
        self.assertIsNone(s["hr_min"])
        aa.format_report([s])  # must not raise

    def test_lap_without_position(self):
        raw = climb_points(100)
        for p in raw:
            p["lat"] = None
        lap = aa.parse_tcx_string(make_tcx([{"points": raw}]))[0]
        s = aa.summarize_lap(lap)
        self.assertIsNone(s["gps_distance_m"])
        self.assertEqual(s["jumps"], [])
        self.assertIn("Lap 1", aa.format_report([s]))


class MainTest(unittest.TestCase):
    def setUp(self):
        raw = climb_points(120)
        raw[60]["lat"] += 1000.0 / M_PER_DEG_LAT
        self.tmp = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.tmp.name, "a.tcx")
        with open(self.path, "w") as f:
            f.write(make_tcx([{"points": raw, "total_time": 120}, {"points": climb_points(30)}]))

    def tearDown(self):
        self.tmp.cleanup()

    def test_prints_report(self):
        out = io.StringIO()
        with redirect_stdout(out):
            code = aa.main([self.path])
        self.assertEqual(code, 0)
        text = out.getvalue()
        self.assertIn("Lap 1", text)
        self.assertIn("Lap 2", text)
        self.assertIn("Sauts", text)

    def test_csv_export(self):
        csv_path = os.path.join(self.tmp.name, "out.csv")
        with redirect_stdout(io.StringIO()):
            code = aa.main([self.path, "--csv", csv_path])
        self.assertEqual(code, 0)
        import csv
        with open(csv_path, newline="") as f:
            rows = list(csv.DictReader(f))
        self.assertEqual(len(rows), 121 + 31)
        self.assertEqual(rows[0]["lap"], "1")
        self.assertEqual(rows[-1]["lap"], "2")
        for col in ("time", "elapsed_s", "altitude_m", "distance_m", "vs60_regression_mh",
                    "vs60_diff_mh", "vs_watch_mh", "speed60_mps", "pace60_min_km"):
            self.assertIn(col, rows[0])
        self.assertEqual(rows[0]["vs60_regression_mh"], "")
        self.assertAlmostEqual(float(rows[100]["vs60_regression_mh"]), 600.0, delta=30.0)

    def test_threshold_option(self):
        out = io.StringIO()
        with redirect_stdout(out):
            code = aa.main([self.path, "--gain-threshold", "0.5"])
        self.assertEqual(code, 0)
        self.assertIn("0.5 m", out.getvalue())

    def test_missing_file(self):
        err = io.StringIO()
        with redirect_stderr(err):
            code = aa.main([os.path.join(self.tmp.name, "nope.tcx")])
        self.assertNotEqual(code, 0)
        self.assertIn("nope.tcx", err.getvalue())

    def test_invalid_xml(self):
        bad = os.path.join(self.tmp.name, "bad.tcx")
        with open(bad, "w") as f:
            f.write("<not xml")
        err = io.StringIO()
        with redirect_stderr(err):
            code = aa.main([bad])
        self.assertNotEqual(code, 0)


@unittest.skipUnless(os.path.exists(SALVAN_TCX), "Salvan TCX not present")
class SalvanTest(unittest.TestCase):
    """Real data: Salvan, 2026-09-13. Expected figures from the corrections plan."""

    @classmethod
    def setUpClass(cls):
        cls.laps = aa.parse_tcx(SALVAN_TCX)
        cls.climb = aa.summarize_lap(cls.laps[0])
        cls.flight = aa.summarize_lap(cls.laps[1])

    def test_two_laps(self):
        self.assertEqual(len(self.laps), 2)
        self.assertEqual(self.laps[0].start, "2026-09-13T10:18:43.000Z")
        self.assertEqual(self.laps[1].start, "2026-09-13T12:20:25.000Z")

    def test_climb_points_and_zero_speed(self):
        self.assertEqual(self.climb["points"], 2211)
        self.assertEqual(self.climb["zero_speed"], 1748)
        self.assertEqual(self.climb["with_speed"], 2211)
        share = 100.0 * self.climb["zero_speed"] / self.climb["with_speed"]
        self.assertAlmostEqual(share, 79.1, delta=0.05)

    def test_climb_recorded_distance(self):
        self.assertAlmostEqual(self.climb["recorded_distance_m"], 3904.6, delta=0.05)
        self.assertAlmostEqual(self.climb["duration_s"], 7302.217, delta=0.001)

    def test_climb_gps_distance(self):
        self.assertAlmostEqual(self.climb["gps_distance_m"], 4011.0, delta=0.02 * 4011.0)

    def test_climb_vertical_speed_regression(self):
        self.assertAlmostEqual(self.climb["vs_regression"]["median"], 636.0, delta=0.05 * 636.0)

    def test_climb_vertical_speed_diff_reproduces_plan(self):
        # The plan's +636 m/h, p5 -129, p95 +891 come from the endpoint
        # difference over a trailing 60 s window, evaluated at every point.
        vs = self.climb["vs_diff"]
        self.assertAlmostEqual(vs["median"], 636.0, delta=1.0)
        self.assertAlmostEqual(vs["p5"], -129.0, delta=1.0)
        self.assertAlmostEqual(vs["p95"], 891.0, delta=1.0)

    def test_climb_elevation_gain_bounds(self):
        # Real series: the hysteresis D+ lies between the net climb (last -
        # first altitude) and the sum of every rise (threshold 0), and a
        # larger threshold never gives more.
        alts = [p.alt for p in self.laps[0].points]
        net = alts[-1] - alts[0]
        all_rises = aa.elevation_gain_m(alts, threshold=0.0)
        gain = self.climb["elevation_gain_m"]
        self.assertGreaterEqual(gain, net)
        self.assertLessEqual(gain, all_rises)
        self.assertLessEqual(aa.elevation_gain_m(alts, threshold=3.0), gain)

    def test_climb_no_jump(self):
        self.assertEqual(self.climb["jumps"], [])

    def test_flight_points_and_zero_speed(self):
        self.assertEqual(self.flight["points"], 2100)
        self.assertEqual(self.flight["zero_speed"], 130)
        self.assertAlmostEqual(self.flight["duration_s"], 3250.0, delta=1.0)
        self.assertAlmostEqual(self.flight["recorded_distance_m"], 22756.0, delta=1.0)

    def test_report_runs(self):
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(aa.main([SALVAN_TCX]), 0)
        self.assertIn("Lap 2", out.getvalue())


if __name__ == "__main__":
    unittest.main()
