using Toybox.Test;
using Toybox.Activity;
using Toybox.ActivityRecording;

// Unit tests for the hike-and-fly feature's pure logic, run with:
//   monkeyc -f monkey.jungle -d fenix6 -o bin/tests.prg -y developer_key -t
//   monkeydo bin/tests.prg fenix6 -t
// (:test) functions are compiled out entirely of normal (non -t) builds.

(:test)
function testFormatDuration(logger)
{
	Test.assertEqualMessage(formatDuration(null), "--:--", "null duration should show placeholder");
	Test.assertEqualMessage(formatDuration(0), "00:00", "zero ms");
	Test.assertEqualMessage(formatDuration(59000), "00:59", "59 seconds");
	Test.assertEqualMessage(formatDuration(60000), "01:00", "exactly one minute");
	Test.assertEqualMessage(formatDuration(3599000), "59:59", "just under an hour");
	Test.assertEqualMessage(formatDuration(3600000), "1:00:00", "exactly one hour rolls into h:mm:ss");
	Test.assertEqualMessage(formatDuration(3661000), "1:01:01", "one hour, one minute, one second");
	return true;
}

(:test)
function testBreadcrumbTrailDecimation(logger)
{
	var trail = new BreadcrumbTrail();

	trail.update(46.0, 7.0);
	Test.assertEqualMessage(trail.getCount(), 1, "first point is always stored");

	// ~1.1m away -- below the 15m decimation threshold, should be dropped
	trail.update(46.00001, 7.0);
	Test.assertEqualMessage(trail.getCount(), 1, "sub-threshold move should be decimated away");

	// ~20m north of the last *stored* point -- above threshold, should be stored
	trail.update(46.00018, 7.0);
	Test.assertEqualMessage(trail.getCount(), 2, "above-threshold move should be stored");

	return true;
}

(:test,:typecheck(false))
// See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
function testBreadcrumbTrailRingBufferWraparound(logger)
{
	var trail = new BreadcrumbTrail();
	var capacity = 250; // must match BreadcrumbTrail.MAX_POINTS

	// Push more points than the buffer holds, each ~111m apart (well above
	// the 15m decimation threshold) so every push is accepted.
	var lat = 46.0;
	for (var i = 0; i < capacity + 10; i++)
	{
		lat += 0.001;
		trail.update(lat, 7.0);
	}

	Test.assertEqualMessage(trail.getCount(), capacity, "count should cap at capacity once the ring buffer is full");

	// The 10 oldest pushes (#1-10) should have been overwritten by pushes #251-260;
	// the oldest surviving point is push #11, i.e. lat = 46.0 + 0.001*11 = 46.011,
	// and it must sit exactly at writeIndex (the slot about to be overwritten next).
	var idx = trail.getWriteIndex();
	var oldestLat = trail.getLats()[idx];
	Test.assertMessage(oldestLat > 46.0105 && oldestLat < 46.0115, "oldest retained point should be push #11 (~46.011), got " + oldestLat);

	return true;
}

(:test)
function testWatchDataAccessorsFallBackToActivityData(logger)
{
	var data = new WatchData();

	// assertEqualMessage()'s first argument is documented as non-nullable Lang.Object;
	// passing a null actual there throws rather than failing cleanly, so null checks
	// use the boolean form instead.
	Test.assertMessage(data.getTotalAscent() == null, "no data collected yet (totalAscent)");
	Test.assertMessage(data.getDistance() == null, "no data collected yet (distance)");
	Test.assertMessage(data.getTimerTime() == null, "no data collected yet (timerTime)");
	Test.assertMessage(data.getSpeed() == null, "no data collected yet (speed)");

	// Simulate updateActivityInfo() having populated activityData, without
	// needing a real Activity.Info object.
	data.activityData = {
		"totalAscent" => 123.4,
		"distance" => 5000.0,
		"timerTime" => 65000,
		"speed" => 2.5
	};

	Test.assertEqualMessage(data.getTotalAscent(), 123.4, "totalAscent read from activityData");
	Test.assertEqualMessage(data.getDistance(), 5000.0, "distance read from activityData");
	Test.assertEqualMessage(data.getTimerTime(), 65000, "timerTime read from activityData");
	Test.assertEqualMessage(data.getSpeed(), 2.5, "getSpeed() should fall back to activityData when sensor/GPS speed are absent");

	// sensorData must still win over activityData when both are present, to
	// avoid regressing the Flying page's existing speed source priority.
	data.sensorData = { "speed" => 9.9 };
	Test.assertEqualMessage(data.getSpeed(), 9.9, "getSpeed() should prefer sensorData over activityData");

	return true;
}

(:test)
function testSessionStateMachine(logger)
{
	// Defensive reset in case a previous test/run left a session open.
	if ($.hasActiveSession())
	{
		$.stopRecording(false);
	}

	Test.assertMessage(!$.hasActiveSession(), "no session initially");
	Test.assertMessage(!$.isRecording(), "not recording initially");

	$.startRecording();
	Test.assertMessage($.hasActiveSession(), "session exists after startRecording()");
	Test.assertMessage($.isRecording(), "actively recording after startRecording()");

	$.pauseRecording();
	Test.assertMessage($.hasActiveSession(), "session must still exist while paused -- this is exactly what the BACK quit-menu gate relies on to offer Save/Ignore instead of silently exiting");
	Test.assertMessage(!$.isRecording(), "not actively recording while paused");

	$.resumeRecording();
	Test.assertMessage($.hasActiveSession(), "session exists after resume");
	Test.assertMessage($.isRecording(), "actively recording again after resume");

	$.pauseRecording();
	$.stopRecording(false); // discard -- this is just a test run
	Test.assertMessage(!$.hasActiveSession(), "session gone after stopRecording()");
	Test.assertMessage(!$.isRecording(), "not recording after stopRecording()");
	Test.assertMessage(!$.shouldSaveOnStop($.hasActiveSession(), $.isRecording()), "after discard, onStop() must have nothing to save");

	return true;
}

// onStop() rule: an app closed by the system must keep whatever was
// recorded. The user's own Save/Ignore choices null the
// session before System.exit(), so they never reach this rule with a session.
(:test)
function testShouldSaveOnStop(logger)
{
	Test.assertMessage($.shouldSaveOnStop(true, true), "recording in progress -> save");
	Test.assertMessage($.shouldSaveOnStop(true, false), "session paused -> save");
	Test.assertMessage(!$.shouldSaveOnStop(false, false), "no session -> nothing to save");

	// Edge cases: incoherent or missing inputs must never ask for a save.
	Test.assertMessage(!$.shouldSaveOnStop(false, true), "isRecording without a session is incoherent -> no save");
	Test.assertMessage(!$.shouldSaveOnStop(null, null), "null inputs -> no save");
	Test.assertMessage(!$.shouldSaveOnStop(null, true), "null hasSession -> no save");
	Test.assertMessage($.shouldSaveOnStop(true, null), "session exists, unknown recording state -> still save");

	return true;
}

(:test)
function testStopRecordingSaveWithoutSessionIsNoOp(logger)
{
	if ($.hasActiveSession())
	{
		$.stopRecording(false);
	}
	Test.assertMessage(!$.hasActiveSession(), "precondition: no session");

	// Must not throw: this is what onStop() would hit if the rule were bypassed.
	$.stopRecording(true);
	Test.assertMessage(!$.hasActiveSession(), "still no session after stopRecording(true)");
	Test.assertMessage(!$.isRecording(), "still not recording after stopRecording(true)");

	// Calling it twice is just as harmless.
	$.stopRecording(true);
	Test.assertMessage(!$.hasActiveSession(), "still no session after a second stopRecording(true)");

	return true;
}

// End-to-end of the path onStop() now takes for a paused session: the rule
// says save, and saving a paused (already stopped) session must work and
// clear the session. Note: leaves one short saved activity in the simulator.
(:test)
function testStopRecordingSavesPausedSession(logger)
{
	if ($.hasActiveSession())
	{
		$.stopRecording(false);
	}

	$.startRecording();
	$.pauseRecording();
	Test.assertMessage($.hasActiveSession() && !$.isRecording(), "precondition: paused session");
	Test.assertMessage($.shouldSaveOnStop($.hasActiveSession(), $.isRecording()), "rule asks to save a paused session");

	$.stopRecording(true);
	Test.assertMessage(!$.hasActiveSession(), "session cleared after save");
	Test.assertMessage(!$.isRecording(), "not recording after save");

	return true;
}

