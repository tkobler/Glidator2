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

// D5: heart rate of the hike Pace page, "--" for null or outside
// 25..250 bpm (bounds included). A Float is rounded to the nearest bpm, but
// the range is checked on the raw value, as for the altitude.
(:test)
function testFormatHeartRate(logger)
{
	Test.assertEqualMessage(formatHeartRate(null), "--", "null");
	Test.assertEqualMessage(formatHeartRate(25), "25", "lower bound 25 is valid");
	Test.assertEqualMessage(formatHeartRate(250), "250", "upper bound 250 is valid");
	Test.assertEqualMessage(formatHeartRate(24), "--", "just below 25");
	Test.assertEqualMessage(formatHeartRate(251), "--", "just above 250");
	Test.assertEqualMessage(formatHeartRate(0), "--", "0 (no contact)");
	Test.assertEqualMessage(formatHeartRate(-1), "--", "negative");
	Test.assertEqualMessage(formatHeartRate(255), "--", "255 (invalid byte)");
	Test.assertEqualMessage(formatHeartRate(24.9), "--", "Float just below 25");
	Test.assertEqualMessage(formatHeartRate(250.4), "--", "Float just above 250, rounds to 250");
	Test.assertEqualMessage(formatHeartRate(139.6), "140", "Float rounded");
	Test.assertEqualMessage(formatHeartRate(MapTestHelper.nan()), "--", "NaN");
	Test.assertEqualMessage(formatHeartRate(MapTestHelper.inf()), "--", "+Inf");
	// Real value (garmin_data/activity_24346302742.tcx, HeartRateBpm at
	// 10:51:28 UTC).
	Test.assertEqualMessage(formatHeartRate(139), "139", "Salvan 10:51:28");
	return true;
}

// D9: rotation of the compass dial from the heading (radians): the heading
// negated (the dial turns the other way), 0 (no rotation) when the heading
// is null (Position.Info.heading can be), NaN or +-Infinity.
(:test)
function testCompassRotation(logger)
{
	Test.assertEqualMessage(compassRotation(null), 0.0, "null -> no rotation (was a crash)");
	Test.assertEqualMessage(compassRotation(MapTestHelper.nan()), 0.0, "NaN -> no rotation");
	Test.assertEqualMessage(compassRotation(MapTestHelper.inf()), 0.0, "+Inf -> no rotation");
	Test.assertEqualMessage(compassRotation(-MapTestHelper.inf()), 0.0, "-Inf -> no rotation");
	Test.assertEqualMessage(compassRotation(0.0), 0.0, "0 -> 0");
	Test.assertEqualMessage(compassRotation(0.785), -0.785, "heading negated");
	Test.assertEqualMessage(compassRotation(-1.5), 1.5, "negative heading negated");
	Test.assertEqualMessage(compassRotation(1), -1.0, "Number heading");
	return true;
}

// D7, D8: a coordinate in degrees as D°MM'S.S" plus the hemisphere letter,
// without a minus sign (D7); the seconds are rounded to 0.1" once, on the
// whole value, so 59.96" carries into the minutes and the degrees (D8).
(:test)
function testFormatLatLon(logger)
{
	// Real point (TCX 10:51:28), as Location.toDegrees() gives it, and as Float.
	Test.assertEqualMessage(formatLatLon(46.12446558661759d, true), "46°07'28.1\"N", "Salvan lat");
	Test.assertEqualMessage(formatLatLon(6.985453460365534d, false), "6°59'7.6\"E", "Salvan lon");
	Test.assertEqualMessage(formatLatLon(46.124466, true), "46°07'28.1\"N", "Salvan lat, Float");
	Test.assertEqualMessage(formatLatLon(6.9854535, false), "6°59'7.6\"E", "Salvan lon, Float");
	// D7: south and west.
	Test.assertEqualMessage(formatLatLon(-22.9519d, true), "22°57'6.8\"S", "Rio lat (was -22°...)");
	Test.assertEqualMessage(formatLatLon(-43.2105d, false), "43°12'37.8\"W", "Rio lon (was -43°...)");
	Test.assertEqualMessage(formatLatLon(-0.5d, true), "0°30'0.0\"S", "just south of 0");
	Test.assertEqualMessage(formatLatLon(-0.5d, false), "0°30'0.0\"W", "just west of 0");
	Test.assertEqualMessage(formatLatLon(-0.00002d, true), "0°00'0.1\"S", "0.072\" south rounds to 0.1\"S");
	Test.assertEqualMessage(formatLatLon(-0.00001d, true), "0°00'0.0\"N", "rounds to zero: no hemisphere sign, N");
	Test.assertEqualMessage(formatLatLon(-0.00001d, false), "0°00'0.0\"E", "rounds to zero: E");
	Test.assertEqualMessage(formatLatLon(0.0, true), "0°00'0.0\"N", "equator");
	Test.assertEqualMessage(formatLatLon(-0.0, false), "0°00'0.0\"E", "-0.0 meridian");
	// D8: carries.
	Test.assertEqualMessage(formatLatLon(45.99999d, true), "46°00'0.0\"N", "seconds carry into minutes and degrees (was 45°59'60.0\")");
	Test.assertEqualMessage(formatLatLon(6.99999d, false), "7°00'0.0\"E", "same on a longitude (was 6°59'60.0\")");
	Test.assertEqualMessage(formatLatLon(46.4999999d, true), "46°30'0.0\"N", "seconds carry into minutes (was 46°29'60.0\")");
	Test.assertEqualMessage(formatLatLon(46.13331667d, true), "46°07'59.9\"N", "59.94\" stays 59.9\"");
	Test.assertEqualMessage(formatLatLon(46.13332222d, true), "46°08'0.0\"N", "59.96\" carries");
	Test.assertEqualMessage(formatLatLon(-45.99999d, true), "46°00'0.0\"S", "carry in the south");
	Test.assertEqualMessage(formatLatLon(179.99999d, false), "180°00'0.0\"E", "carry up to 180");
	// Bounds and invalid values.
	Test.assertEqualMessage(formatLatLon(90.0d, true), "90°00'0.0\"N", "north pole (bound)");
	Test.assertEqualMessage(formatLatLon(-90.0d, true), "90°00'0.0\"S", "south pole (bound)");
	Test.assertEqualMessage(formatLatLon(180.0d, false), "180°00'0.0\"E", "lon 180 (bound)");
	Test.assertEqualMessage(formatLatLon(-180.0d, false), "180°00'0.0\"W", "lon -180 (bound)");
	Test.assertEqualMessage(formatLatLon(90.001d, true), "--", "lat beyond 90");
	Test.assertEqualMessage(formatLatLon(180.001d, false), "--", "lon beyond 180");
	Test.assertEqualMessage(formatLatLon(null, true), "--", "null");
	Test.assertEqualMessage(formatLatLon(MapTestHelper.nan(), true), "--", "NaN");
	Test.assertEqualMessage(formatLatLon(MapTestHelper.inf(), false), "--", "+Inf");
	return true;
}
