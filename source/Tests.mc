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

	return true;
}