// Same path for a session still actively recording (no pause): stopRecording(true)
// must take the isRecording branch (stop, then save) and clear the session.
// Note: leaves one short saved activity in the simulator.
(:test)
function testStopRecordingSavesRecordingSession(logger)
{
	if ($.hasActiveSession())
	{
		$.stopRecording(false);
	}

	$.startRecording();
	Test.assertMessage($.hasActiveSession() && $.isRecording(), "precondition: actively recording session");
	Test.assertMessage($.shouldSaveOnStop($.hasActiveSession(), $.isRecording()), "rule asks to save a recording session");

	$.stopRecording(true);
	Test.assertMessage(!$.hasActiveSession(), "session cleared after stop + save");
	Test.assertMessage(!$.isRecording(), "not recording after stop + save");

	return true;
}

// ---------------------------------------------------------------------------
// Recording sport: SPORT_FLYING where the device has it, SPORT_GENERIC
// otherwise (fenix5 / fenix5x, CIQ 3.1.6, have no Activity.SPORT_* at all).
// ---------------------------------------------------------------------------

(:test)
function testPickRecordingSport(logger)
{
	Test.assertEqualMessage($.pickRecordingSport(true), 20, "device has SPORT_FLYING -> FIT sport 20 (flying)");
	Test.assertEqualMessage($.pickRecordingSport(false), 0, "device without SPORT_FLYING -> FIT sport 0 (generic)");

	// Edge case: an unknown capability must fall back to the sport every device has.
	Test.assertEqualMessage($.pickRecordingSport(null), 0, "null capability -> generic");

	return true;
}

// The numeric codes used by pickRecordingSport() must be the API's own values
// wherever the API exposes them. Every access is guarded by `has`, so this test
// also proves the guarded access itself runs on a device without Activity.SPORT_*.
(:test)
function testRecordingSportCodesMatchApi(logger)
{
	var hasFlying = Activity has :SPORT_FLYING;
	logger.debug("Activity has :SPORT_FLYING -> " + hasFlying + ", recording sport " + $.pickRecordingSport(hasFlying));

	if (hasFlying)
	{
		Test.assertEqualMessage(Activity.SPORT_FLYING, $.RECORDING_SPORT_FLYING, "flying code must match Activity.SPORT_FLYING");
	}
	if (Activity has :SPORT_GENERIC)
	{
		Test.assertEqualMessage(Activity.SPORT_GENERIC, $.RECORDING_SPORT_GENERIC, "generic code must match Activity.SPORT_GENERIC");
	}
	else
	{
		// Pre-3.2.0 devices: the sport enum only lives in ActivityRecording.
		Test.assertMessage(ActivityRecording has :SPORT_GENERIC, "pre-3.2.0 device should expose ActivityRecording.SPORT_GENERIC");
		Test.assertEqualMessage(ActivityRecording.SPORT_GENERIC, $.RECORDING_SPORT_GENERIC, "generic code must match ActivityRecording.SPORT_GENERIC");
	}

	// The two codes must differ, otherwise the fallback would be invisible.
	Test.assertMessage($.RECORDING_SPORT_FLYING != $.RECORDING_SPORT_GENERIC, "flying and generic codes differ");

	return true;
}

// ---------------------------------------------------------------------------
// HikeHistory: hike-mode vertical speed / speed over a sliding window.
// All series use injected timestamps (no System.getTimer()), 1 sample / 5 s
// unless stated otherwise. Rates: 600 m/h = 1/6 m/s, 1200 m/h = 1/3 m/s.
// ---------------------------------------------------------------------------

// Steady 600 m/h climb over 120 s, timestamps near the top of the
// System.getTimer() range to check the maths works on relative time.
(:test)
function testHikeHistoryConstantClimb(logger)
{
	var h = new HikeHistory();
	var t0 = 2000000000;
	for (var s = 0; s <= 120; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0 + s / 6.0, null);
	}
	Test.assertEqualMessage(h.getCount(), 25, "25 samples in 120 s at 1 / 5 s");

	var v = h.verticalSpeedMh(t0 + 120000, 60000);
	logger.debug("constant climb 600 m/h -> " + v);
	Test.assertMessage(v != null && v > 599.0 && v < 601.0, "600 m/h climb should read 600 +/- 1, got " + v);
	return true;
}

// Same climb, altitude quantised to 0.2 m (like the barometer) plus an
// alternating +/-0.2 m noise.
(:test)
function testHikeHistoryNoisyClimb(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;
	for (var i = 0; i <= 24; i++)
	{
		var s = i * 5;
		var quantised = (s / 6.0 / 0.2).toNumber() * 0.2;
		var noise = (i % 2 == 0) ? 0.2 : -0.2;
		h.add(t0 + s * 1000, 1500.0 + quantised + noise, null);
	}

	var v = h.verticalSpeedMh(t0 + 120000, 60000);
	logger.debug("noisy climb 600 m/h -> " + v);
	Test.assertMessage(v != null && v > 570.0 && v < 630.0, "noisy 600 m/h climb should read 600 +/- 30, got " + v);
	return true;
}

(:test)
function testHikeHistoryFlat(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;
	for (var s = 0; s <= 120; s += 5)
	{
		h.add(t0 + s * 1000, 2250.0, null);
	}

	var v = h.verticalSpeedMh(t0 + 120000, 60000);
	Test.assertMessage(v != null && v > -5.0 && v < 5.0, "constant altitude should read 0 +/- 5, got " + v);
	return true;
}

(:test)
function testHikeHistoryDescent(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;
	for (var s = 0; s <= 120; s += 5)
	{
		h.add(t0 + s * 1000, 2500.0 - s / 3.0, null);
	}

	var v = h.verticalSpeedMh(t0 + 120000, 60000);
	logger.debug("descent 1200 m/h -> " + v);
	Test.assertMessage(v != null && v > -1205.0 && v < -1195.0, "1200 m/h descent should read -1200 +/- 5, got " + v);
	return true;
}

// 60 s of climbing then 60 s flat: the 60 s window must only see the flat part.
(:test)
function testHikeHistoryClimbThenFlat(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;
	for (var s = 0; s <= 120; s += 5)
	{
		var alt = (s <= 60) ? 1500.0 + s / 6.0 : 1510.0;
		h.add(t0 + s * 1000, alt, null);
	}

	var v = h.verticalSpeedMh(t0 + 120000, 60000);
	Test.assertMessage(v != null && v > -30.0 && v < 30.0, "60 s window after the climb should read |v| < 30, got " + v);
	return true;
}

(:test)
function testHikeHistoryNotEnoughData(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;

	Test.assertMessage(h.verticalSpeedMh(t0, 60000) == null, "empty history -> null");
	Test.assertMessage(h.speedMps(t0, 60000) == null, "empty history -> null speed");

	h.add(t0, 1500.0, 100.0);
	Test.assertMessage(h.verticalSpeedMh(t0, 60000) == null, "a single point -> null");
	Test.assertMessage(h.speedMps(t0, 60000) == null, "a single point -> null speed");

	// 4 points spanning 15 s: enough points but not enough time.
	for (var s = 5; s <= 15; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0 + s / 6.0, 100.0 + s);
	}
	Test.assertEqualMessage(h.getCount(), 4, "precondition: 4 samples");
	Test.assertMessage(h.verticalSpeedMh(t0 + 15000, 60000) == null, "15 s of data -> null");
	Test.assertMessage(h.speedMps(t0 + 15000, 60000) == null, "15 s of data -> null speed");
	return true;
}

