using Toybox.Test;

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
	Test.assertMessage($.hasActiveSession(), "session must still exist while paused -- this is exactly what the BACK quit-menu gate relies on to offer Save/Discard instead of silently exiting");
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
// recorded. The user's own Save/Discard choices null the
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
