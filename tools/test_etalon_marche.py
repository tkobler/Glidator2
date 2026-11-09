"""Tests for tools/etalon_marche.py (Python 3 stdlib only).

Run from the repository root:
    python3 -m unittest tools/test_etalon_marche.py
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import analyze_activity as aa  # noqa: E402
import etalon_marche as em  # noqa: E402


class GainTest(unittest.TestCase):
    ALTS = [100.0, 100.4, 100.2, 101.6, 101.0, 103.0, 99.0, 99.8, 102.5, None, 102.0]

    def test_cumulative_hysteresis_matches_analyze_activity(self):
        for th in (0.0, 1.0, 3.0):
            series = em.gain_series(self.ALTS, th)
            for i in range(len(self.ALTS)):
                self.assertAlmostEqual(series[i], aa.elevation_gain_m(self.ALTS[:i + 1], th) or 0.0)

    def test_raw_gain_sums_positive_steps(self):
        self.assertAlmostEqual(em.raw_gain_series(self.ALTS)[-1], 0.4 + 1.4 + 2.0 + 0.8 + 2.7)


class HikeHistoryReplayTest(unittest.TestCase):
    def test_spacing_and_gap_rules(self):
        hh = em.HikeHistoryReplay()
        self.assertTrue(hh.add(0, 100.0, 0.0))
        self.assertFalse(hh.add(4999, 100.0, 1.0))   # < 5 s: dropped
        self.assertTrue(hh.add(5000, 100.0, 1.0))
        self.assertTrue(hh.add(20001, 100.0, 2.0))   # > 15 s: reset, then kept
        self.assertEqual(len(hh.samples), 1)
        self.assertFalse(hh.add(1000, None, 0.0))    # null altitude ignored

    def test_linear_climb_and_walk(self):
        hh = em.HikeHistoryReplay()
        for s in range(0, 61):  # fed at 1 Hz like onSensor()
            hh.add(s * 1000, 1000.0 + s / 6.0, s * 0.5)  # 600 m/h, 0.5 m/s
        self.assertAlmostEqual(hh.vertical_speed_mh(60000), 600.0, places=6)
        self.assertAlmostEqual(hh.speed_mps(60000), 0.5, places=9)

    def test_not_enough_coverage(self):
        hh = em.HikeHistoryReplay()
        for s in (0, 5, 10, 15):
            hh.add(s * 1000, 100.0 + s, 0.0)
        self.assertIsNone(hh.vertical_speed_mh(15000))  # 15 s < 20 s


class FormatTest(unittest.TestCase):
    def test_formats_follow_utils_mc(self):
        self.assertEqual(em.fmt_altitude(-100.1), "--")
        self.assertEqual(em.fmt_altitude(-237.8), "--")
        self.assertEqual(em.fmt_altitude(1840.5), "1841")
        self.assertEqual(em.fmt_ascent(907.6), "908")
        self.assertEqual(em.fmt_ascent(-0.1), "--")
        self.assertEqual(em.fmt_heart_rate(None), "--")
        self.assertEqual(em.fmt_vertical_speed(3000.4), "--")
        self.assertEqual(em.fmt_vertical_speed(-4.9), "0")
        self.assertEqual(em.fmt_vertical_speed(665.0), "+670")
        self.assertEqual(em.fmt_pace(1000.0 / 3600.4), "60:00")
        self.assertEqual(em.fmt_pace(1000.0 / 3600.6), "--:--")
        self.assertEqual(em.fmt_pace(1000.0 / 359.6), "6:00")


def _fake_lap(hrs):
    """Synthetic lap (no real coordinates): 5 points, 10 s apart."""
    from types import SimpleNamespace as NS
    pts = [em.GpxPoint(i, 10 + i, 1000.0 + 10 * i, 46.0, 7.0, 1500.0 + i, hr)
           for i, hr in enumerate(hrs)]
    n = len(pts)
    lap = NS(pts=pts, dist_gps=[10.0 * i for i in range(n)],
             gain_raw=[float(i) for i in range(n)],
             gain_h1=[float(i) for i in range(n)],
             gain_h3=[float(i) for i in range(n)])
    tcx_lap = NS(start="2026-01-01T00:00:00Z", total_time_s=40.0, distance_m=40.0,
                 points=[NS(speed=1.0, dist=10.0 * i) for i in range(n)])
    return lap, tcx_lap


class TotalsReportHrTest(unittest.TestCase):
    def setUp(self):
        em._TCX_HR.clear()

    def test_without_heart_rate_does_not_crash(self):
        lap, tcx_lap = _fake_lap([None] * 5)
        text = "\n".join(em.totals_report(lap, tcx_lap))
        self.assertIn("FC : aucune", text)

    def test_with_heart_rate_unchanged(self):
        lap, tcx_lap = _fake_lap([100, 110, 120, 130, 140])
        text = "\n".join(em.totals_report(lap, tcx_lap))
        self.assertIn("max 140 bpm", text)
        self.assertIn("min 100", text)

    def test_partial_heart_rate(self):
        lap, tcx_lap = _fake_lap([None, 100, None, 120, None])
        text = "\n".join(em.totals_report(lap, tcx_lap))
        self.assertIn("max 120 bpm", text)


class TotalsReportSpeedTest(unittest.TestCase):
    def setUp(self):
        em._TCX_HR.clear()

    def test_without_speed_field_does_not_crash(self):
        lap, tcx_lap = _fake_lap([100, 110, 120, 130, 140])
        for p in tcx_lap.points:
            p.speed = None
        text = "\n".join(em.totals_report(lap, tcx_lap))
        self.assertIn("n/a (pas de Speed)", text)
        self.assertIn("moyenne distance/duree 1.0000 m/s", text)  # 40 m / 40 s still reported

    def test_zero_lap_duration_does_not_crash(self):
        lap, tcx_lap = _fake_lap([100, 110, 120, 130, 140])
        tcx_lap.total_time_s = 0.0
        text = "\n".join(em.totals_report(lap, tcx_lap))
        self.assertIn("max du champ Speed 1.000 m/s", text)
        self.assertIn("duree nulle", text)

    def test_speed_present_unchanged(self):
        lap, tcx_lap = _fake_lap([100, 110, 120, 130, 140])
        text = "\n".join(em.totals_report(lap, tcx_lap))
        self.assertIn("max du champ Speed 1.000 m/s ; moyenne distance/duree 1.0000 m/s", text)


if __name__ == "__main__":
    unittest.main()