// Minimum-coverage edges: exactly 20 s with 3 points is enough, 19.999 s is not.
(:test)
function testHikeHistoryMinimumCoverageEdges(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;
	h.add(t0, 1500.0, 0.0);
	h.add(t0 + 10000, 1500.0 + 10 / 6.0, 10.0);
	h.add(t0 + 20000, 1500.0 + 20 / 6.0, 20.0);
	var v = h.verticalSpeedMh(t0 + 20000, 60000);
	Test.assertMessage(v != null && v > 599.0 && v < 601.0, "3 points over exactly 20 s -> 600, got " + v);
	var sp = h.speedMps(t0 + 20000, 60000);
	Test.assertMessage(sp != null && sp > 0.99 && sp < 1.01, "3 points over exactly 20 s -> 1 m/s, got " + sp);

	h.reset();
	h.add(t0, 1500.0, 0.0);
	h.add(t0 + 9999, 1501.0, 10.0);
	h.add(t0 + 19999, 1502.0, 20.0);
	Test.assertEqualMessage(h.getCount(), 3, "precondition: 3 samples");
	Test.assertMessage(h.verticalSpeedMh(t0 + 19999, 60000) == null, "19.999 s of data -> null");
	Test.assertMessage(h.speedMps(t0 + 19999, 60000) == null, "19.999 s of data -> null speed");

	// The window start is inclusive: t >= nowMs - windowMs. Samples at 0, 10, 20 s
	// read at now = 60 s with a 60 s window keep all three; 1 ms later the 0 s
	// sample drops out, leaving 2 points over 10 s -> null.
	h.reset();
	h.add(t0, 1500.0, 0.0);
	h.add(t0 + 10000, 1500.0 + 10 / 6.0, 10.0);
	h.add(t0 + 20000, 1500.0 + 20 / 6.0, 20.0);
	v = h.verticalSpeedMh(t0 + 60000, 60000);
	Test.assertMessage(v != null && v > 599.0 && v < 601.0, "sample exactly at nowMs - windowMs is included, got " + v);
	Test.assertMessage(h.verticalSpeedMh(t0 + 60001, 60000) == null, "one ms later the first sample leaves the window -> null");
	return true;
}

// A gap of more than 15 s (pause, lost data) resets the history.
(:test)
function testHikeHistoryGapResets(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;
	for (var s = 0; s <= 120; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0 + s / 6.0, 100.0 + s);
	}
	Test.assertMessage(h.verticalSpeedMh(t0 + 120000, 60000) != null, "precondition: valid speed before the gap");

	h.add(t0 + 140000, 1530.0, 250.0);
	Test.assertEqualMessage(h.getCount(), 1, "20 s gap -> history restarts from the new sample");
	Test.assertMessage(h.verticalSpeedMh(t0 + 140000, 60000) == null, "right after a 20 s gap -> null");
	Test.assertMessage(h.speedMps(t0 + 140000, 60000) == null, "right after a 20 s gap -> null speed");
	return true;
}

(:test)
function testHikeHistorySampleSpacing(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;

	h.add(t0, 1500.0, 0.0);
	Test.assertEqualMessage(h.getCount(), 1, "first sample stored");

	h.add(t0 + 4999, 1501.0, 5.0);
	Test.assertEqualMessage(h.getCount(), 1, "sample < 5 s after the previous one is ignored");

	h.add(t0 + 5000, 1501.0, 5.0);
	Test.assertEqualMessage(h.getCount(), 2, "sample exactly 5000 ms later is accepted");

	// The ignored 4999 ms sample must not have moved the reference time:
	// 5000 ms after the accepted one is accepted again.
	h.add(t0 + 10000, 1502.0, 10.0);
	Test.assertEqualMessage(h.getCount(), 3, "spacing is measured from the last accepted sample");

	h.add(t0 + 13000, null, 13.0);
	Test.assertEqualMessage(h.getCount(), 3, "null altitude is ignored (< 5 s anyway)");
	h.add(t0 + 16000, null, 16.0);
	Test.assertEqualMessage(h.getCount(), 3, "null altitude is ignored even when due");

	h.add(t0 + 25000, 1503.0, 25.0);
	Test.assertEqualMessage(h.getCount(), 4, "exactly 15000 ms later: accepted without reset");

	h.add(t0 + 40001, 1504.0, 40.0);
	Test.assertEqualMessage(h.getCount(), 1, "15001 ms later: reset, then the sample is kept");

	// Null altitude never resets nor feeds the history, even after a long gap.
	h.add(t0 + 90000, null, 90.0);
	Test.assertEqualMessage(h.getCount(), 1, "null altitude after a gap: ignored, no reset");

	// Time going backwards (timer restarted) is treated like a gap: reset.
	h.add(t0 + 45001, 1505.0, 45.0);
	Test.assertEqualMessage(h.getCount(), 2, "precondition: 2 samples");
	h.add(t0 + 1000, 1506.0, 46.0);
	Test.assertEqualMessage(h.getCount(), 1, "timestamp going backwards -> reset, sample kept");
	return true;
}

(:test)
function testHikeHistoryReset(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;
	for (var s = 0; s <= 60; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0 + s / 6.0, 100.0 + s);
	}
	h.reset();
	Test.assertEqualMessage(h.getCount(), 0, "reset() empties the buffer");
	Test.assertMessage(h.verticalSpeedMh(t0 + 60000, 60000) == null, "no vertical speed after reset()");
	Test.assertMessage(h.speedMps(t0 + 60000, 60000) == null, "no speed after reset()");

	// After reset, the next sample is accepted whatever its timing.
	h.add(t0 + 61000, 1510.0, 161.0);
	Test.assertEqualMessage(h.getCount(), 1, "first sample after reset() accepted even 1 s later");
	return true;
}

(:test)
function testHikeHistorySpeed(logger)
{
	var t0 = 3600000;

	var h = new HikeHistory();
	for (var s = 0; s <= 120; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0, 2000.0 + 1.04 * s);
	}
	var sp = h.speedMps(t0 + 120000, 60000);
	logger.debug("speed 1.04 m/s -> " + sp);
	Test.assertMessage(sp != null && sp > 1.03 && sp < 1.05, "1.04 m/s should read 1.04 +/- 0.01, got " + sp);

	h = new HikeHistory();
	for (var s = 0; s <= 120; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0 + s / 6.0, 2000.0);
	}
	sp = h.speedMps(t0 + 120000, 60000);
	Test.assertMessage(sp != null && sp > -0.001 && sp < 0.001, "constant distance should read 0, got " + sp);

	h = new HikeHistory();
	for (var s = 0; s <= 120; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0 + s / 6.0, null);
	}
	Test.assertMessage(h.speedMps(t0 + 120000, 60000) == null, "no distance at all (no session) -> null speed");
	var v = h.verticalSpeedMh(t0 + 120000, 60000);
	Test.assertMessage(v != null && v > 599.0 && v < 601.0, "vertical speed still works without distance, got " + v);
	return true;
}

// Samples with and without distance mixed (session started mid-way, or dist
// momentarily missing): speed only uses the samples that carry a distance.
(:test)
function testHikeHistoryMixedNullDistance(logger)
{
	var t0 = 3600000;

	// Every other sample without distance.
	var h = new HikeHistory();
	for (var i = 0; i <= 24; i++)
	{
		var s = i * 5;
		h.add(t0 + s * 1000, 1500.0 + s / 6.0, (i % 2 == 0) ? 2000.0 + 1.04 * s : null);
	}
	var sp = h.speedMps(t0 + 120000, 60000);
	Test.assertMessage(sp != null && sp > 1.03 && sp < 1.05, "alternate null distances -> 1.04 +/- 0.01, got " + sp);
	var v = h.verticalSpeedMh(t0 + 120000, 60000);
	Test.assertMessage(v != null && v > 599.0 && v < 601.0, "vertical speed uses every sample, got " + v);

	// Distance only on the last two samples of the window: < 3 usable points.
	h = new HikeHistory();
	for (var s = 0; s <= 120; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0, (s >= 115) ? 2000.0 + 1.04 * s : null);
	}
	Test.assertMessage(h.speedMps(t0 + 120000, 60000) == null, "only 2 samples with distance -> null speed");

	// Distance on the last 3 samples only (10 s): enough points, not enough time.
	h = new HikeHistory();
	for (var s = 0; s <= 120; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0, (s >= 110) ? 2000.0 + 1.04 * s : null);
	}
	Test.assertMessage(h.speedMps(t0 + 120000, 60000) == null, "distance over 10 s only -> null speed");

	// Distance appears 40 s before now (session started): speed over those 40 s.
	h = new HikeHistory();
	for (var s = 0; s <= 120; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0, (s >= 80) ? 1.04 * (s - 80) : null);
	}
	sp = h.speedMps(t0 + 120000, 60000);
	Test.assertMessage(sp != null && sp > 1.03 && sp < 1.05, "distance on the last 40 s only -> 1.04, got " + sp);
	return true;
}

