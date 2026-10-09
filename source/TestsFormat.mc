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

// ELEV. GAIN of the Position page (decision of 07/10, Position ascent guard):
// rounded to the meter like the altitude, "--" for null, NaN, +-Infinity,
// negative or above 20 000 m (bound included). The bound applies to the raw
// value: 20000.4 rounds to 20000 but is out of range, so "--". -0.0 is a zero
// and reads "0", not "-0" or "--".
(:test)
function testFormatHikeAscent(logger)
{
	Test.assertEqualMessage(formatHikeAscent(null), "--", "null");
	Test.assertEqualMessage(formatHikeAscent(0.0), "0", "0 (lower bound)");
	Test.assertEqualMessage(formatHikeAscent(-0.0), "0", "-0.0 is zero, no minus sign");
	Test.assertEqualMessage(formatHikeAscent(0), "0", "Number 0");
	Test.assertEqualMessage(formatHikeAscent(20000.0), "20000", "upper bound 20000 is valid");
	Test.assertEqualMessage(formatHikeAscent(20000), "20000", "Number 20000");
	Test.assertEqualMessage(formatHikeAscent(20000.1), "--", "just above 20000");
	Test.assertEqualMessage(formatHikeAscent(20000.4), "--", "rounds to 20000 but the raw value is out of range");
	Test.assertEqualMessage(formatHikeAscent(20001), "--", "Number 20001");
	Test.assertEqualMessage(formatHikeAscent(19999.6), "20000", "in range, rounds up to 20000");
	Test.assertEqualMessage(formatHikeAscent(-0.1), "--", "just below 0");
	Test.assertEqualMessage(formatHikeAscent(-0.4), "--", "rounds to 0 but the raw value is negative");
	Test.assertEqualMessage(formatHikeAscent(-1), "--", "Number -1");
	Test.assertEqualMessage(formatHikeAscent(0.4), "0", "rounds down to 0");
	Test.assertEqualMessage(formatHikeAscent(0.5), "1", "half rounds up");
	Test.assertEqualMessage(formatHikeAscent(335.4), "335", "rounds down");
	Test.assertEqualMessage(formatHikeAscent(1.0e10), "--", "huge (would overflow a Number)");
	Test.assertEqualMessage(formatHikeAscent(MapTestHelper.nan()), "--", "NaN");
	Test.assertEqualMessage(formatHikeAscent(MapTestHelper.inf()), "--", "+Inf");
	Test.assertEqualMessage(formatHikeAscent(-MapTestHelper.inf()), "--", "-Inf");
	// Long and Double.
	Test.assertEqualMessage(formatHikeAscent(20000l), "20000", "Long 20000");
	Test.assertEqualMessage(formatHikeAscent(20001l), "--", "Long 20001");
	Test.assertEqualMessage(formatHikeAscent(5000000000l), "--", "Long 5e9");
	Test.assertEqualMessage(formatHikeAscent(-1l), "--", "Long -1");
	Test.assertEqualMessage(formatHikeAscent(907.6d), "908", "Double");
	Test.assertEqualMessage(formatHikeAscent(20000.0d), "20000", "Double 20000");
	Test.assertEqualMessage(formatHikeAscent(20000.001d), "--", "Double just above 20000");
	Test.assertEqualMessage(formatHikeAscent(-0.001d), "--", "Double just below 0");
	Test.assertEqualMessage(formatHikeAscent(-0.0d), "0", "Double -0.0");
	Test.assertEqualMessage(formatHikeAscent(1.0e300d), "--", "Double 1e300");
	// Real value (garmin_data/activity_24346302742.tcx): D+ of lap 1, the
	// Salvan climb, 908 m.
	Test.assertEqualMessage(formatHikeAscent(908.0), "908", "Salvan climb D+");
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

// V1b (flight page, plan of 08/10): altitude rounded to the meter as before
// (Math.round), "--" for null, NaN, +-Infinity or outside -500..9000 m
// (bounds included). The bound applies to the raw value: 9000.4 rounds to
// 9000 but is out of range, so "--". Wider than the hike bounds: 6000.1 and
// -432.4 are shown in flight.
(:test)
function testFormatFlightAltitude(logger)
{
	Test.assertEqualMessage(formatFlightAltitude(null), "--", "null");
	Test.assertEqualMessage(formatFlightAltitude(-500.0), "-500", "lower bound -500 is valid");
	Test.assertEqualMessage(formatFlightAltitude(9000.0), "9000", "upper bound 9000 is valid");
	Test.assertEqualMessage(formatFlightAltitude(-500), "-500", "Number -500");
	Test.assertEqualMessage(formatFlightAltitude(9000), "9000", "Number 9000");
	Test.assertEqualMessage(formatFlightAltitude(-500.1), "--", "just below -500");
	Test.assertEqualMessage(formatFlightAltitude(9000.1), "--", "just above 9000");
	Test.assertEqualMessage(formatFlightAltitude(-501), "--", "Number -501");
	Test.assertEqualMessage(formatFlightAltitude(9001), "--", "Number 9001");
	Test.assertEqualMessage(formatFlightAltitude(9000.4), "--", "rounds to 9000 but the raw value is out of range");
	Test.assertEqualMessage(formatFlightAltitude(-500.4), "--", "rounds to -500 but the raw value is out of range");
	Test.assertEqualMessage(formatFlightAltitude(9000.0001d), "--", "Double just above 9000 (checked in Double)");
	Test.assertEqualMessage(formatFlightAltitude(-499.6), "-500", "in range, rounds to -500");
	Test.assertEqualMessage(formatFlightAltitude(8999.6), "9000", "in range, rounds up to 9000");
	Test.assertEqualMessage(formatFlightAltitude(8848.6), "8849", "Everest");
	Test.assertEqualMessage(formatFlightAltitude(6000.1), "6000", "above the hike bound, shown in flight");
	Test.assertEqualMessage(formatFlightAltitude(-432.4), "-432", "Dead Sea shore, shown in flight");
	Test.assertEqualMessage(formatFlightAltitude(0.0), "0", "zero");
	Test.assertEqualMessage(formatFlightAltitude(-0.4), "0", "rounds to zero, no minus sign");
	Test.assertEqualMessage(formatFlightAltitude(1.0e10), "--", "huge (was 2147483647)");
	Test.assertEqualMessage(formatFlightAltitude(-1.0e10), "--", "huge negative");
	Test.assertEqualMessage(formatFlightAltitude(MapTestHelper.nan()), "--", "NaN (was 0)");
	Test.assertEqualMessage(formatFlightAltitude(MapTestHelper.inf()), "--", "+Inf");
	Test.assertEqualMessage(formatFlightAltitude(-MapTestHelper.inf()), "--", "-Inf");
	Test.assertEqualMessage(formatFlightAltitude(2149.4d), "2149", "Double");
	// Real values (garmin_data/activity_24346302742.tcx, AltitudeMeters at
	// 10:51:28 and 13:01:47 UTC).
	Test.assertEqualMessage(formatFlightAltitude(2149.4), "2149", "Salvan 10:51:28");
	Test.assertEqualMessage(formatFlightAltitude(1732.2), "1732", "Salvan 13:01:47");
	return true;
}

// V1a (flight page, plan of 08/10): left x of the speed line ("<speed> km/h",
// WatchDisplay.speed()). Unchanged without a sub-window or when the line is
// clear of it; else moved left until its right end meets the left edge of
// the sub-window (x = sub[0]), never left of x = 0.
(:test)
function testFlySpeedLineX(logger)
{
	var i2 = [113, 0, 62, 62]; // instinct2 sub-window [x, y, width, height]
	// No sub-window (fenix6pro, fenix5...): the centred x, as is.
	Test.assertEqualMessage(flySpeedLineX(100, 59, 47.5, 82.5, null), 100, "no sub-window: fenix6pro Normal unchanged");
	Test.assertEqualMessage(flySpeedLineX(73, 94, 42.5, 77.5, null), 73, "no sub-window: Extreme unchanged");
	Test.assertEqualMessage(flySpeedLineX(-5, 300, 0, 40, null), -5, "no sub-window: even off screen, unchanged");
	// instinct2 bench values (Normal "0 km/h": x 61, width 54; Extreme
	// "120 km/h": x 48, width 80; NUMBER_MILD 35 px high at y = 44).
	Test.assertEqualMessage(flySpeedLineX(61, 54, 26.5, 61.5, i2), 59, "instinct2 Normal: 2 px left, ends at 113");
	Test.assertEqualMessage(flySpeedLineX(48, 80, 26.5, 61.5, i2), 33, "instinct2 Extreme: ends at 113");
	// Already clear of the sub-window.
	Test.assertEqualMessage(flySpeedLineX(59, 54, 26.5, 61.5, i2), 59, "right end exactly at sub x (touching): unchanged");
	Test.assertEqualMessage(flySpeedLineX(20, 54, 26.5, 61.5, i2), 20, "left of the sub-window: unchanged");
	Test.assertEqualMessage(flySpeedLineX(61, 54, 62, 97, i2), 61, "top at the sub-window bottom (touching): unchanged");
	Test.assertEqualMessage(flySpeedLineX(61, 54, 70, 105, i2), 61, "below the sub-window: unchanged");
	Test.assertEqualMessage(flySpeedLineX(61, 54, 0, 20, [113, 30, 62, 62]), 61, "above a lower sub-window: unchanged");
	Test.assertEqualMessage(flySpeedLineX(61, 54, 61.9, 96.9, i2), 59, "0.1 px into the sub-window height: moved");
	// Wider than the room left of the sub-window: clamped to 0.
	Test.assertEqualMessage(flySpeedLineX(10, 150, 26.5, 61.5, i2), 0, "too wide: clamped to x = 0");
	Test.assertEqualMessage(flySpeedLineX(0, 0, 26.5, 61.5, i2), 0, "empty line at 0");
	return true;
}
