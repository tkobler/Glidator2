using Toybox.Test;

// Unit tests of the display formatters in Utils.mc that bound what the hike
// pages and the compass show (defects D2 hike page, D3, D5, D6, D7, D8 of the
// test plan; display bounds decided on 2026-10-06).

// D6: a negative duration has no meaning on a timer: "--:--". Everything
// from 0 up is unchanged (testFormatDuration in Tests.mc).
(:test)
function testFormatDurationNegative(logger)
{
	Test.assertEqualMessage(formatDuration(-1), "--:--", "-1 ms (bound just below 0)");
	Test.assertEqualMessage(formatDuration(-999), "--:--", "-999 ms (was 00:00)");
	Test.assertEqualMessage(formatDuration(-1000), "--:--", "-1 s (was 00:-1)");
	Test.assertEqualMessage(formatDuration(-65000), "--:--", "-65 s (was -1:-5)");
	Test.assertEqualMessage(formatDuration(-3600000), "--:--", "-1 h");
	Test.assertEqualMessage(formatDuration(-0.5), "--:--", "negative Float");
	Test.assertEqualMessage(formatDuration(0), "00:00", "0 is still valid (bound)");
	Test.assertEqualMessage(formatDuration(-0.0), "00:00", "-0.0 is zero, not negative");
	Test.assertEqualMessage(formatDuration(999), "00:00", "999 ms still truncated to 00:00");
	return true;
}

// D3: DISTANCE of the Position page, in km with one decimal. "--" for null,
// negative, NaN or +-Infinity; -0.0 is a zero and reads "0.0", not "-0.0".
(:test)
function testFormatDistanceKm(logger)
{
	Test.assertEqualMessage(formatDistanceKm(null), "--", "null");
	Test.assertEqualMessage(formatDistanceKm(0.0), "0.0", "0 (bound)");
	Test.assertEqualMessage(formatDistanceKm(-0.0), "0.0", "-0.0 is zero, no minus sign");
	Test.assertEqualMessage(formatDistanceKm(0), "0.0", "Number 0");
	Test.assertEqualMessage(formatDistanceKm(-0.001), "--", "just below 0");
	Test.assertEqualMessage(formatDistanceKm(-5.0), "--", "-5 m (was -0.0)");
	Test.assertEqualMessage(formatDistanceKm(-1000.0), "--", "-1 km (was -1.0)");
	Test.assertEqualMessage(formatDistanceKm(-1), "--", "Number -1");
	Test.assertEqualMessage(formatDistanceKm(MapTestHelper.nan()), "--", "NaN");
	Test.assertEqualMessage(formatDistanceKm(MapTestHelper.inf()), "--", "+Inf");
	Test.assertEqualMessage(formatDistanceKm(-MapTestHelper.inf()), "--", "-Inf");
	Test.assertEqualMessage(formatDistanceKm(1500), "1.5", "Number 1500 m");
	Test.assertEqualMessage(formatDistanceKm(999900.0), "999.9", "999.9 km");
	// Real values (garmin_data/activity_24346302742.tcx, DistanceMeters at
	// 10:51:28 and 13:01:47 UTC).
	Test.assertEqualMessage(formatDistanceKm(1692.49), "1.7", "Salvan 10:51:28");
	Test.assertEqualMessage(formatDistanceKm(22048.72), "22.0", "Salvan 13:01:47");
	return true;
}

// D2 (hike Position page only): ALTITUDE rounded to the meter, "--" for
// null, NaN, +-Infinity or outside -100..6000 m. The bound applies to the
// raw value: 6000.4 rounds to 6000 but is out of range, so "--".
(:test)
function testFormatHikeAltitude(logger)
{
	Test.assertEqualMessage(formatHikeAltitude(null), "--", "null");
	Test.assertEqualMessage(formatHikeAltitude(-100.0), "-100", "lower bound -100 is valid");
	Test.assertEqualMessage(formatHikeAltitude(6000.0), "6000", "upper bound 6000 is valid");
	Test.assertEqualMessage(formatHikeAltitude(-100), "-100", "Number -100");
	Test.assertEqualMessage(formatHikeAltitude(6000), "6000", "Number 6000");
	Test.assertEqualMessage(formatHikeAltitude(-100.1), "--", "just below -100");
	Test.assertEqualMessage(formatHikeAltitude(6000.1), "--", "just above 6000");
	Test.assertEqualMessage(formatHikeAltitude(-101), "--", "Number -101");
	Test.assertEqualMessage(formatHikeAltitude(6001), "--", "Number 6001");
	Test.assertEqualMessage(formatHikeAltitude(6000.4), "--", "rounds to 6000 but the raw value is out of range");
	Test.assertEqualMessage(formatHikeAltitude(-100.4), "--", "rounds to -100 but the raw value is out of range");
	Test.assertEqualMessage(formatHikeAltitude(-99.6), "-100", "in range, rounds to -100");
	Test.assertEqualMessage(formatHikeAltitude(5999.4), "5999", "in range, rounds down");
	Test.assertEqualMessage(formatHikeAltitude(5999.6), "6000", "in range, rounds up to 6000");
	Test.assertEqualMessage(formatHikeAltitude(0.0), "0", "zero");
	Test.assertEqualMessage(formatHikeAltitude(-0.4), "0", "rounds to zero, no minus sign");
	Test.assertEqualMessage(formatHikeAltitude(-432.4), "--", "Dead Sea shore");
	Test.assertEqualMessage(formatHikeAltitude(8848.6), "--", "Everest");
	Test.assertEqualMessage(formatHikeAltitude(1.0e10), "--", "huge (was an overflowed Number)");
	Test.assertEqualMessage(formatHikeAltitude(-1.0e10), "--", "huge negative");
	Test.assertEqualMessage(formatHikeAltitude(MapTestHelper.nan()), "--", "NaN (was 0)");
	Test.assertEqualMessage(formatHikeAltitude(MapTestHelper.inf()), "--", "+Inf");
	Test.assertEqualMessage(formatHikeAltitude(-MapTestHelper.inf()), "--", "-Inf");
	Test.assertEqualMessage(formatHikeAltitude(2149.4d), "2149", "Double");
	// Real values (garmin_data/activity_24346302742.tcx, AltitudeMeters at
	// 10:51:28 and 13:01:47 UTC).
	Test.assertEqualMessage(formatHikeAltitude(2149.4), "2149", "Salvan 10:51:28");
	Test.assertEqualMessage(formatHikeAltitude(1732.2), "1732", "Salvan 13:01:47");
	return true;
}