// System.getTimer() wraps past 2^31 ms (~24.8 days) to negative values;
// Monkey C Number arithmetic wraps the same way, so t0 + s * 1000 below
// reproduces it. Window and spacing checks must use differences.
(:test)
function testHikeHistoryTimerWrapAround(logger)
{
	// Wraps 3.6 s after the first sample: the 60 s window is entirely after
	// the wrap, the flat samples before it must be excluded.
	var h = new HikeHistory();
	var t0 = 2147480000;
	for (var s = 0; s <= 120; s += 5)
	{
		var alt = (s < 60) ? 1500.0 : 1500.0 + (s - 60) / 6.0;
		h.add(t0 + s * 1000, alt, 1.0 * s);
	}
	var now = t0 + 120000;
	Test.assertMessage(now < 0, "precondition: the timer has wrapped to a negative value");
	Test.assertEqualMessage(h.getCount(), 25, "no reset when the timer wraps");
	var v = h.verticalSpeedMh(now, 60000);
	logger.debug("wrap at 3.6 s -> " + v);
	Test.assertMessage(v != null && v > 599.0 && v < 601.0, "60 s window after the wrap: 600 +/- 1 (flat samples excluded), got " + v);
	var sp = h.speedMps(now, 60000);
	Test.assertMessage(sp != null && sp > 0.99 && sp < 1.01, "speed after the wrap, got " + sp);
	var v300 = h.verticalSpeedMh(now, 300000);
	Test.assertMessage(v300 != null && v300 > 0.0 && v300 < 590.0, "300 s window still sees the flat part, got " + v300);

	// Wrap in the middle of the 60 s window (at 90 s): steady climb.
	h = new HikeHistory();
	t0 = 2147483647 - 90000;
	for (var s = 0; s <= 120; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0 + s / 6.0, 1.04 * s);
	}
	now = t0 + 120000;
	Test.assertEqualMessage(h.getCount(), 25, "no reset across the wrap");
	v = h.verticalSpeedMh(now, 60000);
	Test.assertMessage(v != null && v > 599.0 && v < 601.0, "wrap inside the window: 600 +/- 1, got " + v);
	sp = h.speedMps(now, 60000);
	Test.assertMessage(sp != null && sp > 1.03 && sp < 1.05, "wrap inside the window: 1.04 m/s, got " + sp);
	return true;
}

// Series starting 1 s after the timer wrapped to -2^31: with a 300 s window,
// nowMs - windowMs would go below -2^31 and overflow to a large positive
// value if computed directly, excluding every sample.
(:test)
function testHikeHistoryWindowStartWouldOverflow(logger)
{
	var h = new HikeHistory();
	var t0 = -2147482648;
	// Read at 60 s while the history only holds the first (flat) minute,
	// as in the app where no sample is newer than nowMs.
	for (var s = 0; s <= 60; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0, 1.0 * s);
	}
	var v = h.verticalSpeedMh(t0 + 60000, 300000);
	Test.assertMessage(v != null && v > -5.0 && v < 5.0, "flat first minute, 300 s window read at 60 s, got " + v);

	for (var s = 65; s <= 120; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0 + (s - 60) / 3.0, 1.0 * s);
	}
	Test.assertEqualMessage(h.getCount(), 25, "precondition: 25 samples");

	var now = t0 + 120000;
	v = h.verticalSpeedMh(now, 60000);
	Test.assertMessage(v != null && v > 1195.0 && v < 1205.0, "1200 m/h second minute (no overflow case), got " + v);
	var v300 = h.verticalSpeedMh(now, 300000);
	Test.assertMessage(v300 != null && v300 > 0.0 && v300 < 1200.0, "300 s window sees the whole series, got " + v300);
	var sp = h.speedMps(now, 300000);
	Test.assertMessage(sp != null && sp > 0.99 && sp < 1.01, "300 s window speed 1 m/s, got " + sp);
	return true;
}

// Distance going down between window start and end (a new session restarted
// elapsedDistance): no negative speed, null instead.
(:test)
function testHikeHistoryDistanceDecreases(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;
	for (var s = 0; s <= 120; s += 5)
	{
		var dist = (s <= 60) ? 2000.0 + 1.04 * s : 1.04 * (s - 65);
		h.add(t0 + s * 1000, 1500.0, dist);
	}
	Test.assertMessage(h.speedMps(t0 + 120000, 60000) == null, "distance restarted inside the window -> null speed");
	var sp = h.speedMps(t0 + 120000, 55000);
	Test.assertMessage(sp != null && sp > 1.03 && sp < 1.05, "window after the restart -> 1.04 m/s, got " + sp);
	return true;
}

// More than 60 samples: the oldest are overwritten and must no longer count.
// First 20 samples descend fast, the next 60 climb at 600 m/h; with a window
// wider than the buffer, only the 60 climbing samples may be used.
(:test)
function testHikeHistoryRingBufferOverflow(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;
	var alt = 2000.0;
	var dist = 0.0;
	for (var i = 0; i < 80; i++)
	{
		if (i > 0)
		{
			alt += (i < 20) ? -5.0 : 5.0 / 6.0;
			dist += (i < 20) ? 50.0 : 5.0;
		}
		h.add(t0 + i * 5000, alt, dist);
	}
	Test.assertEqualMessage(h.getCount(), 60, "count caps at 60 samples");

	var now = t0 + 79 * 5000;
	var v = h.verticalSpeedMh(now, 1000000);
	Test.assertMessage(v != null && v > 599.0 && v < 601.0, "overwritten descent samples must be gone, got " + v);
	var sp = h.speedMps(now, 1000000);
	Test.assertMessage(sp != null && sp > 0.99 && sp < 1.01, "speed only from retained samples (1 m/s), got " + sp);

	// And the usual 60 s window still reads right after wrapping around.
	v = h.verticalSpeedMh(now, 60000);
	Test.assertMessage(v != null && v > 599.0 && v < 601.0, "60 s window after wrap-around, got " + v);
	return true;
}

// The 5 min window (300 s) used for the averaged display.
(:test)
function testHikeHistoryWindow300s(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;
	// 4 min flat then 1 min at 1200 m/h: +20 m in the last minute.
	for (var s = 0; s <= 300; s += 5)
	{
		var alt = (s <= 240) ? 1500.0 : 1500.0 + (s - 240) / 3.0;
		h.add(t0 + s * 1000, alt, 1.0 * s);
	}
	var now = t0 + 300000;

	var v60 = h.verticalSpeedMh(now, 60000);
	Test.assertMessage(v60 != null && v60 > 1195.0 && v60 < 1205.0, "60 s window sees the 1200 m/h climb, got " + v60);

	var v300 = h.verticalSpeedMh(now, 300000);
	logger.debug("300 s window -> " + v300);
	Test.assertMessage(v300 != null && v300 > 0.0 && v300 < 600.0, "300 s window smooths the late climb (0 < v < 600), got " + v300);

	var sp = h.speedMps(now, 300000);
	Test.assertMessage(sp != null && sp > 0.99 && sp < 1.01, "300 s window speed 1 m/s, got " + sp);

	// Steady 600 m/h over the full 5 min.
	h.reset();
	for (var s = 0; s <= 300; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0 + s / 6.0, null);
	}
	var v = h.verticalSpeedMh(now, 300000);
	Test.assertMessage(v != null && v > 599.0 && v < 601.0, "600 m/h over 300 s, got " + v);
	return true;
}

// Real data: Salvan outing, 13/09/2026, lap 1 (climb), from
// garmin_data/activity_24346302742.tcx, 11:07:11 -> 11:09:21 UTC (TCX lines
// 16806-17832). The TCX is smart-recorded (1-4 s irregular spacing); samples
// kept here follow add()'s own rule: first record >= 5 s after the last kept
// one. 11:07:11 is the first record after a 37 s stop (11:06:34), which would
// reset the history anyway. Columns: seconds since 11:07:11, AltitudeMeters,
// DistanceMeters.
(:test)
function testHikeHistorySalvanRealClimb(logger)
{
	var secs = [0, 7, 14, 20, 25, 30, 35, 41, 46, 51, 57, 62,
		70, 76, 81, 87, 92, 97, 102, 107, 113, 118, 124, 130];
	var alts = [2249.0, 2249.8, 2251.0, 2251.4, 2251.8, 2253.0, 2253.4, 2254.0,
		2255.0, 2255.4, 2255.4, 2255.4, 2256.4, 2257.6, 2258.8, 2260.4,
		2261.4, 2262.6, 2263.8, 2265.2, 2266.0, 2266.4, 2267.6, 2268.6];
	var dists = [2232.68, 2241.07, 2246.74, 2248.84, 2252.27, 2254.52, 2258.45, 2263.16,
		2267.93, 2275.91, 2285.28, 2291.61, 2300.57, 2302.97, 2307.71, 2314.88,
		2318.73, 2324.05, 2327.65, 2331.63, 2338.11, 2342.33, 2346.54, 2351.20];

	var h = new HikeHistory();
	var t0 = 3600000;
	var at1108_48 = 17; // index of 11:08:48 (97 s)
	for (var i = 0; i <= at1108_48; i++)
	{
		h.add(t0 + secs[i] * 1000, alts[i], dists[i]);
	}
	Test.assertEqualMessage(h.getCount(), at1108_48 + 1, "every real sample kept (all >= 5 s apart, no gap > 15 s)");

	// 60 s window 11:07:48 -> 11:08:48 (includes the short flat at 11:08:02-13).
	// Hand-computed least squares: ~524 m/h. Speed: 60.89 m / 56 s = 1.087 m/s.
	var v = h.verticalSpeedMh(t0 + 97000, 60000);
	logger.debug("Salvan 60 s window at 11:08:48 -> " + v + " m/h");
	Test.assertMessage(v != null && v >= 500.0 && v <= 700.0, "real Salvan climb at 11:08:48 should read 500-700 m/h, got " + v);
	var sp = h.speedMps(t0 + 97000, 60000);
	logger.debug("Salvan 60 s speed at 11:08:48 -> " + sp + " m/s");
	Test.assertMessage(sp != null && sp > 1.077 && sp < 1.097, "real Salvan speed at 11:08:48 ~1.087 m/s, got " + sp);

	for (var i = at1108_48 + 1; i < secs.size(); i++)
	{
		h.add(t0 + secs[i] * 1000, alts[i], dists[i]);
	}
	Test.assertEqualMessage(h.getCount(), secs.size(), "all 24 real samples kept");

	// Whole 2 min 10 s extract (300 s window): hand-computed ~543 m/h,
	// speed 118.52 m / 130 s = 0.912 m/s.
	var now = t0 + 130000;
	var v300 = h.verticalSpeedMh(now, 300000);
	logger.debug("Salvan whole extract (300 s window) -> " + v300 + " m/h");
	Test.assertMessage(v300 != null && v300 >= 500.0 && v300 <= 700.0, "whole real extract should read 500-700 m/h, got " + v300);
	sp = h.speedMps(now, 300000);
	Test.assertMessage(sp != null && sp > 0.902 && sp < 0.922, "whole real extract speed ~0.912 m/s, got " + sp);

	// Last minute 11:08:21 -> 11:09:21 is steeper: hand-computed ~747 m/h.
	var v60 = h.verticalSpeedMh(now, 60000);
	logger.debug("Salvan 60 s window at 11:09:21 -> " + v60 + " m/h");
	Test.assertMessage(v60 != null && v60 > 720.0 && v60 < 780.0, "real Salvan last minute should read ~747 m/h, got " + v60);
	return true;
}

// ---------------------------------------------------------------------------
// Hike vertical speed wiring (Marche 1b): display format, pause rule, and
// WatchData feeding its HikeHistory from getAltitude() / getDistance().
// ---------------------------------------------------------------------------

// Rounded to 10 m/h, "+" only when the rounded value is positive, "--" when
// there is no value. Halves round away from zero, symmetrically.
(:test)
function testFormatVerticalSpeed(logger)
{
	// Spec values.
	Test.assertEqualMessage($.formatVerticalSpeed(null), "--", "null -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(636.4), "+640", "636.4 -> +640");
	Test.assertEqualMessage($.formatVerticalSpeed(-129.0), "-130", "-129.0 -> -130");
	Test.assertEqualMessage($.formatVerticalSpeed(0.0), "0", "0.0 -> 0");

	// Rounding boundaries: exactly half a step goes away from zero, just
	// under it goes to 0, and a value that rounds to 0 never shows "+0"/"-0".
	Test.assertEqualMessage($.formatVerticalSpeed(5.0), "+10", "5.0 -> +10");
	Test.assertEqualMessage($.formatVerticalSpeed(-5.0), "-10", "-5.0 -> -10");
	Test.assertEqualMessage($.formatVerticalSpeed(4.9), "0", "4.9 -> 0");
	Test.assertEqualMessage($.formatVerticalSpeed(-4.9), "0", "-4.9 -> 0 (no -0)");
	Test.assertEqualMessage($.formatVerticalSpeed(-0.0), "0", "-0.0 -> 0");
	Test.assertEqualMessage($.formatVerticalSpeed(14.9), "+10", "14.9 -> +10");
	Test.assertEqualMessage($.formatVerticalSpeed(15.0), "+20", "15.0 -> +20");
	Test.assertEqualMessage($.formatVerticalSpeed(-15.0), "-20", "-15.0 -> -20");
	Test.assertEqualMessage($.formatVerticalSpeed(645.0), "+650", "645.0 -> +650");
	Test.assertEqualMessage($.formatVerticalSpeed(-1195.0), "-1200", "-1195.0 -> -1200");

	// Integer input (Number) is accepted too.
	Test.assertEqualMessage($.formatVerticalSpeed(600), "+600", "Number 600 -> +600");
	Test.assertEqualMessage($.formatVerticalSpeed(-7), "-10", "Number -7 -> -10");
	Test.assertEqualMessage($.formatVerticalSpeed(0), "0", "Number 0 -> 0");

	// Very large values (altitude glitch) must not overflow a 32-bit Number.
	Test.assertEqualMessage($.formatVerticalSpeed(1000000.0), "+1000000", "1e6 -> +1000000");
	Test.assertEqualMessage($.formatVerticalSpeed(-1000000.0), "-1000000", "-1e6 -> -1000000");
	Test.assertEqualMessage($.formatVerticalSpeed(1.0e10), "+10000000000", "1e10 -> no 32-bit overflow");

	// NaN is not a speed: show "--" rather than garbage. (A Float division
	// 0.0 / 0.0 throws in Monkey C, so NaN is built from sqrt of a negative.)
	var nan = Toybox.Math.sqrt(-1.0);
	logger.debug("NaN candidate: " + nan);
	Test.assertEqualMessage($.formatVerticalSpeed(nan), "--", "NaN -> --");

	// +/-Infinity is not a speed either: "--". Built at run time by overflowing
	// a 32-bit Float (max ~3.4e38) rather than dividing by 0.0, which may throw.
	var big = 3.0e38;
	var inf = big * 10.0;
	var negInf = -big * 10.0;
	Test.assertMessage(inf > big && inf == inf * 2.0, "test setup: +Inf expected, got " + inf);
	Test.assertMessage(negInf < -big && negInf == negInf * 2.0, "test setup: -Inf expected, got " + negInf);
	Test.assertEqualMessage($.formatVerticalSpeed(inf), "--", "+Inf -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(negInf), "--", "-Inf -> --");
	// Largest finite Float still formats as a number (guard must not catch it).
	Test.assertMessage(!$.formatVerticalSpeed(big).equals("--"), "3e38 is finite -> not --");
	return true;
}

// onSensor() must not feed the hike buffer while a session is paused
// (hasSession && !isRecording); before any session and while recording it does.
(:test)
function testShouldRecordHikeSample(logger)
{
	Test.assertMessage($.shouldRecordHikeSample(false, false), "no session yet -> record");
	Test.assertMessage($.shouldRecordHikeSample(true, true), "recording -> record");
	Test.assertMessage(!$.shouldRecordHikeSample(true, false), "paused -> do not record");

	// Edge cases.
	Test.assertMessage($.shouldRecordHikeSample(false, true), "isRecording without a session is incoherent -> treated as no session -> record");
	Test.assertMessage($.shouldRecordHikeSample(null, null), "null inputs -> treated as no session -> record");
	Test.assertMessage($.shouldRecordHikeSample(null, false), "null hasSession -> record");
	Test.assertMessage(!$.shouldRecordHikeSample(true, null), "session with unknown recording state -> treated as paused -> do not record");
	return true;
}

// recordHikeSampleAt() reads getAltitude() / getDistance() (activityData
// simulated, as in testWatchDataAccessorsFallBackToActivityData) and the
// getters use a 60 s window.
(:test)
function testWatchDataRecordHikeSample(logger)
{
	var data = new WatchData();
	var t0 = 1000000;

	// No data at all: nothing recorded, no speeds.
	data.recordHikeSampleAt(t0);
	Test.assertEqualMessage(data.hikeHistory.getCount(), 0, "no altitude -> no sample");
	Test.assertMessage(data.getHikeVerticalSpeedAt(t0) == null, "empty -> vertical speed null");
	Test.assertMessage(data.getHikeSpeedAt(t0) == null, "empty -> speed null");

	// Altitude key present but null (Activity.Info.altitude can be null).
	data.activityData = { "altitude" => null, "distance" => 10.0 };
	data.recordHikeSampleAt(t0);
	Test.assertEqualMessage(data.hikeHistory.getCount(), 0, "null altitude -> no sample");

	// 600 m/h climb at 1 m/s, one call per second (like onSensor) for 120 s:
	// the buffer keeps one sample every 5 s.
	for (var s = 0; s <= 120; s++)
	{
		data.activityData = { "altitude" => 1500.0 + s / 6.0, "distance" => 100.0 + s };
		data.recordHikeSampleAt(t0 + s * 1000);
	}
	Test.assertEqualMessage(data.hikeHistory.getCount(), 25, "1 Hz calls -> 1 sample / 5 s over 120 s");

	var now = t0 + 120000;
	var v = data.getHikeVerticalSpeedAt(now);
	logger.debug("WatchData 600 m/h -> " + v);
	Test.assertMessage(v != null && v > 599.0 && v < 601.0, "600 m/h through WatchData, got " + v);
	var sp = data.getHikeSpeedAt(now);
	Test.assertMessage(sp != null && sp > 0.99 && sp < 1.01, "1 m/s through WatchData, got " + sp);

	// The getters use a 60 s window: last minute flat -> ~0, not the 120 s mix.
	for (var s = 125; s <= 180; s += 5)
	{
		data.activityData = { "altitude" => 1520.0, "distance" => 220.0 };
		data.recordHikeSampleAt(t0 + s * 1000);
	}
	var vFlat = data.getHikeVerticalSpeedAt(t0 + 180000);
	Test.assertMessage(vFlat != null && vFlat > -5.0 && vFlat < 5.0, "60 s window: flat last minute -> ~0, got " + vFlat);
	var spFlat = data.getHikeSpeedAt(t0 + 180000);
	Test.assertMessage(spFlat != null && spFlat < 0.01, "60 s window: no distance gained in last minute -> ~0, got " + spFlat);

	// The vario of flight is untouched by hike sampling.
	Test.assertMessage(data.oldAlt == null, "recordHikeSampleAt() must not touch oldAlt");
	Test.assertMessage(data.getVario() == null, "recordHikeSampleAt() must not touch the vario");
	return true;
}

// Before a session starts there is no elapsedDistance: vertical speed still
// works, speed stays null. Altitude falls back to sensorData like getAltitude().
(:test)
function testWatchDataRecordHikeSampleWithoutDistance(logger)
{
	var data = new WatchData();
	var t0 = 50000;
	for (var s = 0; s <= 60; s += 5)
	{
		data.sensorData = { "altitude" => 800.0 - s / 3.0 }; // -1200 m/h
		data.recordHikeSampleAt(t0 + s * 1000);
	}
	Test.assertEqualMessage(data.hikeHistory.getCount(), 13, "13 samples from sensorData altitude");
	var v = data.getHikeVerticalSpeedAt(t0 + 60000);
	Test.assertMessage(v != null && v > -1205.0 && v < -1195.0, "-1200 m/h from sensorData, got " + v);
	Test.assertMessage(data.getHikeSpeedAt(t0 + 60000) == null, "no distance -> speed null");

	// activityData altitude wins over sensorData, as in getAltitude().
	data.activityData = { "altitude" => 2000.0 };
	data.recordHikeSampleAt(t0 + 65000);
	Test.assertEqualMessage(data.hikeHistory.getCount(), 14, "activityData sample is the 14th sample");
	Test.assertEqualMessage(data.hikeHistory.alts[13], 2000.0, "altitude taken from activityData, not sensorData");
	return true;
}

// Same rule as onSensor(): pause stops sampling; on resume the >15 s gap
// resets the buffer, so the display shows "--" for ~20 s and never mixes
// before/after-pause samples (spec, point to decide n. 2).
(:test)
function testWatchDataHikeSamplingAcrossPause(logger)
{
	var data = new WatchData();
	var t0 = 200000;
	var hasSession = true;
	var recording = true;

	for (var s = 0; s <= 180; s++)
	{
		recording = !(s > 60 && s < 120); // paused from 61 s to 119 s
		data.activityData = { "altitude" => 1000.0 + s / 6.0, "distance" => s * 1.0 };
		if ($.shouldRecordHikeSample(hasSession, recording))
		{
			data.recordHikeSampleAt(t0 + s * 1000);
		}

		if (s == 60)
		{
			Test.assertMessage(data.getHikeVerticalSpeedAt(t0 + s * 1000) != null, "before the pause: value shown");
		}
		if (s == 119)
		{
			// Nothing recorded during the pause: the window has emptied.
			Test.assertMessage(data.getHikeVerticalSpeedAt(t0 + s * 1000) == null, "after a 60 s pause: -- (window empty)");
			Test.assertMessage($.formatVerticalSpeed(data.getHikeVerticalSpeedAt(t0 + s * 1000)).equals("--"), "pause -> displays --");
		}
		if (s == 120)
		{
			Test.assertEqualMessage(data.hikeHistory.getCount(), 1, "resume after > 15 s gap -> buffer reset to the first new sample");
			Test.assertMessage(data.getHikeVerticalSpeedAt(t0 + s * 1000) == null, "just after resume -> null");
		}
	}
	var v = data.getHikeVerticalSpeedAt(t0 + 180000);
	Test.assertMessage(v != null && v > 599.0 && v < 601.0, "60 s after resume: 600 m/h again, got " + v);
	return true;
}

// recordHikeSample() / getters with the real System.getTimer() clock: one
// sample only, so the speeds stay null; values must still be read through.
(:test)
function testWatchDataRecordHikeSampleUsesTimer(logger)
{
	var data = new WatchData();
	data.recordHikeSample();
	Test.assertEqualMessage(data.hikeHistory.getCount(), 0, "no altitude -> no sample with the real clock either");

	data.activityData = { "altitude" => 1234.5, "distance" => 42.0 };
	data.recordHikeSample();
	Test.assertEqualMessage(data.hikeHistory.getCount(), 1, "one sample recorded with System.getTimer()");
	Test.assertMessage(data.getHikeVerticalSpeed() == null, "one sample -> vertical speed null");
	Test.assertMessage(data.getHikeSpeed() == null, "one sample -> speed null");
	return true;
}

// Real Salvan extract (same rows as testHikeHistorySalvanRealClimb) fed
// through WatchData at 1 Hz, as onSensor() would: 11:07:11 -> 11:08:48.
(:test)
function testWatchDataHikeSalvanRealClimb(logger)
{
	var secs = [0, 7, 14, 20, 25, 30, 35, 41, 46, 51, 57, 62,
		70, 76, 81, 87, 92, 97];
	var alts = [2249.0, 2249.8, 2251.0, 2251.4, 2251.8, 2253.0, 2253.4, 2254.0,
		2255.0, 2255.4, 2255.4, 2255.4, 2256.4, 2257.6, 2258.8, 2260.4,
		2261.4, 2262.6];
	var dists = [2232.68, 2241.07, 2246.74, 2248.84, 2252.27, 2254.52, 2258.45, 2263.16,
		2267.93, 2275.91, 2285.28, 2291.61, 2300.57, 2302.97, 2307.71, 2314.88,
		2318.73, 2324.05];

	var data = new WatchData();
	var t0 = 3600000;
	var row = 0;
	// 1 Hz ticks; activityData holds the last TCX record, like the watch
	// between two recorded points.
	for (var s = 0; s <= 97; s++)
	{
		while (row + 1 < secs.size() && secs[row + 1] <= s)
		{
			row += 1;
		}
		data.activityData = { "altitude" => alts[row], "distance" => dists[row] };
		data.recordHikeSampleAt(t0 + s * 1000);
	}
	// Kept samples are the 5 s grid t = 0, 5, ..., 95; the 60 s window holds
	// t = 40..95 with the held TCX values (records at 35, 41, 46, 51, 57, 62,
	// 70, 70, 76, 81, 87, 92 s). Hand-computed least squares on those 12
	// points: sum(dt*da) = 468, sum(dt^2) = 3575 -> 468 / 3575 * 3600 =
	// 471.3 m/h. Lower than the 524 m/h of testHikeHistorySalvanRealClimb
	// because the window and the held values differ, same order of magnitude.
	var v = data.getHikeVerticalSpeedAt(t0 + 97000);
	logger.debug("WatchData Salvan 60 s at 11:08:48 -> " + v + " m/h, shown " + $.formatVerticalSpeed(v));
	Test.assertMessage(v != null && v > 470.3 && v < 472.3, "real Salvan climb through WatchData: hand-computed 471.3 m/h, got " + v);
	Test.assertEqualMessage($.formatVerticalSpeed(v), "+470", "real Salvan climb displayed as +470");
	// Speed: (2318.73 - 2258.45) m / 55 s = 1.096 m/s.
	var sp = data.getHikeSpeedAt(t0 + 97000);
	logger.debug("WatchData Salvan 60 s speed -> " + sp);
	Test.assertMessage(sp != null && sp > 1.086 && sp < 1.106, "real Salvan speed through WatchData ~1.096 m/s, got " + sp);
	return true;
}

// ---------------------------------------------------------------------------
// Speed keys written by WatchData.update*(): a null speed must not be stored,
// otherwise sensorData["speed"] = null hides the GPS speed in getSpeed().
// The update*() functions only use `info has :x` and `info.x`, so these
// minimal stand-ins exercise the real code without a Position/Activity/Sensor
// Info object. Fields missing here are simply skipped by the `has` checks.
// ---------------------------------------------------------------------------

(:test)
class FakePositionInfo
{
	var altitude = null;
	var speed = null;

	function initialize(alt, spd)
	{
		altitude = alt;
		speed = spd;
	}
}

(:test)
class FakeActivityInfo
{
	var altitude = null;
	var currentSpeed = null;
	var currentHeartRate = null;

	function initialize(alt, spd)
	{
		altitude = alt;
		currentSpeed = spd;
	}
}

(:test)
class FakeSensorInfo
{
	var altitude = null;
	var speed = null;
	var heartRate = null;

	function initialize(alt, spd)
	{
		altitude = alt;
		speed = spd;
	}
}

// Test helpers live in a (:test) class: a (:test) global function would be
// run by the test runner as a test.
(:test)
class SpeedTestHelper
{
	// One updateData() tick as in FlyInstrumentView, with injected Info values.
	// A null fake means "getInfo() returned null": that source is not updated.
	static function feedTick(data, posInfo, actInfo, sensInfo)
	{
		data.startMeasure();
		if (posInfo != null) { data.updateInfo(posInfo); }
		if (actInfo != null) { data.updateActivityInfo(actInfo); }
		if (sensInfo != null) { data.updateSensorInfo(sensInfo); }
	}

	// assertEqualMessage() throws on a null actual; this fails cleanly instead.
	static function assertSpeed(data, expected, msg)
	{
		var s = data.getSpeed();
		Test.assertMessage(s != null && s == expected, msg + " (expected " + expected + ", got " + s + ")");
	}
}

// Spec case: no sensor speed + GPS speed 1.5 -> getSpeed() = 1.5.
(:test)
function testWatchDataSpeedFallsBackToGpsWhenSensorSpeedNull(logger)
{
	// Hand-built dictionaries: the key is absent from sensorData.
	var data = new WatchData();
	data.sensorData = {};
	data.gpsData = { "speed" => 1.5 };
	Test.assertEqualMessage(data.getSpeed(), 1.5, "sensorData without speed key -> GPS speed");

	// Same case through the real update functions: Sensor.Info.speed is null.
	data = new WatchData();
	SpeedTestHelper.feedTick(data, new FakePositionInfo(1000.0, 1.5), null, new FakeSensorInfo(1000.0, null));
	SpeedTestHelper.assertSpeed(data, 1.5, "null sensor speed must not hide the GPS speed");
	Test.assertMessage(!data.sensorData.hasKey("speed"), "null sensor speed must not create a speed key");
	return true;
}

// Each of the 3 blocks: null -> no key; 0.0 is a real value and is kept;
// the altitude key is still written as before.
(:test)
function testWatchDataUpdatesSkipNullSpeedOnly(logger)
{
	var data = new WatchData();

	data.updateInfo(new FakePositionInfo(1200.0, null));
	Test.assertMessage(!data.gpsData.hasKey("speed"), "updateInfo: null speed not stored");
	Test.assertEqualMessage(data.gpsData["altitude"], 1200.0, "updateInfo: altitude still stored");
	data.updateInfo(new FakePositionInfo(1200.0, 0.0));
	Test.assertEqualMessage(data.gpsData["speed"], 0.0, "updateInfo: zero speed kept");

	data.updateActivityInfo(new FakeActivityInfo(1300.0, null));
	Test.assertMessage(!data.activityData.hasKey("speed"), "updateActivityInfo: null speed not stored");
	Test.assertEqualMessage(data.activityData["altitude"], 1300.0, "updateActivityInfo: altitude still stored");
	data.updateActivityInfo(new FakeActivityInfo(1300.0, 0.0));
	Test.assertEqualMessage(data.activityData["speed"], 0.0, "updateActivityInfo: zero speed kept");

	data.updateSensorInfo(new FakeSensorInfo(1400.0, null));
	Test.assertMessage(!data.sensorData.hasKey("speed"), "updateSensorInfo: null speed not stored");
	Test.assertEqualMessage(data.sensorData["altitude"], 1400.0, "updateSensorInfo: altitude still stored");
	data.updateSensorInfo(new FakeSensorInfo(1400.0, 0.0));
	Test.assertEqualMessage(data.sensorData["speed"], 0.0, "updateSensorInfo: zero speed kept");

	// All speeds null -> getSpeed() is null (nothing to show), not a crash.
	data = new WatchData();
	SpeedTestHelper.feedTick(data, new FakePositionInfo(1000.0, null), new FakeActivityInfo(1000.0, null), new FakeSensorInfo(1000.0, null));
	Test.assertMessage(data.getSpeed() == null, "all speeds null -> getSpeed() null");
	return true;
}

// Sensor speed present -> null -> back: getSpeed() follows the GPS while the
// sensor speed is missing and never keeps a stale sensor value.
(:test)
function testWatchDataSpeedRecoversAfterNullSensorSpeed(logger)
{
	var data = new WatchData();

	SpeedTestHelper.feedTick(data, new FakePositionInfo(1000.0, 1.2), new FakeActivityInfo(1000.0, 0.9), new FakeSensorInfo(1000.0, 2.0));
	SpeedTestHelper.assertSpeed(data, 2.0, "tick 1: sensor speed wins (priority unchanged)");

	SpeedTestHelper.feedTick(data, new FakePositionInfo(1000.0, 1.3), new FakeActivityInfo(1000.0, 0.9), new FakeSensorInfo(1000.0, null));
	SpeedTestHelper.assertSpeed(data, 1.3, "tick 2: sensor speed null -> GPS speed, not stale 2.0");

	SpeedTestHelper.feedTick(data, new FakePositionInfo(1000.0, null), new FakeActivityInfo(1000.0, 0.8), new FakeSensorInfo(1000.0, null));
	SpeedTestHelper.assertSpeed(data, 0.8, "tick 3: sensor and GPS null -> activity speed");

	SpeedTestHelper.feedTick(data, new FakePositionInfo(1000.0, 1.4), new FakeActivityInfo(1000.0, 0.9), new FakeSensorInfo(1000.0, 2.5));
	SpeedTestHelper.assertSpeed(data, 2.5, "tick 4: sensor speed back -> used again");

	// Without startMeasure() in between: updateSensorInfo() rebuilds its
	// dictionary, so an earlier 2.5 must not survive a later null.
	data.updateSensorInfo(new FakeSensorInfo(1000.0, null));
	SpeedTestHelper.assertSpeed(data, 1.4, "no reset between calls: still no stale sensor speed");
	return true;
}

// ---------------------------------------------------------------------------
// Heart-rate keys written by WatchData.update*(): same rule as speed. A null
// heart rate must not be stored, otherwise activityData["heartRate"] = null
// wins in getHeartRate() and hides a valid Sensor.Info.heartRate.
// ---------------------------------------------------------------------------

(:test)
class HeartRateTestHelper
{
	// Activity.Info stand-in with only the heart rate varying.
	static function act(hr)
	{
		var info = new FakeActivityInfo(1000.0, 1.0);
		info.currentHeartRate = hr;
		return info;
	}

	// Sensor.Info stand-in with only the heart rate varying.
	static function sens(hr)
	{
		var info = new FakeSensorInfo(1000.0, 1.0);
		info.heartRate = hr;
		return info;
	}

	// Handles a null expected value and fails cleanly on a null actual.
	static function assertHr(data, expected, msg)
	{
		var hr = data.getHeartRate();
		if (expected == null)
		{
			Test.assertMessage(hr == null, msg + " (expected null, got " + hr + ")");
		}
		else
		{
			Test.assertMessage(hr != null && hr == expected, msg + " (expected " + expected + ", got " + hr + ")");
		}
	}
}

// Each of the 2 blocks: null -> no key; 0 is a real value and is kept; the
// other keys (altitude, speed) are still written as before.
(:test)
function testWatchDataUpdatesSkipNullHeartRateOnly(logger)
{
	var data = new WatchData();

	data.updateActivityInfo(HeartRateTestHelper.act(null));
	Test.assertMessage(!data.activityData.hasKey("heartRate"), "updateActivityInfo: null heart rate not stored");
	Test.assertEqualMessage(data.activityData["altitude"], 1000.0, "updateActivityInfo: altitude still stored");
	Test.assertEqualMessage(data.activityData["speed"], 1.0, "updateActivityInfo: speed still stored");
	data.updateActivityInfo(HeartRateTestHelper.act(0));
	Test.assertEqualMessage(data.activityData["heartRate"], 0, "updateActivityInfo: zero heart rate kept");

	data.updateSensorInfo(HeartRateTestHelper.sens(null));
	Test.assertMessage(!data.sensorData.hasKey("heartRate"), "updateSensorInfo: null heart rate not stored");
	Test.assertEqualMessage(data.sensorData["altitude"], 1000.0, "updateSensorInfo: altitude still stored");
	Test.assertEqualMessage(data.sensorData["speed"], 1.0, "updateSensorInfo: speed still stored");
	data.updateSensorInfo(HeartRateTestHelper.sens(0));
	Test.assertEqualMessage(data.sensorData["heartRate"], 0, "updateSensorInfo: zero heart rate kept");

	// A zero activity heart rate still wins over the sensor (priority unchanged).
	data = new WatchData();
	SpeedTestHelper.feedTick(data, null, HeartRateTestHelper.act(0), HeartRateTestHelper.sens(118));
	HeartRateTestHelper.assertHr(data, 0, "activity 0 bpm kept and still has priority");

	// A null activity heart rate must not hide the sensor heart rate.
	data = new WatchData();
	SpeedTestHelper.feedTick(data, null, HeartRateTestHelper.act(null), HeartRateTestHelper.sens(118));
	HeartRateTestHelper.assertHr(data, 118, "null activity heart rate -> sensor heart rate");

	// Both null -> getHeartRate() null (the views show "--"), not a crash.
	data = new WatchData();
	SpeedTestHelper.feedTick(data, null, HeartRateTestHelper.act(null), HeartRateTestHelper.sens(null));
	HeartRateTestHelper.assertHr(data, null, "all heart rates null -> getHeartRate() null");
	return true;
}

// Sequence 120 -> null -> 125: no source keeps a stale 120 after the null;
// the accessor falls back to the other source, or to null ("--").
(:test)
function testWatchDataHeartRateRecoversAfterNull(logger)
{
	// A: both sources lose the strap together.
	var data = new WatchData();
	SpeedTestHelper.feedTick(data, null, HeartRateTestHelper.act(120), HeartRateTestHelper.sens(120));
	HeartRateTestHelper.assertHr(data, 120, "A tick 1: 120");
	SpeedTestHelper.feedTick(data, null, HeartRateTestHelper.act(null), HeartRateTestHelper.sens(null));
	HeartRateTestHelper.assertHr(data, null, "A tick 2: both null -> null, not stale 120");
	SpeedTestHelper.feedTick(data, null, HeartRateTestHelper.act(125), HeartRateTestHelper.sens(125));
	HeartRateTestHelper.assertHr(data, 125, "A tick 3: 125 taken");

	// B: only the activity heart rate drops, the sensor value is shown.
	data = new WatchData();
	SpeedTestHelper.feedTick(data, null, HeartRateTestHelper.act(120), HeartRateTestHelper.sens(120));
	HeartRateTestHelper.assertHr(data, 120, "B tick 1: 120");
	SpeedTestHelper.feedTick(data, null, HeartRateTestHelper.act(null), HeartRateTestHelper.sens(119));
	HeartRateTestHelper.assertHr(data, 119, "B tick 2: activity null -> sensor 119");
	SpeedTestHelper.feedTick(data, null, HeartRateTestHelper.act(125), HeartRateTestHelper.sens(124));
	HeartRateTestHelper.assertHr(data, 125, "B tick 3: activity 125 back, priority unchanged");

	// C: Activity.getActivityInfo() returned null, sensor only.
	data = new WatchData();
	SpeedTestHelper.feedTick(data, null, null, HeartRateTestHelper.sens(120));
	HeartRateTestHelper.assertHr(data, 120, "C tick 1: sensor 120");
	SpeedTestHelper.feedTick(data, null, null, HeartRateTestHelper.sens(null));
	HeartRateTestHelper.assertHr(data, null, "C tick 2: sensor null -> null, not stale 120");
	SpeedTestHelper.feedTick(data, null, null, HeartRateTestHelper.sens(125));
	HeartRateTestHelper.assertHr(data, 125, "C tick 3: sensor 125 taken");

	// Without startMeasure() in between: each update*() rebuilds its
	// dictionary, so an earlier value never survives a later null.
	data = new WatchData();
	SpeedTestHelper.feedTick(data, null, HeartRateTestHelper.act(125), HeartRateTestHelper.sens(123));
	data.updateActivityInfo(HeartRateTestHelper.act(null));
	HeartRateTestHelper.assertHr(data, 123, "no reset: activity null -> sensor 123");
	data.updateSensorInfo(HeartRateTestHelper.sens(null));
	HeartRateTestHelper.assertHr(data, null, "no reset: both null -> null");
	return true;
}
