using Toybox.Test;
using Toybox.Application;
using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Position;
using Toybox.Sensor;
using Toybox.Attention;
using Toybox.WatchUi;

// Unit tests for the hike-and-fly feature's pure logic, run with:
//   monkeyc -f monkey.jungle -o /tmp/glidator-build/Glidator.prg -d fenix6pro -y developer_key -t
//   monkeydo /tmp/glidator-build/Glidator.prg fenix6pro -t
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
// START (SELECT) button and the Resume / Pause / Save / Ignore menu, modelled
// on the stock Garmin Hike app: SELECT while recording freezes the timer and
// opens the menu; SELECT while paused resumes; SELECT without a session starts.
// In the menu, BACK means Resume, and 30 s without a choice resumes too.
// ---------------------------------------------------------------------------

// Full table of the three session states, plus incoherent / missing inputs.
(:test)
function testSelectAction(logger)
{
	Test.assertEqualMessage($.selectAction(false, false), :start, "no session -> start");
	Test.assertEqualMessage($.selectAction(true, true), :pauseMenu, "recording -> pause and open the menu");
	Test.assertEqualMessage($.selectAction(true, false), :resume, "paused -> resume");

	// Edge cases.
	Test.assertEqualMessage($.selectAction(false, true), :start, "recording without a session is incoherent -> start (startRecording() is a no-op if a session exists)");
	Test.assertEqualMessage($.selectAction(null, null), :start, "null inputs -> start");
	Test.assertEqualMessage($.selectAction(null, true), :start, "null hasSession -> start");
	Test.assertEqualMessage($.selectAction(true, null), :resume, "session with unknown recording state -> treated as paused (resumeRecording() is a no-op if recording)");

	return true;
}

// Auto-resume after 30 s without any choice in the menu. Bounds pinned at
// 29 999 / 30 000 ms; unknown or negative elapsed time never resumes.
(:test)
function testMenuTimeoutAction(logger)
{
	Test.assertEqualMessage($.MENU_AUTO_RESUME_MS, 30000, "auto-resume delay is 30 s");

	Test.assertEqualMessage($.menuTimeoutAction(0), :none, "just opened -> none");
	Test.assertEqualMessage($.menuTimeoutAction(1000), :none, "1 s -> none");
	Test.assertEqualMessage($.menuTimeoutAction(29999), :none, "29 999 ms -> none (just below the bound)");
	Test.assertEqualMessage($.menuTimeoutAction(30000), :resume, "30 000 ms -> resume (bound included)");
	Test.assertEqualMessage($.menuTimeoutAction(30001), :resume, "30 001 ms -> resume");
	Test.assertEqualMessage($.menuTimeoutAction(3600000), :resume, "an hour later -> resume");
	Test.assertEqualMessage($.menuTimeoutAction(2147483647), :resume, "max Number -> resume");

	// Edge cases: missing or nonsensical elapsed times never resume on their own.
	Test.assertEqualMessage($.menuTimeoutAction(null), :none, "null -> none");
	Test.assertEqualMessage($.menuTimeoutAction(-1), :none, "negative -> none");
	Test.assertEqualMessage($.menuTimeoutAction(-30000), :none, "large negative -> none");

	// Floats (e.g. a computed elapsed time) follow the same bound.
	Test.assertEqualMessage($.menuTimeoutAction(29999.5), :none, "29 999.5 ms -> none");
	Test.assertEqualMessage($.menuTimeoutAction(30000.0), :resume, "30 000.0 ms -> resume");

	return true;
}

// The periodic check the menu runs: once the menu is closed (a choice was
// made, or BACK), the timer must never resume anything afterwards -- e.g.
// after Pause the session stays paused, whatever the elapsed time.
(:test)
function testQuitMenuTickAction(logger)
{
	Test.assertEqualMessage($.quitMenuTickAction(false, 29999), :none, "menu open, 29 999 ms -> none");
	Test.assertEqualMessage($.quitMenuTickAction(false, 30000), :resume, "menu open, 30 000 ms -> resume");
	Test.assertEqualMessage($.quitMenuTickAction(true, 30000), :none, "menu already closed, 30 000 ms -> none");
	Test.assertEqualMessage($.quitMenuTickAction(true, 3600000), :none, "menu already closed, long after -> none");
	Test.assertEqualMessage($.quitMenuTickAction(true, 0), :none, "menu already closed, 0 ms -> none");
	Test.assertEqualMessage($.quitMenuTickAction(false, null), :none, "menu open, unknown elapsed -> none");
	Test.assertEqualMessage($.quitMenuTickAction(false, -5), :none, "menu open, negative elapsed -> none");
	Test.assertEqualMessage($.quitMenuTickAction(null, 30000), :none, "unknown closed state -> none (never resume on doubt)");

	return true;
}

// Menu item ids -> actions, and BACK -> Resume.
(:test)
function testMenuItemAction(logger)
{
	Test.assertEqualMessage($.menuItemAction("resume"), :resume, "Resume item");
	Test.assertEqualMessage($.menuItemAction("pause"), :pause, "Pause item");
	Test.assertEqualMessage($.menuItemAction("save"), :save, "Save item");
	Test.assertEqualMessage($.menuItemAction("ignore"), :ignore, "Ignore item");

	// Edge cases.
	Test.assertEqualMessage($.menuItemAction(null), :none, "null id -> none");
	Test.assertEqualMessage($.menuItemAction(""), :none, "empty id -> none");
	Test.assertEqualMessage($.menuItemAction("discard"), :none, "unknown id -> none");
	Test.assertEqualMessage($.menuItemAction("Resume"), :none, "ids are case sensitive -> none");
	Test.assertEqualMessage($.menuItemAction(:resume), :none, "symbol instead of string id -> none");

	Test.assertEqualMessage($.menuBackAction(), :resume, "BACK in the menu -> resume");

	return true;
}

// isPaused(): a session exists but is not ticking. Driven through the real
// session API, then checked against selectAction() at each step, i.e. the
// exact sequence of SELECT presses the user goes through.
(:test)
function testIsPausedAndSelectFlow(logger)
{
	if ($.hasActiveSession())
	{
		$.stopRecording(false);
	}

	Test.assertMessage(!$.isPaused(), "no session -> not paused");
	Test.assertEqualMessage($.selectAction($.hasActiveSession(), $.isRecording()), :start, "SELECT without a session -> start");

	$.startRecording();
	Test.assertMessage(!$.isPaused(), "recording -> not paused");
	Test.assertEqualMessage($.selectAction($.hasActiveSession(), $.isRecording()), :pauseMenu, "SELECT while recording -> pause + menu");

	$.pauseRecording();
	Test.assertMessage($.isPaused(), "after pauseRecording() -> paused");
	Test.assertEqualMessage($.selectAction($.hasActiveSession(), $.isRecording()), :resume, "SELECT while paused -> resume");

	$.resumeRecording();
	Test.assertMessage(!$.isPaused(), "after resumeRecording() -> not paused");
	Test.assertEqualMessage($.selectAction($.hasActiveSession(), $.isRecording()), :pauseMenu, "SELECT after resume -> pause + menu again");

	$.stopRecording(false); // discard -- this is just a test run
	Test.assertMessage(!$.isPaused(), "after discard -> not paused");
	Test.assertEqualMessage($.selectAction($.hasActiveSession(), $.isRecording()), :start, "SELECT after discard -> start");

	return true;
}

// ---------------------------------------------------------------------------
// Pause 4b: "Paused" screen (opened by the menu's Pause item), sensors off
// except GPS while paused, distinct pause / resume vibrations.
// ---------------------------------------------------------------------------

// SELECT on the Paused screen: resume when paused, otherwise just close the
// screen; never act twice (a second press before the screen is gone would
// pop one view too many and quit the app).
(:test)
function testPausedSelectAction(logger)
{
	Test.assertEqualMessage($.pausedSelectAction(false, true, false), :resume, "paused session -> resume");
	Test.assertEqualMessage($.pausedSelectAction(false, true, true), :close, "session already recording -> close only (no second start)");
	Test.assertEqualMessage($.pausedSelectAction(false, false, false), :close, "no session any more -> close only");

	// Already handled once: nothing more, whatever the session state.
	Test.assertEqualMessage($.pausedSelectAction(true, true, false), :none, "already closed, paused -> none");
	Test.assertEqualMessage($.pausedSelectAction(true, true, true), :none, "already closed, recording -> none");
	Test.assertEqualMessage($.pausedSelectAction(true, false, false), :none, "already closed, no session -> none");

	// Edge cases.
	Test.assertEqualMessage($.pausedSelectAction(null, true, false), :none, "unknown closed state -> none (never pop on doubt)");
	Test.assertEqualMessage($.pausedSelectAction(false, true, null), :resume, "session with unknown recording state -> treated as paused (resumeRecording() is a no-op if recording)");
	Test.assertEqualMessage($.pausedSelectAction(false, null, null), :close, "unknown session -> close only");
	Test.assertEqualMessage($.pausedSelectAction(false, false, true), :close, "recording without a session is incoherent -> close only");
	return true;
}

// BACK on the Paused screen does nothing: it must neither resume nor pop the
// screen (popping the last view would quit the app).
(:test)
function testPausedBackAction(logger)
{
	Test.assertEqualMessage($.pausedBackAction(), :none, "BACK on the Paused screen -> none");
	Test.assertMessage($.pausedBackAction() != $.menuBackAction(), "unlike the pause menu, BACK does not resume here");
	return true;
}

// Frozen timer shown on the Paused screen.
(:test)
function testPausedScreenTimerText(logger)
{
	Test.assertEqualMessage($.pausedScreenTimerText(true, 0), "00:00", "session, 0 ms");
	Test.assertEqualMessage($.pausedScreenTimerText(true, 65000), "01:05", "session, 65 s");
	Test.assertEqualMessage($.pausedScreenTimerText(true, 3661000), "1:01:01", "session, over an hour");
	Test.assertEqualMessage($.pausedScreenTimerText(true, 65999), "01:05", "milliseconds are truncated, like the hike pages");

	// Edge cases.
	Test.assertEqualMessage($.pausedScreenTimerText(true, null), "--:--", "session, unknown timer -> placeholder");
	Test.assertEqualMessage($.pausedScreenTimerText(false, 65000), "--:--", "no session -> placeholder (stale timer not shown)");
	Test.assertEqualMessage($.pausedScreenTimerText(null, 65000), "--:--", "unknown session -> placeholder");
	return true;
}

// Sensors wanted for a state: none while paused (GPS is not a Sensor and is
// driven separately by Position.enableLocationEvents), the exact list that
// was enabled at start otherwise.
(:test)
function testSensorsForState(logger)
{
	var active = [Sensor.SENSOR_HEARTRATE, Sensor.SENSOR_TEMPERATURE];

	var running = $.sensorsForState(false, active);
	Test.assertEqualMessage(running.size(), 2, "running -> the 2 active sensors");
	Test.assertEqualMessage(running[0], Sensor.SENSOR_HEARTRATE, "running -> heart rate first, as given");
	Test.assertEqualMessage(running[1], Sensor.SENSOR_TEMPERATURE, "running -> temperature second, as given");

	Test.assertEqualMessage($.sensorsForState(true, active).size(), 0, "paused -> no sensor");
	Test.assertEqualMessage(active.size(), 2, "the active list itself is not emptied by a pause");

	// Exactly what was on comes back, whatever it was.
	var hrOnly = $.sensorsForState(false, [Sensor.SENSOR_HEARTRATE]);
	Test.assertEqualMessage(hrOnly.size(), 1, "running, HR only -> 1 sensor");
	Test.assertEqualMessage(hrOnly[0], Sensor.SENSOR_HEARTRATE, "running, HR only -> HR");
	Test.assertEqualMessage($.sensorsForState(false, []).size(), 0, "running, nothing active -> nothing");

	// Edge cases.
	Test.assertEqualMessage($.sensorsForState(false, null).size(), 0, "running, unknown active list -> nothing");
	Test.assertEqualMessage($.sensorsForState(true, null).size(), 0, "paused, unknown active list -> nothing");
	Test.assertEqualMessage($.sensorsForState(null, active).size(), 2, "unknown pause state -> keep sensors on (only costs battery)");
	return true;
}

// The list enabled by onStart() (and restored on resume): heart rate and
// temperature, as before 4b.
(:test)
function testActiveSensorList(logger)
{
	var list = $.activeSensorList();
	Test.assertEqualMessage(list.size(), 2, "2 sensors");
	Test.assertEqualMessage(list[0], Sensor.SENSOR_HEARTRATE, "heart rate");
	Test.assertEqualMessage(list[1], Sensor.SENSOR_TEMPERATURE, "temperature");
	return true;
}

// Pausing turns the sensors off, resuming (from the Paused screen or the menu)
// turns them back on, and ending a paused session never leaves them off.
//
// The session is a FakeSession (TestsChain.mc), not ActivityRecording's: with
// the simulator's real session, Session.start() may leave isRecording() false
// (it returns false when recording could not start, and the simulator does so
// now and then under load: seen once on fenix6s, 10/10). pauseRecording() then
// rightly does nothing -- the app only calls it when isRecording() is true,
// see selectAction() -- and this test failed for a reason unrelated to the
// sensors. The real session API (start / stop / save / discard) stays covered
// by testSessionStateMachine, testIsPausedAndSelectFlow and the
// testStopRecordingSaves* tests; what is checked here is only how
// pause / resume / stop drive the sensors, which depends on isRecording() alone.
(:test)
function testSensorsFollowPauseAndResume(logger)
{
	if ($.hasActiveSession())
	{
		$.stopRecording(false);
	}
	Test.assertMessage($.sensorsOffForPause != true, "precondition: sensors on without a session");

	$.session = new FakeSession(true); // what startRecording() leaves when start() succeeds
	Test.assertMessage($.isRecording(), "precondition: recording");
	Test.assertMessage($.sensorsOffForPause != true, "recording -> sensors on");

	$.pauseRecording();
	Test.assertMessage(!$.isRecording(), "pauseRecording() stops the session");
	Test.assertMessage($.sensorsOffForPause == true, "paused -> sensors off");
	Test.assertEqualMessage($.pausedSelectAction(false, $.hasActiveSession(), $.isRecording()), :resume, "SELECT on the Paused screen -> resume");

	$.resumeRecording();
	Test.assertMessage($.sensorsOffForPause != true, "resumed -> sensors on again");
	Test.assertMessage($.isRecording(), "resumed -> recording");

	// A second pause / resume cycle behaves the same.
	$.pauseRecording();
	Test.assertMessage($.sensorsOffForPause == true, "paused again -> sensors off");
	$.resumeRecording();
	Test.assertMessage($.sensorsOffForPause != true, "resumed again -> sensors on");

	// Ending a paused session (Save / Ignore, onStop) restores the sensors.
	$.pauseRecording();
	Test.assertMessage($.sensorsOffForPause == true, "precondition: paused, sensors off");
	$.stopRecording(false); // discard -- this is just a test run
	Test.assertMessage($.sensorsOffForPause != true, "session ended while paused -> sensors on");

	// Pause / resume without a session are no-ops: the sensors are not touched.
	$.pauseRecording();
	Test.assertMessage($.sensorsOffForPause != true, "pause without a session -> sensors untouched");
	$.resumeRecording();
	Test.assertMessage($.sensorsOffForPause != true, "resume without a session -> sensors untouched");

	// Pause and resume are transitions: pause only from recording, resume only
	// from a session that is not recording; outside their state they leave the
	// session and the sensors alone. (Kept in this test rather than a new one:
	// the 'globals' module is at the compiler's 253-member limit.)
	// Session whose start() did not take (exists, not recording): the UI shows
	// it as paused (SELECT -> resume), a stray pauseRecording() must not stop
	// anything, and resuming starts it.
	$.session = new FakeSession(false);
	Test.assertEqualMessage($.selectAction($.hasActiveSession(), $.isRecording()), :resume, "session not recording -> SELECT resumes, never pauses");
	$.pauseRecording();
	Test.assertMessage($.sensorsOffForPause != true, "pause of a session not recording -> sensors untouched");
	Test.assertMessage($.hasActiveSession() && !$.isRecording(), "pause of a session not recording -> session unchanged");
	$.resumeRecording();
	Test.assertMessage($.isRecording(), "resume of a session not recording -> recording");
	Test.assertMessage($.sensorsOffForPause != true, "resume -> sensors on");

	// Resume of a session already recording: no-op, even if the sensors were off.
	$.sensorsOffForPause = true;
	$.resumeRecording();
	Test.assertMessage($.sensorsOffForPause == true, "resume while recording -> sensors untouched");
	Test.assertMessage($.isRecording(), "resume while recording -> still recording");
	$.sensorsOffForPause = false;

	// Two pauses in a row: the second one changes nothing.
	$.pauseRecording();
	Test.assertMessage($.sensorsOffForPause == true, "first pause -> sensors off");
	$.pauseRecording();
	Test.assertMessage($.sensorsOffForPause == true, "second pause -> sensors still off");
	Test.assertMessage($.hasActiveSession() && !$.isRecording(), "second pause -> still paused");

	$.stopRecording(false);
	Test.assertMessage(!$.hasActiveSession(), "session gone after stop");
	Test.assertMessage($.sensorsOffForPause != true, "session ended after a double pause -> sensors on");
	return true;
}

// Vibration motifs as [duty cycle %, duration ms] segments.
// Pause: two short pulses; resume: one long pulse (spec 4b).
(:test)
function testVibePattern(logger)
{
	var pause = $.vibePattern(:pause);
	Test.assertEqualMessage(pause.size(), 3, "pause: pulse, gap, pulse");
	Test.assertEqualMessage(pause[0][0], 100, "pause pulse 1: 100 %");
	Test.assertEqualMessage(pause[0][1], 150, "pause pulse 1: 150 ms");
	Test.assertEqualMessage(pause[1][0], 0, "pause gap: 0 % (motor off)");
	Test.assertEqualMessage(pause[1][1], 150, "pause gap: 150 ms");
	Test.assertEqualMessage(pause[2][0], 100, "pause pulse 2: 100 %");
	Test.assertEqualMessage(pause[2][1], 150, "pause pulse 2: 150 ms");

	var resume = $.vibePattern(:resume);
	Test.assertEqualMessage(resume.size(), 1, "resume: a single pulse");
	Test.assertEqualMessage(resume[0][0], 100, "resume pulse: 100 %");
	Test.assertEqualMessage(resume[0][1], 600, "resume pulse: 600 ms");

	// Distinct by shape, not just intensity: pulse count and longest pulse differ.
	var pausePulses = 0;
	var pauseLongest = 0;
	for (var i = 0; i < pause.size(); i++)
	{
		if (pause[i][0] > 0) { pausePulses++; }
		if (pause[i][0] > 0 && pause[i][1] > pauseLongest) { pauseLongest = pause[i][1]; }
	}
	Test.assertEqualMessage(pausePulses, 2, "pause has 2 pulses");
	Test.assertMessage(resume[0][1] >= 4 * pauseLongest, "the resume pulse is at least 4x longer than a pause pulse");

	// Every segment is valid for Attention.VibeProfile: duty 0..100, duration > 0.
	var all = [pause, resume];
	for (var p = 0; p < all.size(); p++)
	{
		for (var i = 0; i < all[p].size(); i++)
		{
			var seg = all[p][i];
			Test.assertMessage(seg[0] >= 0 && seg[0] <= 100, "duty cycle within 0..100");
			Test.assertMessage(seg[1] > 0, "duration > 0");
		}
	}

	// Edge cases: unknown kinds vibrate nothing.
	Test.assertEqualMessage($.vibePattern(:unknown).size(), 0, "unknown kind -> no vibration");
	Test.assertEqualMessage($.vibePattern(null).size(), 0, "null kind -> no vibration");
	Test.assertEqualMessage($.vibePattern("pause").size(), 0, "string instead of symbol -> no vibration");
	return true;
}

// Pattern -> Attention.VibeProfile array, one profile per segment.
(:test)
function testVibeProfilesFromPattern(logger)
{
	var profiles = $.vibeProfiles($.vibePattern(:pause));
	Test.assertEqualMessage(profiles.size(), 3, "pause -> 3 profiles");
	for (var i = 0; i < profiles.size(); i++)
	{
		Test.assertMessage(profiles[i] instanceof Attention.VibeProfile, "profile " + i + " is a VibeProfile");
	}
	Test.assertEqualMessage($.vibeProfiles($.vibePattern(:resume)).size(), 1, "resume -> 1 profile");

	// Edge cases.
	Test.assertEqualMessage($.vibeProfiles([]).size(), 0, "empty pattern -> no profile");
	Test.assertEqualMessage($.vibeProfiles(null).size(), 0, "null pattern -> no profile");
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

	// Very large values (altitude glitch) are beyond the +-3000 m/h cap
	// (decision of 07/10, VS cap): "--", never an overflowed Number.
	Test.assertEqualMessage($.formatVerticalSpeed(1000000.0), "--", "1e6 -> -- (beyond the 3000 m/h cap)");
	Test.assertEqualMessage($.formatVerticalSpeed(-1000000.0), "--", "-1e6 -> -- (beyond the 3000 m/h cap)");
	Test.assertEqualMessage($.formatVerticalSpeed(1.0e10), "--", "1e10 -> -- (beyond the 3000 m/h cap)");

	// NaN is not a speed: show "--" rather than garbage. (A Float division
	// 0.0 / 0.0 throws in Monkey C, so NaN is built from sqrt of a negative.)
	var nan = Toybox.Math.sqrt(-1.0);
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
	// Beyond VERTICAL_SPEED_MAX_MH (3000 m/h) the value reads "--"; a finite
	// but huge Float such as 3e38 would also overflow the Long rounding
	// (toLong() past about 9.2e18) if it were not capped.
	Test.assertEqualMessage($.formatVerticalSpeed(big), "--", "3e38 -> -- (beyond the cap, no Long overflow)");
	Test.assertEqualMessage($.formatVerticalSpeed(-big), "--", "-3e38 -> -- (beyond the cap, no Long overflow)");
	return true;
}

// Cap of formatVerticalSpeed() (decision of 07/10, VS cap): |v| <= 3000 m/h (bound
// included) is formatted, anything larger reads "--", in climb and descent.
// The rule is on the value BEFORE rounding: 3000.4 would round to "+3000"
// but is above the cap, so it reads "--".
// 32-bit Floats are about 0.00024 apart near 3000, so 2999.9, 3000.1 and
// 3000.4 each stay on their side of 3000; 3000.0 is exact.
(:test)
function testFormatVerticalSpeedCap(logger)
{
	Test.assertEqualMessage($.VERTICAL_SPEED_MAX_MH, 3000.0, "documented cap is 3000 m/h");

	// Just under and exactly at the cap: formatted.
	Test.assertEqualMessage($.formatVerticalSpeed(2999.9), "+3000", "2999.9 (under the cap) -> +3000");
	Test.assertEqualMessage($.formatVerticalSpeed(-2999.9), "-3000", "-2999.9 (under the cap) -> -3000");
	Test.assertEqualMessage($.formatVerticalSpeed(3000.0), "+3000", "3000.0 (the cap, included) -> +3000");
	Test.assertEqualMessage($.formatVerticalSpeed(-3000.0), "-3000", "-3000.0 (the cap, included) -> -3000");
	Test.assertEqualMessage($.formatVerticalSpeed(2994.9), "+2990", "2994.9 -> +2990");
	Test.assertEqualMessage($.formatVerticalSpeed(-2995.0), "-3000", "-2995.0 -> -3000");

	// Just above the cap: "--", even when the rounded value would be 3000.
	Test.assertEqualMessage($.formatVerticalSpeed(3000.1), "--", "3000.1 (just above) -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(-3000.1), "--", "-3000.1 (just above) -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(3000.4), "--", "3000.4 (would round to +3000) -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(-3000.4), "--", "-3000.4 (would round to -3000) -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(3004.9), "--", "3004.9 -> --");

	// Far above the cap, including the former Long overflow zone.
	Test.assertEqualMessage($.formatVerticalSpeed(23736.3), "--", "23736.3 (altitude jump) -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(-14419.8), "--", "-14419.8 (spiral dive) -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(1.0e10), "--", "1e10 -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(-1.0e10), "--", "-1e10 -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(1.0e19), "--", "1e19 (Long overflow zone) -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(-1.0e20), "--", "-1e20 -> --");

	// Not a value, NaN, +-Infinity: "--" (unchanged by the cap).
	Test.assertEqualMessage($.formatVerticalSpeed(null), "--", "null -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(MapTestHelper.nan()), "--", "NaN -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(MapTestHelper.inf()), "--", "+Inf -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(-MapTestHelper.inf()), "--", "-Inf -> --");

	// Zero and minus zero are inside the cap.
	Test.assertEqualMessage($.formatVerticalSpeed(-0.0), "0", "-0.0 -> 0");
	Test.assertEqualMessage($.formatVerticalSpeed(0), "0", "Number 0 -> 0");

	// Number, Long and Double inputs are capped the same way.
	Test.assertEqualMessage($.formatVerticalSpeed(3000), "+3000", "Number 3000 -> +3000");
	Test.assertEqualMessage($.formatVerticalSpeed(-3000), "-3000", "Number -3000 -> -3000");
	Test.assertEqualMessage($.formatVerticalSpeed(3001), "--", "Number 3001 -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(-3001), "--", "Number -3001 -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(3000l), "+3000", "Long 3000 -> +3000");
	Test.assertEqualMessage($.formatVerticalSpeed(5000000000l), "--", "Long 5e9 -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(3000.0d), "+3000", "Double 3000 -> +3000");
	Test.assertEqualMessage($.formatVerticalSpeed(3000.1d), "--", "Double 3000.1 -> --");
	Test.assertEqualMessage($.formatVerticalSpeed(1.0e300d), "--", "Double 1e300 -> --");

	// Real Salvan climb (garmin_data/activity_24346302742.tcx, lap 1, 60 s
	// trailing window, endpoint difference; pinned by
	// tools/test_analyze_activity.py test_climb_vertical_speed_diff_reproduces_plan):
	// median +636 m/h, p95 +891 m/h, p5 -129 m/h. All stay displayed.
	Test.assertEqualMessage($.formatVerticalSpeed(636.4), "+640", "Salvan median 636.4 still +640");
	Test.assertEqualMessage($.formatVerticalSpeed(891.0), "+890", "Salvan p95 891 still +890");
	Test.assertEqualMessage($.formatVerticalSpeed(-129.0), "-130", "Salvan p5 -129 still -130");
	return true;
}

// ---------------------------------------------------------------------------
// Hike pace (Marche 2b): formatPace(speedMps) -> "m:ss" min/km. The total
// in seconds is rounded before splitting, so a 359.6 s pace reads "6:00",
// never "5:60". "--:--" when there is no usable speed or the pace is slower
// than 60:00 /km (60:00 itself is shown).
// ---------------------------------------------------------------------------

(:test)
function testFormatPace(logger)
{
	// Spec values.
	Test.assertEqualMessage($.formatPace(null), "--:--", "null -> --:--");
	Test.assertEqualMessage($.formatPace(0.0), "--:--", "0.0 -> --:--");
	Test.assertEqualMessage($.formatPace(0.25), "--:--", "0.25 m/s (66:40 /km) -> --:--");
	Test.assertEqualMessage($.formatPace(1000.0 / 300.0), "5:00", "300 s/km -> 5:00");
	Test.assertEqualMessage($.formatPace(1000.0 / 359.6), "6:00", "359.6 s/km -> 6:00, not 5:60");
	Test.assertEqualMessage($.formatPace(1.04), "16:02", "1.04 m/s (961.5 s/km) -> 16:02");
	Test.assertEqualMessage($.formatPace(1000.0 / 3600.0), "60:00", "3600 s/km -> 60:00 (bound included)");

	// Around the 60:00 bound: the rounded total decides, not the raw speed.
	Test.assertEqualMessage($.formatPace(1000.0 / 3599.6), "60:00", "3599.6 s/km rounds to 60:00");
	Test.assertEqualMessage($.formatPace(1000.0 / 3600.4), "60:00", "3600.4 s/km rounds to 60:00 -> still shown");
	Test.assertEqualMessage($.formatPace(1000.0 / 3600.6), "--:--", "3600.6 s/km rounds to 60:01 -> --:--");
	Test.assertEqualMessage($.formatPace(1000.0 / 3540.0), "59:00", "3540 s/km -> 59:00");

	// Seconds rounding (away from exact halves, which Float cannot pin down).
	Test.assertEqualMessage($.formatPace(1000.0 / 300.4), "5:00", "300.4 s/km -> 5:00");
	Test.assertEqualMessage($.formatPace(1000.0 / 300.6), "5:01", "300.6 s/km -> 5:01");
	Test.assertEqualMessage($.formatPace(1000.0 / 59.6), "1:00", "59.6 s/km -> 1:00, not 0:60");
	Test.assertEqualMessage($.formatPace(1000.0 / 9.0), "0:09", "9 s/km -> 0:09 (seconds padded)");
	Test.assertEqualMessage($.formatPace(1000.0 / 605.0), "10:05", "605 s/km -> 10:05");

	// Negative speeds are not a pace.
	Test.assertEqualMessage($.formatPace(-1.0), "--:--", "negative speed -> --:--");
	Test.assertEqualMessage($.formatPace(-0.0), "--:--", "-0.0 -> --:--");

	// Integer input (Number) is accepted: 1 m/s -> 1000 s/km.
	Test.assertEqualMessage($.formatPace(1), "16:40", "Number 1 -> 16:40");
	Test.assertEqualMessage($.formatPace(0), "--:--", "Number 0 -> --:--");
	Test.assertEqualMessage($.formatPace(-2), "--:--", "Number -2 -> --:--");

	// Tiny positive speed: pace far beyond 60:00, no overflow on the way.
	Test.assertEqualMessage($.formatPace(1.0e-30), "--:--", "1e-30 m/s -> --:--");

	// Very large speeds (GPS glitch): a pace that rounds to 0 s is not a pace.
	Test.assertEqualMessage($.formatPace(1000.0), "0:01", "1000 m/s -> 0:01");
	Test.assertEqualMessage($.formatPace(2500.0), "--:--", "2500 m/s (0.4 s/km, rounds to 0) -> --:--");
	Test.assertEqualMessage($.formatPace(1.0e30), "--:--", "1e30 m/s -> --:--");

	// NaN and +/-Infinity (built as in testFormatVerticalSpeed).
	var nan = Toybox.Math.sqrt(-1.0);
	Test.assertEqualMessage($.formatPace(nan), "--:--", "NaN -> --:--");
	var big = 3.0e38;
	var inf = big * 10.0;
	var negInf = -big * 10.0;
	Test.assertMessage(inf > big && inf == inf * 2.0, "test setup: +Inf expected, got " + inf);
	Test.assertMessage(negInf < -big && negInf == negInf * 2.0, "test setup: -Inf expected, got " + negInf);
	Test.assertEqualMessage($.formatPace(inf), "--:--", "+Inf -> --:--");
	Test.assertEqualMessage($.formatPace(negInf), "--:--", "-Inf -> --:--");
	return true;
}

// What HikePaceView shows: formatPace(getHikeSpeedAt()) on the real Salvan
// climb (same rows as testWatchDataHikeSalvanRealClimb, 11:07:11 -> 11:08:48),
// and "--:--" before a session (no elapsedDistance) or while speed is still
// unknown. Speed (2318.73 - 2258.45) m / 55 s = 1.096 m/s -> 912.4 s/km.
(:test)
function testHikePaceSalvanRealClimb(logger)
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
	Test.assertEqualMessage($.formatPace(data.getHikeSpeedAt(t0)), "--:--", "no sample yet -> --:--");

	var row = 0;
	for (var s = 0; s <= 97; s++)
	{
		while (row + 1 < secs.size() && secs[row + 1] <= s)
		{
			row += 1;
		}
		data.activityData = { "altitude" => alts[row], "distance" => dists[row] };
		data.recordHikeSampleAt(t0 + s * 1000);
		if (s == 10)
		{
			Test.assertEqualMessage($.formatPace(data.getHikeSpeedAt(t0 + s * 1000)), "--:--", "10 s of data -> --:--");
		}
	}
	var pace = $.formatPace(data.getHikeSpeedAt(t0 + 97000));
	logger.debug("Salvan pace at 11:08:48 -> " + pace + " /km");
	Test.assertEqualMessage(pace, "15:12", "real Salvan climb pace: 912.4 s/km -> 15:12");

	// Before a session there is no elapsedDistance: pace stays --:--.
	data = new WatchData();
	for (var s = 0; s <= 60; s += 5)
	{
		data.sensorData = { "altitude" => 1500.0 + s / 6.0 };
		data.recordHikeSampleAt(t0 + s * 1000);
	}
	Test.assertEqualMessage($.formatPace(data.getHikeSpeedAt(t0 + 60000)), "--:--", "no session (no distance) -> --:--");

	// Standing still for a minute: speed 0 -> --:--.
	data = new WatchData();
	for (var s = 0; s <= 60; s += 5)
	{
		data.activityData = { "altitude" => 1500.0, "distance" => 2000.0 };
		data.recordHikeSampleAt(t0 + s * 1000);
	}
	Test.assertEqualMessage($.formatPace(data.getHikeSpeedAt(t0 + 60000)), "--:--", "standing still -> --:--");
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
// Marche 1c: vertical-speed window preference, 1 / 3 / 5 min (MENU ->
// "VS window"). Stored like the beep preference; anything missing or not one
// of the three choices reads as the 60 s default. Only the hike vertical
// speed uses it: pace keeps its 60 s window, the flight vario is untouched.
// ---------------------------------------------------------------------------

(:test)
function testVsWindowChoices(logger)
{
	Test.assertEqualMessage($.VS_WINDOW_DEFAULT_MS, 60000, "default window is 60 s");
	var c = $.vsWindowChoicesMs();
	Test.assertEqualMessage(c.size(), 3, "3 choices");
	Test.assertEqualMessage(c[0], 60000, "1 min");
	Test.assertEqualMessage(c[1], 180000, "3 min");
	Test.assertEqualMessage(c[2], 300000, "5 min");
	// 5 min is the buffer's whole history: 60 samples at most 5 s apart.
	var h = new HikeHistory();
	Test.assertMessage(c[2] >= (h.MAX_SAMPLES - 1) * h.MIN_SPACING_MS, "5 min window covers the full buffer");
	return true;
}

// Stored value -> window. Only the three exact Number values are accepted.
(:test)
function testSanitizeVsWindowMs(logger)
{
	Test.assertEqualMessage($.sanitizeVsWindowMs(60000), 60000, "60000 kept");
	Test.assertEqualMessage($.sanitizeVsWindowMs(180000), 180000, "180000 kept");
	Test.assertEqualMessage($.sanitizeVsWindowMs(300000), 300000, "300000 kept");

	// Nothing stored, unknown or corrupted values -> default.
	Test.assertEqualMessage($.sanitizeVsWindowMs(null), 60000, "null (nothing stored) -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs(0), 60000, "0 -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs(-60000), 60000, "negative -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs(120000), 60000, "2 min (not a choice) -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs(299999), 60000, "just under 5 min -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs(300001), 60000, "just over 5 min -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs(600000), 60000, "10 min (beyond the buffer) -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs(2147483647), 60000, "max Number -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs(3), 60000, "minutes instead of ms -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs("180000"), 60000, "String -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs(180000.0), 60000, "Float -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs(180000l), 60000, "Long -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs(true), 60000, "Boolean -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs([180000]), 60000, "Array -> 60000");
	Test.assertEqualMessage($.sanitizeVsWindowMs(:vs3), 60000, "Symbol -> 60000");
	return true;
}

// Menu logic (decision R6, 07/10: no sub-menu any more): labels, index of a
// window, and what the Preferences menu does with each item.
(:test)
function testVsWindowMenuLogic(logger)
{
	Test.assertEqualMessage($.vsWindowLabel(60000), "1 min", "label 1 min");
	Test.assertEqualMessage($.vsWindowLabel(180000), "3 min", "label 3 min");
	Test.assertEqualMessage($.vsWindowLabel(300000), "5 min", "label 5 min");
	Test.assertEqualMessage($.vsWindowLabel(null), "1 min", "null -> label of the default");
	Test.assertEqualMessage($.vsWindowLabel(120000), "1 min", "unknown -> label of the default");
	Test.assertEqualMessage($.vsWindowLabel("x"), "1 min", "corrupted -> label of the default");

	Test.assertEqualMessage($.vsWindowFocusIndex(60000), 0, "index of 1 min");
	Test.assertEqualMessage($.vsWindowFocusIndex(180000), 1, "index of 3 min");
	Test.assertEqualMessage($.vsWindowFocusIndex(300000), 2, "index of 5 min");
	Test.assertEqualMessage($.vsWindowFocusIndex(null), 0, "null -> index of the default");
	Test.assertEqualMessage($.vsWindowFocusIndex(42), 0, "unknown -> index of the default");

	Test.assertEqualMessage($.preferencesMenuAction("vsWindow"), :cycleVsWindow, "VS window item -> next window, no sub-menu");
	Test.assertEqualMessage($.preferencesMenuAction("beep"), :none, "Beep toggle -> none (saved on BACK, as before)");
	Test.assertEqualMessage($.preferencesMenuAction(null), :none, "null id -> none");
	Test.assertEqualMessage($.preferencesMenuAction(""), :none, "empty id -> none");
	Test.assertEqualMessage($.preferencesMenuAction("VSWINDOW"), :none, "ids are case sensitive -> none");
	Test.assertEqualMessage($.preferencesMenuAction(:vsWindow), :none, "symbol instead of string id -> none");
	Test.assertEqualMessage($.preferencesMenuAction(180000), :none, "Number instead of string id -> none");
	// Ids of the removed 1 / 3 / 5 min sub-menu: nothing.
	Test.assertEqualMessage($.preferencesMenuAction("vs1"), :none, "old sub-menu id vs1 -> none");
	Test.assertEqualMessage($.preferencesMenuAction("vs3"), :none, "old sub-menu id vs3 -> none");
	Test.assertEqualMessage($.preferencesMenuAction("vs5"), :none, "old sub-menu id vs5 -> none");

	// The pause menu (4a/4b) ignores the Preferences ids.
	Test.assertEqualMessage($.menuItemAction("vsWindow"), :none, "pause menu: vsWindow -> none");
	Test.assertEqualMessage($.menuItemAction("vs5"), :none, "pause menu: vs5 -> none");
	return true;
}

// Decision R6 (07/10): each press on "VS window" goes to the next window,
// 1 -> 3 -> 5 -> 1 min. Pure rotation; anything that is not one of the three
// windows (absent, corrupted) restarts the cycle at 1 min.
(:test)
function testNextVsWindowMs(logger)
{
	Test.assertEqualMessage($.nextVsWindowMs(60000), 180000, "1 min -> 3 min");
	Test.assertEqualMessage($.nextVsWindowMs(180000), 300000, "3 min -> 5 min");
	Test.assertEqualMessage($.nextVsWindowMs(300000), 60000, "5 min -> back to 1 min");

	// Invalid values -> 60000.
	Test.assertEqualMessage($.nextVsWindowMs(null), 60000, "null (absent) -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs(0), 60000, "0 -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs(-60000), 60000, "negative -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs(120000), 60000, "2 min (not a choice) -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs(179999), 60000, "just under 3 min -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs(300001), 60000, "just over 5 min -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs(2147483647), 60000, "max Number -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs(3), 60000, "minutes instead of ms -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs("60000"), 60000, "String -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs("180000"), 60000, "String of a choice -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs(60000.0), 60000, "Float 1 min -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs(180000.0), 60000, "Float 3 min -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs(180000l), 60000, "Long -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs(true), 60000, "Boolean -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs([180000]), 60000, "Array -> 60000");
	Test.assertEqualMessage($.nextVsWindowMs(:vs3), 60000, "Symbol -> 60000");

	// Always one of the three windows; three presses come back to the start.
	var c = $.vsWindowChoicesMs();
	for (var i = 0; i < c.size(); i++)
	{
		Test.assertEqualMessage($.sanitizeVsWindowMs($.nextVsWindowMs(c[i])), $.nextVsWindowMs(c[i]), "next of " + c[i] + " is a valid window");
		Test.assertEqualMessage($.nextVsWindowMs($.nextVsWindowMs($.nextVsWindowMs(c[i]))), c[i], "three presses from " + c[i] + " -> back to it");
	}
	return true;
}

// Sub-label shown under "VS window" after each press: the window just chosen.
(:test)
function testVsWindowSubLabelAfterPress(logger)
{
	Test.assertEqualMessage($.vsWindowLabel($.nextVsWindowMs(60000)), "3 min", "1 min pressed -> 3 min shown");
	Test.assertEqualMessage($.vsWindowLabel($.nextVsWindowMs(180000)), "5 min", "3 min pressed -> 5 min shown");
	Test.assertEqualMessage($.vsWindowLabel($.nextVsWindowMs(300000)), "1 min", "5 min pressed -> 1 min shown");
	Test.assertEqualMessage($.vsWindowLabel($.nextVsWindowMs(null)), "1 min", "absent -> 1 min shown");
	Test.assertEqualMessage($.vsWindowLabel($.nextVsWindowMs("abc")), "1 min", "String -> 1 min shown");
	Test.assertEqualMessage($.vsWindowLabel($.nextVsWindowMs(180000.0)), "1 min", "Float -> 1 min shown");
	Test.assertEqualMessage($.vsWindowLabel($.nextVsWindowMs(120000)), "1 min", "outside the list -> 1 min shown");

	// Sub-label of the window itself (menu opening) for odd values.
	Test.assertEqualMessage($.vsWindowLabel(180000.0), "1 min", "Float -> label of the default");
	Test.assertEqualMessage($.vsWindowLabel("180000"), "1 min", "String -> label of the default");
	Test.assertEqualMessage($.vsWindowLabel(180000l), "1 min", "Long -> label of the default");
	Test.assertEqualMessage($.vsWindowLabel(0), "1 min", "zero -> label of the default");

	// A full cycle shows the three labels in order.
	var w = 60000;
	var shown = ["3 min", "5 min", "1 min", "3 min"];
	for (var i = 0; i < shown.size(); i++)
	{
		w = $.nextVsWindowMs(w);
		Test.assertEqualMessage($.vsWindowLabel(w), shown[i], "press " + (i + 1) + " shows " + shown[i]);
	}
	return true;
}

// One press on "VS window" (cycleVsWindow): the next window is read from the
// store, written back at once and pushed to the WatchData read by
// HikePaceView. Both stores are saved and restored (new Preferences(Application.getApp()) runs the
// migration on the old object store).
(:test)
function testCycleVsWindow(logger)
{
	var stored = new StoredPrefsSnapshot();
	var legacy = new LegacyPrefsSnapshot(Application.getApp());
	try
	{
		stored.clear();
		legacy.clear();
		var p = new Preferences(Application.getApp());
		var data = new WatchData();

		// Nothing stored (1 min by default): 3, 5, then back to 1 min.
		Test.assertEqualMessage($.cycleVsWindow(p, data), 180000, "first press -> 3 min");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY), 180000, "3 min written at once");
		Test.assertEqualMessage(data.getHikeVsWindowMs(), 180000, "3 min in WatchData");
		Test.assertEqualMessage($.cycleVsWindow(p, data), 300000, "second press -> 5 min");
		Test.assertEqualMessage(p.getVsWindowMs(), 300000, "5 min stored");
		Test.assertEqualMessage(data.getHikeVsWindowMs(), 300000, "5 min in WatchData");
		Test.assertEqualMessage($.cycleVsWindow(p, data), 60000, "third press -> back to 1 min");
		Test.assertEqualMessage(p.getVsWindowMs(), 60000, "1 min stored");
		Test.assertEqualMessage(data.getHikeVsWindowMs(), 60000, "1 min in WatchData");

		// Kept after a relaunch (a new Preferences reads the store).
		$.cycleVsWindow(p, data);
		Test.assertEqualMessage(new Preferences(Application.getApp()).getVsWindowMs(), 180000, "3 min read back after a relaunch");

		// Corrupted store: read as 1 min, so the press gives 3 min.
		Application.Storage.setValue($.PREF_VS_WINDOW_KEY, "abc");
		Test.assertEqualMessage($.cycleVsWindow(p, data), 180000, "String in the store -> 3 min");
		Application.Storage.setValue($.PREF_VS_WINDOW_KEY, 180000.0);
		Test.assertEqualMessage($.cycleVsWindow(p, data), 180000, "Float in the store -> 3 min");
		Application.Storage.setValue($.PREF_VS_WINDOW_KEY, 120000);
		Test.assertEqualMessage($.cycleVsWindow(p, data), 180000, "value outside the list -> 3 min");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY), 180000, "a valid window replaces the corrupted one");

		// No WatchData yet (menu before the views exist): stored only, no crash.
		Test.assertEqualMessage($.cycleVsWindow(p, null), 300000, "no WatchData -> still cycles");
		Test.assertEqualMessage(p.getVsWindowMs(), 300000, "stored without WatchData");

		// No Preferences: the WatchData window is the current one.
		data.setHikeVsWindowMs(300000);
		Test.assertEqualMessage($.cycleVsWindow(null, data), 60000, "no Preferences -> from the WatchData window");
		Test.assertEqualMessage(data.getHikeVsWindowMs(), 60000, "WatchData set without Preferences");
		Test.assertEqualMessage(p.getVsWindowMs(), 300000, "store untouched without Preferences");

		// Neither: default 1 min -> 3 min, no crash.
		Test.assertEqualMessage($.cycleVsWindow(null, null), 180000, "nothing at all -> 3 min, no crash");

		// The beep preference is a separate key.
		p.setBeep(true);
		$.cycleVsWindow(p, data);
		Test.assertEqualMessage(p.getBeep(), true, "VS window press does not change the beep");
	}
	finally
	{
		stored.restore();
		legacy.restore();
	}
	return true;
}

// ---------------------------------------------------------------------------
// Preferences in Application.Storage (decision D6, 07/10). The tests below
// that touch the real stores save them first and put them back at the end,
// whatever happens (StoredPrefsSnapshot, LegacyPrefsSnapshot).

// Storage values of the two preference keys (beep, VS window).
(:test, :typecheck(false))
class StoredPrefsSnapshot
{
	var beep;
	var vsWindow;

	function initialize()
	{
		beep = Application.Storage.getValue($.PREF_BEEP_KEY);
		vsWindow = Application.Storage.getValue($.PREF_VS_WINDOW_KEY);
	}

	function clear()
	{
		Application.Storage.deleteValue($.PREF_BEEP_KEY);
		Application.Storage.deleteValue($.PREF_VS_WINDOW_KEY);
	}

	function restore()
	{
		put($.PREF_BEEP_KEY, beep);
		put($.PREF_VS_WINDOW_KEY, vsWindow);
	}

	function put(key, value)
	{
		if (value == null)
		{
			Application.Storage.deleteValue(key);
		}
		else
		{
			Application.Storage.setValue(key, value);
		}
	}
}

// MIGRATION TESTS ONLY: the deprecated AppBase object store (getProperty /
// setProperty / deleteProperty), where versions before D6 kept the two keys.
(:test, :typecheck(false))
class LegacyPrefsSnapshot
{
	var app;
	var beep;
	var vsWindow;

	function initialize(appInstance)
	{
		app = appInstance;
		beep = app.getProperty($.PREF_BEEP_KEY);
		vsWindow = app.getProperty($.PREF_VS_WINDOW_KEY);
	}

	function clear()
	{
		app.deleteProperty($.PREF_BEEP_KEY);
		app.deleteProperty($.PREF_VS_WINDOW_KEY);
	}

	// What a version before D6 did on a preference change.
	function writeAsOldVersion(key, value)
	{
		app.setProperty(key, value);
	}

	function read(key)
	{
		return app.getProperty(key);
	}

	function restore()
	{
		if (beep == null) { app.deleteProperty($.PREF_BEEP_KEY); } else { app.setProperty($.PREF_BEEP_KEY, beep); }
		if (vsWindow == null) { app.deleteProperty($.PREF_VS_WINDOW_KEY); } else { app.setProperty($.PREF_VS_WINDOW_KEY, vsWindow); }
	}
}

// Stand-in for the old object store, so the migration rules can be checked
// without the real AppBase: same getProperty / deleteProperty as AppBase.
// failGetKeys / failDeleteKeys (empty by default): keys whose getProperty /
// deleteProperty throws, like a damaged or removed object store. Kept in this
// class rather than a new one: the 'globals' module is close to its
// 253-member limit on fenix6pro.
(:test)
class FakeLegacyStore
{
	var values;
	var deleteCalls;
	var failGetKeys;
	var failDeleteKeys;

	function initialize(dict)
	{
		values = dict;
		deleteCalls = 0;
		failGetKeys = [];
		failDeleteKeys = [];
	}

	function getProperty(key)
	{
		if (failGetKeys.indexOf(key) >= 0)
		{
			throw new FakeStoreException();
		}
		return values.get(key);
	}

	function deleteProperty(key)
	{
		deleteCalls += 1;
		if (failDeleteKeys.indexOf(key) >= 0)
		{
			throw new FakeStoreException();
		}
		values.remove(key);
	}
}

// A firmware where AppBase.getProperty has been removed ("may be removed
// after System 4"): no getProperty, nothing to migrate.
(:test)
class NoLegacyStore
{
	function initialize() {}
}

(:test)
function testSanitizeBeep(logger)
{
	Test.assertEqualMessage($.sanitizeBeep(true), true, "true -> true");
	Test.assertEqualMessage($.sanitizeBeep(false), false, "false -> false");
	Test.assertEqualMessage($.sanitizeBeep(null), false, "absent -> default false");
	Test.assertEqualMessage($.sanitizeBeep(1), false, "Number 1 (corrupted) -> false");
	Test.assertEqualMessage($.sanitizeBeep(0), false, "Number 0 (corrupted) -> false");
	Test.assertEqualMessage($.sanitizeBeep(1.0), false, "Float (corrupted) -> false");
	Test.assertEqualMessage($.sanitizeBeep("true"), false, "String \"true\" (corrupted) -> false");
	Test.assertEqualMessage($.sanitizeBeep([true]), false, "Array (corrupted) -> false");
	return true;
}

(:test)
function testSanitizePreference(logger)
{
	Test.assertEqualMessage($.sanitizePreference($.PREF_BEEP_KEY, true), true, "beep true kept");
	Test.assertEqualMessage($.sanitizePreference($.PREF_BEEP_KEY, false), false, "beep false kept");
	Test.assertEqualMessage($.sanitizePreference($.PREF_BEEP_KEY, 5), false, "beep corrupted -> false");
	Test.assertEqualMessage($.sanitizePreference($.PREF_BEEP_KEY, null), false, "beep absent -> false");
	Test.assertEqualMessage($.sanitizePreference($.PREF_VS_WINDOW_KEY, 300000), 300000, "VS 5 min kept");
	Test.assertEqualMessage($.sanitizePreference($.PREF_VS_WINDOW_KEY, 180000), 180000, "VS 3 min kept");
	Test.assertEqualMessage($.sanitizePreference($.PREF_VS_WINDOW_KEY, "abc"), 60000, "VS String -> 60000");
	Test.assertEqualMessage($.sanitizePreference($.PREF_VS_WINDOW_KEY, 120000), 60000, "VS unknown Number -> 60000");
	Test.assertEqualMessage($.sanitizePreference($.PREF_VS_WINDOW_KEY, 180000.0), 60000, "VS Float -> 60000");
	Test.assertEqualMessage($.sanitizePreference($.PREF_VS_WINDOW_KEY, null), 60000, "VS absent -> 60000");
	Test.assertEqualMessage($.sanitizePreference($.PREF_VS_WINDOW_KEY, true), 60000, "VS Boolean -> 60000");
	// Not one of the two migrated keys: nothing to write.
	Test.assertMessage($.sanitizePreference("other", 5) == null, "unknown key -> null");
	Test.assertMessage($.sanitizePreference(null, true) == null, "null key -> null");
	return true;
}

// Pure decision: (value already in Storage, value in the old store) -> value
// kept. Storage wins as soon as it holds something (false included): it was
// written by this version, after the migration or by the user.
(:test)
function testPreferenceToKeep(logger)
{
	Test.assertMessage($.preferenceToKeep(null, null) == null, "nothing anywhere -> null (default on read)");
	Test.assertEqualMessage($.preferenceToKeep(null, true), true, "first launch: old beep taken");
	Test.assertEqualMessage($.preferenceToKeep(null, false), false, "first launch: old beep false taken");
	Test.assertEqualMessage($.preferenceToKeep(null, 300000), 300000, "first launch: old VS window taken");
	Test.assertEqualMessage($.preferenceToKeep(null, "abc"), "abc", "old corrupted value passed on (sanitized by the caller)");
	Test.assertEqualMessage($.preferenceToKeep(180000, 300000), 180000, "Storage wins over a stale old value");
	Test.assertEqualMessage($.preferenceToKeep(false, true), false, "Storage false is a value: wins over old true");
	Test.assertEqualMessage($.preferenceToKeep(0, 300000), 0, "Storage zero is a value: wins (sanitized later)");
	Test.assertEqualMessage($.preferenceToKeep(180000, null), 180000, "after the update: Storage kept");
	return true;
}

// Migration rules against a stand-in for the old store. The real old store is
// saved and restored too: the `new Preferences(Application.getApp())` below migrates it.
(:test)
function testMigrateLegacyPreferencesRules(logger)
{
	var snap = new StoredPrefsSnapshot();
	var legacy = new LegacyPrefsSnapshot(Application.getApp());
	try
	{
		// Value taken from the old store, old key removed.
		snap.clear();
		var old = new FakeLegacyStore({ $.PREF_BEEP_KEY => true, $.PREF_VS_WINDOW_KEY => 300000 });
		Test.assertEqualMessage($.migrateLegacyPreferences(old), 2, "two keys migrated");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_BEEP_KEY), true, "beep true now in Storage");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY), 300000, "5 min now in Storage");
		Test.assertMessage(old.getProperty($.PREF_BEEP_KEY) == null, "old beep key removed");
		Test.assertMessage(old.getProperty($.PREF_VS_WINDOW_KEY) == null, "old VS key removed");

		// Second launch: nothing left to migrate, Storage untouched.
		Test.assertEqualMessage($.migrateLegacyPreferences(old), 0, "second run -> nothing migrated");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY), 300000, "second run keeps 5 min");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_BEEP_KEY), true, "second run keeps beep");

		// Old beep false is a value: written as false, not left absent.
		snap.clear();
		old = new FakeLegacyStore({ $.PREF_BEEP_KEY => false });
		Test.assertEqualMessage($.migrateLegacyPreferences(old), 1, "beep false migrated");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_BEEP_KEY), false, "beep false in Storage");
		Test.assertMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY) == null, "absent VS window not written");

		// Nothing anywhere: nothing written, defaults on read.
		snap.clear();
		old = new FakeLegacyStore({});
		Test.assertEqualMessage($.migrateLegacyPreferences(old), 0, "empty old store -> nothing migrated");
		Test.assertEqualMessage(old.deleteCalls, 0, "empty old store -> no delete");
		Test.assertMessage(Application.Storage.getValue($.PREF_BEEP_KEY) == null, "beep not written");
		Test.assertMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY) == null, "VS window not written");
		var p = new Preferences(Application.getApp());
		Test.assertEqualMessage(p.getBeep(), false, "absent -> beep default false");
		Test.assertEqualMessage(p.getVsWindowMs(), 60000, "absent -> VS default 60000");

		// Corrupted old values: the defaults are written, old keys removed.
		snap.clear();
		old = new FakeLegacyStore({ $.PREF_BEEP_KEY => 5, $.PREF_VS_WINDOW_KEY => "abc" });
		Test.assertEqualMessage($.migrateLegacyPreferences(old), 2, "corrupted keys migrated");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_BEEP_KEY), false, "corrupted beep -> false stored");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY), 60000, "corrupted VS -> 60000 stored");
		Test.assertMessage(old.getProperty($.PREF_BEEP_KEY) == null, "corrupted old beep removed");
		Test.assertMessage(old.getProperty($.PREF_VS_WINDOW_KEY) == null, "corrupted old VS removed");
		snap.clear();
		old = new FakeLegacyStore({ $.PREF_VS_WINDOW_KEY => 120000 });
		$.migrateLegacyPreferences(old);
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY), 60000, "unknown old Number -> 60000");
		snap.clear();
		old = new FakeLegacyStore({ $.PREF_VS_WINDOW_KEY => 180000.0 });
		$.migrateLegacyPreferences(old);
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY), 60000, "old Float -> 60000");

		// Storage already set (by this version) and a stale old key: Storage
		// wins, the old key is removed.
		snap.clear();
		Application.Storage.setValue($.PREF_VS_WINDOW_KEY, 180000);
		Application.Storage.setValue($.PREF_BEEP_KEY, false);
		old = new FakeLegacyStore({ $.PREF_BEEP_KEY => true, $.PREF_VS_WINDOW_KEY => 300000 });
		Test.assertEqualMessage($.migrateLegacyPreferences(old), 2, "stale old keys handled");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY), 180000, "Storage 3 min kept");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_BEEP_KEY), false, "Storage beep false kept");
		Test.assertMessage(old.getProperty($.PREF_VS_WINDOW_KEY) == null, "stale old VS removed");
		Test.assertMessage(old.getProperty($.PREF_BEEP_KEY) == null, "stale old beep removed");

		// Other keys of the old store are not touched (out of scope).
		snap.clear();
		old = new FakeLegacyStore({ "other" => 7 });
		Test.assertEqualMessage($.migrateLegacyPreferences(old), 0, "unrelated key -> nothing migrated");
		Test.assertEqualMessage(old.getProperty("other"), 7, "unrelated key left in place");

		// No old store at all (getProperty removed, or null): no crash.
		snap.clear();
		Test.assertEqualMessage($.migrateLegacyPreferences(new NoLegacyStore()), 0, "no getProperty -> 0");
		Test.assertEqualMessage($.migrateLegacyPreferences(null), 0, "null -> 0");
		Test.assertMessage(Application.Storage.getValue($.PREF_BEEP_KEY) == null, "no old store -> nothing written");
	}
	finally
	{
		snap.restore();
		legacy.restore();
	}
	return true;
}

// The real thing: values written by a version before D6 with
// AppBase.setProperty, then this version starts (new Preferences(Application.getApp()) runs the
// migration) and starts again, and the user changes a value.
(:test)
function testMigrateLegacyPreferencesRealStoreAfterUpdate(logger)
{
	var app = Application.getApp();
	var stored = new StoredPrefsSnapshot();
	var legacy = new LegacyPrefsSnapshot(app);
	try
	{
		stored.clear();
		legacy.clear();
		legacy.writeAsOldVersion($.PREF_BEEP_KEY, true);
		legacy.writeAsOldVersion($.PREF_VS_WINDOW_KEY, 180000);

		// First launch after the update.
		var p = new Preferences(Application.getApp());
		Test.assertEqualMessage(p.getBeep(), true, "old beep true taken over");
		Test.assertEqualMessage(p.getVsWindowMs(), 180000, "old 3 min taken over");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_BEEP_KEY), true, "beep in Storage");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY), 180000, "3 min in Storage");
		Test.assertMessage(legacy.read($.PREF_BEEP_KEY) == null, "old beep key erased");
		Test.assertMessage(legacy.read($.PREF_VS_WINDOW_KEY) == null, "old VS key erased");

		// Next launch: values kept.
		p = new Preferences(Application.getApp());
		Test.assertEqualMessage(p.getBeep(), true, "beep kept on the next launch");
		Test.assertEqualMessage(p.getVsWindowMs(), 180000, "3 min kept on the next launch");

		// Changed in this version, then relaunched: the new values stay.
		p.setBeep(false);
		p.setVsWindowMs(300000);
		p = new Preferences(Application.getApp());
		Test.assertEqualMessage(p.getBeep(), false, "beep false kept after a relaunch");
		Test.assertEqualMessage(p.getVsWindowMs(), 300000, "5 min kept after a relaunch");
		Test.assertMessage(legacy.read($.PREF_BEEP_KEY) == null, "nothing written back to the old store");
		Test.assertMessage(legacy.read($.PREF_VS_WINDOW_KEY) == null, "nothing written back to the old store (VS)");

		// Corrupted old value on the real store -> default.
		stored.clear();
		legacy.writeAsOldVersion($.PREF_VS_WINDOW_KEY, "abc");
		p = new Preferences(Application.getApp());
		Test.assertEqualMessage(p.getVsWindowMs(), 60000, "real store, corrupted old VS -> 60000");
		Test.assertMessage(legacy.read($.PREF_VS_WINDOW_KEY) == null, "real store, corrupted old VS erased");
	}
	finally
	{
		stored.restore();
		legacy.restore();
	}
	return true;
}

// Stand-in for Application.Storage in the migration (getValue / setValue),
// with keys whose read or write throws, like a full store (setValue raises an
// exception when the object store is full).
(:test)
class FakePrefStore
{
	var values;
	var failSetKeys;
	var failGetKeys;
	var setCalls;

	function initialize(dict, failSet, failGet)
	{
		values = dict;
		failSetKeys = failSet;
		failGetKeys = failGet;
		setCalls = 0;
	}

	function getValue(key)
	{
		if (failGetKeys.indexOf(key) >= 0)
		{
			throw new FakeStoreException();
		}
		return values.get(key);
	}

	function setValue(key, value)
	{
		setCalls += 1;
		if (failSetKeys.indexOf(key) >= 0)
		{
			throw new FakeStoreException();
		}
		values.put(key, value);
	}
}

(:test)
class FakeStoreException extends Toybox.Lang.Exception
{
	function initialize()
	{
		Exception.initialize();
	}
}

// Start-up migration against a stand-in Storage: empty store, values already
// there (Storage wins), and a store whose write or read throws. A key that
// could not be written keeps its old value for the next launch, the other key
// is still migrated, and no exception leaves the migration (the app starts).
(:test)
function testMigrateLegacyPreferencesToStore(logger)
{
	// Empty Storage: the old values are taken, sanitized, old keys erased.
	var store = new FakePrefStore({}, [], []);
	var old = new FakeLegacyStore({ $.PREF_BEEP_KEY => true, $.PREF_VS_WINDOW_KEY => 300000 });
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 2, "empty store: two keys migrated");
	Test.assertEqualMessage(store.values.get($.PREF_BEEP_KEY), true, "empty store: beep true written");
	Test.assertEqualMessage(store.values.get($.PREF_VS_WINDOW_KEY), 300000, "empty store: 5 min written");
	Test.assertEqualMessage(old.deleteCalls, 2, "empty store: both old keys erased");
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 0, "second launch: nothing left");
	Test.assertEqualMessage(store.setCalls, 2, "second launch: nothing written");

	// Values already in Storage: Storage wins (false included), old keys erased.
	store = new FakePrefStore({ $.PREF_BEEP_KEY => false, $.PREF_VS_WINDOW_KEY => 180000 }, [], []);
	old = new FakeLegacyStore({ $.PREF_BEEP_KEY => true, $.PREF_VS_WINDOW_KEY => 300000 });
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 2, "values present: two keys handled");
	Test.assertEqualMessage(store.values.get($.PREF_BEEP_KEY), false, "values present: Storage beep false kept");
	Test.assertEqualMessage(store.values.get($.PREF_VS_WINDOW_KEY), 180000, "values present: Storage 3 min kept");
	Test.assertMessage(old.getProperty($.PREF_BEEP_KEY) == null, "values present: old beep erased");

	// Corrupted value already in Storage: it still wins, written back sanitized.
	store = new FakePrefStore({ $.PREF_VS_WINDOW_KEY => "abc" }, [], []);
	old = new FakeLegacyStore({ $.PREF_VS_WINDOW_KEY => 300000 });
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 1, "corrupted Storage: handled");
	Test.assertEqualMessage(store.values.get($.PREF_VS_WINDOW_KEY), 60000, "corrupted Storage wins, sanitized to 60000");

	// No old key: Storage left alone, nothing written.
	store = new FakePrefStore({ $.PREF_VS_WINDOW_KEY => 180000 }, [], []);
	old = new FakeLegacyStore({});
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 0, "no old key: nothing migrated");
	Test.assertEqualMessage(store.setCalls, 0, "no old key: no write");

	// setValue throws for the beep: the beep keeps its old key, the VS window
	// is still migrated, and nothing escapes.
	store = new FakePrefStore({}, [$.PREF_BEEP_KEY], []);
	old = new FakeLegacyStore({ $.PREF_BEEP_KEY => true, $.PREF_VS_WINDOW_KEY => 300000 });
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 1, "beep write throws: only the VS window migrated");
	Test.assertEqualMessage(old.getProperty($.PREF_BEEP_KEY), true, "beep write throws: old beep kept for the next launch");
	Test.assertMessage(store.values.get($.PREF_BEEP_KEY) == null, "beep write throws: nothing stored for the beep");
	Test.assertEqualMessage(store.values.get($.PREF_VS_WINDOW_KEY), 300000, "beep write throws: 5 min still stored");
	Test.assertMessage(old.getProperty($.PREF_VS_WINDOW_KEY) == null, "beep write throws: old VS key erased");
	// Next launch, the store works again: the beep is carried over then.
	store.failSetKeys = [];
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 1, "next launch: the beep is migrated");
	Test.assertEqualMessage(store.values.get($.PREF_BEEP_KEY), true, "next launch: beep true stored");
	Test.assertMessage(old.getProperty($.PREF_BEEP_KEY) == null, "next launch: old beep erased");

	// Every write throws (full store): nothing migrated, nothing erased.
	store = new FakePrefStore({}, [$.PREF_BEEP_KEY, $.PREF_VS_WINDOW_KEY], []);
	old = new FakeLegacyStore({ $.PREF_BEEP_KEY => false, $.PREF_VS_WINDOW_KEY => 180000 });
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 0, "full store: nothing migrated");
	Test.assertEqualMessage(old.deleteCalls, 0, "full store: no old key erased");
	Test.assertEqualMessage(store.setCalls, 2, "full store: both writes tried");

	// The read throws: same as a failed write for that key.
	store = new FakePrefStore({}, [], [$.PREF_VS_WINDOW_KEY]);
	old = new FakeLegacyStore({ $.PREF_BEEP_KEY => true, $.PREF_VS_WINDOW_KEY => 180000 });
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 1, "VS read throws: only the beep migrated");
	Test.assertEqualMessage(old.getProperty($.PREF_VS_WINDOW_KEY), 180000, "VS read throws: old VS kept");
	Test.assertMessage(store.values.get($.PREF_VS_WINDOW_KEY) == null, "VS read throws: nothing written for VS");

	// No old store, or no store at all: 0, no crash.
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(null, new FakePrefStore({}, [], [])), 0, "null old store -> 0");
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(new NoLegacyStore(), new FakePrefStore({}, [], [])), 0, "no getProperty -> 0");
	old = new FakeLegacyStore({ $.PREF_BEEP_KEY => true });
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, null), 0, "null store -> 0");
	Test.assertEqualMessage(old.getProperty($.PREF_BEEP_KEY), true, "null store: old beep kept");

	// Review of 08/10: the OLD store throws (getProperty or deleteProperty).
	// Nothing escapes the start-up migration; the key concerned is skipped,
	// the other one is still migrated. A key counts as migrated only once its
	// old copy is erased. Storage still wins (decision of the user).

	// getProperty throws for the beep: beep untouched (nothing written,
	// nothing erased), VS window migrated.
	store = new FakePrefStore({}, [], []);
	old = new FakeLegacyStore({ $.PREF_BEEP_KEY => true, $.PREF_VS_WINDOW_KEY => 300000 });
	old.failGetKeys = [$.PREF_BEEP_KEY];
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 1, "old beep read throws: only the VS window migrated");
	Test.assertMessage(store.values.get($.PREF_BEEP_KEY) == null, "old beep read throws: nothing stored for the beep");
	Test.assertEqualMessage(store.values.get($.PREF_VS_WINDOW_KEY), 300000, "old beep read throws: 5 min stored");
	Test.assertEqualMessage(old.values.get($.PREF_BEEP_KEY), true, "old beep read throws: old beep left for the next launch");
	Test.assertEqualMessage(old.deleteCalls, 1, "old beep read throws: only the VS key erased");

	// Every old read throws: nothing read from Storage, nothing written.
	store = new FakePrefStore({}, [], []);
	old = new FakeLegacyStore({ $.PREF_BEEP_KEY => true, $.PREF_VS_WINDOW_KEY => 300000 });
	old.failGetKeys = [$.PREF_BEEP_KEY, $.PREF_VS_WINDOW_KEY];
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 0, "every old read throws: nothing migrated");
	Test.assertEqualMessage(store.setCalls, 0, "every old read throws: no write");
	Test.assertEqualMessage(old.deleteCalls, 0, "every old read throws: no erase");

	// deleteProperty throws for the VS window: its value is already in
	// Storage (kept), the old key stays, it is not counted; the beep is
	// migrated.
	store = new FakePrefStore({}, [], []);
	old = new FakeLegacyStore({ $.PREF_BEEP_KEY => true, $.PREF_VS_WINDOW_KEY => 300000 });
	old.failDeleteKeys = [$.PREF_VS_WINDOW_KEY];
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 1, "old VS erase throws: only the beep counted");
	Test.assertEqualMessage(store.values.get($.PREF_VS_WINDOW_KEY), 300000, "old VS erase throws: 5 min already stored");
	Test.assertEqualMessage(store.values.get($.PREF_BEEP_KEY), true, "old VS erase throws: beep stored");
	Test.assertEqualMessage(old.values.get($.PREF_VS_WINDOW_KEY), 300000, "old VS erase throws: old VS key still there");
	Test.assertMessage(old.values.get($.PREF_BEEP_KEY) == null, "old VS erase throws: old beep erased");
	// The user then picks 1 min; next launch, the erase works: Storage wins
	// over the stale old 5 min, the old key is erased.
	store.values.put($.PREF_VS_WINDOW_KEY, 60000);
	old.failDeleteKeys = [];
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 1, "next launch: old VS key handled");
	Test.assertEqualMessage(store.values.get($.PREF_VS_WINDOW_KEY), 60000, "next launch: Storage 1 min wins");
	Test.assertMessage(old.values.get($.PREF_VS_WINDOW_KEY) == null, "next launch: old VS key erased");

	// Every erase throws: both values stored, both old keys kept, 0 counted.
	store = new FakePrefStore({}, [], []);
	old = new FakeLegacyStore({ $.PREF_BEEP_KEY => false, $.PREF_VS_WINDOW_KEY => 180000 });
	old.failDeleteKeys = [$.PREF_BEEP_KEY, $.PREF_VS_WINDOW_KEY];
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 0, "every erase throws: 0 counted");
	Test.assertEqualMessage(store.values.get($.PREF_BEEP_KEY), false, "every erase throws: beep false stored");
	Test.assertEqualMessage(store.values.get($.PREF_VS_WINDOW_KEY), 180000, "every erase throws: 3 min stored");
	Test.assertEqualMessage(old.deleteCalls, 2, "every erase throws: both erases tried");

	// A failed Storage write is never followed by an erase, even when the
	// erase would throw too.
	store = new FakePrefStore({}, [$.PREF_BEEP_KEY], []);
	old = new FakeLegacyStore({ $.PREF_BEEP_KEY => true });
	old.failDeleteKeys = [$.PREF_BEEP_KEY];
	Test.assertEqualMessage($.migrateLegacyPreferencesTo(old, store), 0, "write and erase throw: 0");
	Test.assertEqualMessage(old.deleteCalls, 0, "write throws: no erase tried");
	return true;
}

// Start-up path: FlyInstrumentApp.initialize() builds `new Preferences(self)`,
// so the migration reads the object it is given, not Application.getApp().
// A stand-in old store is given here while the real one holds another value:
// the real one must not be read nor erased. Both stores restored at the end.
(:test)
function testPreferencesStartupMigratesGivenApp(logger)
{
	var stored = new StoredPrefsSnapshot();
	var legacy = new LegacyPrefsSnapshot(Application.getApp());
	try
	{
		// Empty Storage, old values in the given object.
		stored.clear();
		legacy.clear();
		legacy.writeAsOldVersion($.PREF_VS_WINDOW_KEY, 180000);
		var given = new FakeLegacyStore({ $.PREF_BEEP_KEY => true, $.PREF_VS_WINDOW_KEY => 300000 });
		var p = new Preferences(given);
		Test.assertEqualMessage(p.getBeep(), true, "beep taken from the given app");
		Test.assertEqualMessage(p.getVsWindowMs(), 300000, "5 min taken from the given app");
		Test.assertEqualMessage(given.deleteCalls, 2, "old keys of the given app erased");
		Test.assertEqualMessage(legacy.read($.PREF_VS_WINDOW_KEY), 180000, "Application.getApp() store not touched");

		// Values already in Storage: Storage wins on start-up.
		given = new FakeLegacyStore({ $.PREF_BEEP_KEY => false, $.PREF_VS_WINDOW_KEY => 60000 });
		p = new Preferences(given);
		Test.assertEqualMessage(p.getBeep(), true, "start-up: Storage beep wins");
		Test.assertEqualMessage(p.getVsWindowMs(), 300000, "start-up: Storage 5 min wins");
		Test.assertMessage(given.getProperty($.PREF_BEEP_KEY) == null, "start-up: stale old beep erased");

		// No app object, or one without the old store: defaults, no crash.
		stored.clear();
		p = new Preferences(null);
		Test.assertEqualMessage(p.getBeep(), false, "null app: beep default");
		Test.assertEqualMessage(p.getVsWindowMs(), 60000, "null app: VS default");
		p = new Preferences(new NoLegacyStore());
		Test.assertEqualMessage(p.getVsWindowMs(), 60000, "no getProperty: VS default");
		Test.assertEqualMessage(legacy.read($.PREF_VS_WINDOW_KEY), 180000, "real old store still untouched");

		// Review of 08/10: an old store whose getProperty / deleteProperty
		// throw must not stop the start-up (`new Preferences(app)` raising
		// would keep the app from starting). Here in this test rather than in
		// a new one: the 'globals' module is at its 253-member limit on
		// fenix6pro.
		Application.Storage.setValue($.PREF_VS_WINDOW_KEY, 180000);
		given = new FakeLegacyStore({ $.PREF_BEEP_KEY => true, $.PREF_VS_WINDOW_KEY => 300000 });
		given.failGetKeys = [$.PREF_BEEP_KEY];
		given.failDeleteKeys = [$.PREF_VS_WINDOW_KEY];
		p = new Preferences(given);
		Test.assertEqualMessage(p.getBeep(), false, "throwing old store: beep default (old read failed)");
		Test.assertEqualMessage(p.getVsWindowMs(), 180000, "throwing old store: Storage 3 min wins");
		Test.assertEqualMessage(given.values.get($.PREF_BEEP_KEY), true, "throwing old store: old beep kept");
		Test.assertEqualMessage(given.values.get($.PREF_VS_WINDOW_KEY), 300000, "throwing old store: old VS kept (erase failed)");
		Test.assertEqualMessage(legacy.read($.PREF_VS_WINDOW_KEY), 180000, "throwing old store: real old store untouched");
	}
	finally
	{
		stored.restore();
		legacy.restore();
	}
	return true;
}

// Beep against Storage. Old store saved and restored (new Preferences(Application.getApp())
// migrates it).
(:test)
function testPreferencesBeepStore(logger)
{
	var snap = new StoredPrefsSnapshot();
	var legacy = new LegacyPrefsSnapshot(Application.getApp());
	try
	{
		snap.clear();
		var p = new Preferences(Application.getApp());
		Test.assertEqualMessage(p.getBeep(), false, "nothing stored -> false");

		p.setBeep(true);
		Test.assertEqualMessage(p.getBeep(), true, "true stored");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_BEEP_KEY), true, "true in Storage");
		Test.assertEqualMessage(new Preferences(Application.getApp()).getBeep(), true, "read back by a new Preferences (store, not a cache)");
		p.setBeep(false);
		Test.assertEqualMessage(p.getBeep(), false, "false stored");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_BEEP_KEY), false, "false in Storage (a value, not absent)");

		// Corrupted values in Storage.
		Application.Storage.setValue($.PREF_BEEP_KEY, 1);
		Test.assertEqualMessage(p.getBeep(), false, "Number in Storage -> false");
		Application.Storage.setValue($.PREF_BEEP_KEY, "true");
		Test.assertEqualMessage(p.getBeep(), false, "String in Storage -> false");

		// set() never writes an invalid value.
		p.setBeep(true);
		p.setBeep(null);
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_BEEP_KEY), false, "null set -> false stored");
		p.setBeep(1);
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_BEEP_KEY), false, "Number set -> false stored");

		// The VS window is a separate key.
		p.setVsWindowMs(300000);
		p.setBeep(true);
		Test.assertEqualMessage(p.getVsWindowMs(), 300000, "beep does not change the VS window");
	}
	finally
	{
		snap.restore();
		legacy.restore();
	}
	return true;
}

// VS window against Storage. Old store saved and restored (new Preferences(Application.getApp())
// migrates it).
(:test)
function testPreferencesVsWindowStore(logger)
{
	var snap = new StoredPrefsSnapshot();
	var legacy = new LegacyPrefsSnapshot(Application.getApp());
	try
	{
		snap.clear();
		var p = new Preferences(Application.getApp());
		Test.assertEqualMessage(p.getVsWindowMs(), 60000, "nothing stored -> 60000");

		p.setVsWindowMs(300000);
		Test.assertEqualMessage(p.getVsWindowMs(), 300000, "5 min stored -> 300000");
		Test.assertEqualMessage(new Preferences(Application.getApp()).getVsWindowMs(), 300000, "read back by a new Preferences (store, not a cache)");
		p.setVsWindowMs(180000);
		Test.assertEqualMessage(p.getVsWindowMs(), 180000, "3 min stored -> 180000");
		p.setVsWindowMs(60000);
		Test.assertEqualMessage(p.getVsWindowMs(), 60000, "1 min stored -> 60000");

		// Corrupted values in the store.
		Application.Storage.setValue($.PREF_VS_WINDOW_KEY, "abc");
		Test.assertEqualMessage(p.getVsWindowMs(), 60000, "String in the store -> 60000");
		Application.Storage.setValue($.PREF_VS_WINDOW_KEY, 120000);
		Test.assertEqualMessage(p.getVsWindowMs(), 60000, "unknown Number in the store -> 60000");
		Application.Storage.setValue($.PREF_VS_WINDOW_KEY, 180000.0);
		Test.assertEqualMessage(p.getVsWindowMs(), 60000, "Float in the store -> 60000");
		Application.Storage.setValue($.PREF_VS_WINDOW_KEY, 0);
		Test.assertEqualMessage(p.getVsWindowMs(), 60000, "zero in the store -> 60000");

		// set() never writes an invalid value.
		p.setVsWindowMs(300000);
		p.setVsWindowMs(42);
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY), 60000, "invalid set -> the default is stored");
		p.setVsWindowMs(null);
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY), 60000, "null set -> the default is stored");

		// The beep preference is a separate key.
		var beep = p.getBeep();
		p.setVsWindowMs(300000);
		Test.assertEqualMessage(p.getBeep(), beep, "VS window does not change the beep");
	}
	finally
	{
		snap.restore();
		legacy.restore();
	}
	return true;
}

// HikeHistory with each of the three windows. Synthetic: alt = 1500 + s^2 / 3600
// (s in seconds), one sample / 5 s from 0 to 300 s. On evenly spaced samples
// the least-squares slope of a parabola is its derivative at the window's
// centre, 2 * centre / 3600 m/s = 2 * centre m/h:
// - 60 s: samples 240..300, centre 270 -> 540 m/h;
// - 180 s: samples 120..300, centre 210 -> 420 m/h;
// - 300 s: 61 samples, but the buffer holds 60: 5..300, centre 152.5 -> 305 m/h.
(:test)
function testHikeHistoryWindows60180300(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;
	for (var s = 0; s <= 300; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0 + s * s / 3600.0, null);
	}
	Test.assertEqualMessage(h.getCount(), 60, "61 samples offered, 60 kept (buffer capacity)");
	var now = t0 + 300000;

	var v60 = h.verticalSpeedMh(now, 60000);
	logger.debug("parabola, 60 s -> " + v60);
	Test.assertMessage(v60 != null && v60 > 539.0 && v60 < 541.0, "60 s window -> 540 +/- 1, got " + v60);
	var v180 = h.verticalSpeedMh(now, 180000);
	logger.debug("parabola, 180 s -> " + v180);
	Test.assertMessage(v180 != null && v180 > 419.0 && v180 < 421.0, "180 s window -> 420 +/- 1, got " + v180);
	var v300 = h.verticalSpeedMh(now, 300000);
	logger.debug("parabola, 300 s -> " + v300);
	Test.assertMessage(v300 != null && v300 > 304.0 && v300 < 306.0, "300 s window -> 305 +/- 1 (oldest sample overwritten), got " + v300);
	return true;
}

// Real Salvan climb (same rows as testHikeHistorySalvanRealClimb, 11:07:11 ->
// 11:09:21, 130 s) with the three windows. Hand-computed least squares:
// - at 11:08:48 (97 s, 18 samples): 180 and 300 s both see the whole 97 s,
//   Sxy = 1976.7, Sxx = 15460.5 -> 460.3 m/h (the 60 s window reads ~524);
// - at 11:09:21 (130 s, 24 samples): 60 s (70..130 s) Sxy = 850.5,
//   Sxx = 4100.25 -> 746.7 m/h; 180 and 300 s see the whole 130 s,
//   Sxy = 5390.1, Sxx = 35711.0 -> 543.4 m/h.
// For reference the plan's "+9.6 m in 67 s = +516 m/h" (2253.0 -> 2262.6 m,
// 11:07:41 -> 11:08:48) is an end-point difference, not one of these windows.
(:test)
function testHikeHistorySalvanWindows(logger)
{
	var secs = [0, 7, 14, 20, 25, 30, 35, 41, 46, 51, 57, 62,
		70, 76, 81, 87, 92, 97, 102, 107, 113, 118, 124, 130];
	var alts = [2249.0, 2249.8, 2251.0, 2251.4, 2251.8, 2253.0, 2253.4, 2254.0,
		2255.0, 2255.4, 2255.4, 2255.4, 2256.4, 2257.6, 2258.8, 2260.4,
		2261.4, 2262.6, 2263.8, 2265.2, 2266.0, 2266.4, 2267.6, 2268.6];

	var h = new HikeHistory();
	var t0 = 3600000;
	for (var i = 0; i <= 17; i++)
	{
		h.add(t0 + secs[i] * 1000, alts[i], null);
	}
	var v180 = h.verticalSpeedMh(t0 + 97000, 180000);
	var v300 = h.verticalSpeedMh(t0 + 97000, 300000);
	logger.debug("Salvan at 11:08:48: 180 s -> " + v180 + ", 300 s -> " + v300);
	Test.assertMessage(v180 != null && v180 > 459.3 && v180 < 461.3, "Salvan 11:08:48, 180 s: 460.3 m/h, got " + v180);
	Test.assertMessage(v300 != null && v300 > 459.3 && v300 < 461.3, "Salvan 11:08:48, 300 s: 460.3 m/h, got " + v300);
	Test.assertEqualMessage($.formatVerticalSpeed(v300), "+460", "displayed +460");

	for (var i = 18; i < secs.size(); i++)
	{
		h.add(t0 + secs[i] * 1000, alts[i], null);
	}
	var now = t0 + 130000;
	var v60 = h.verticalSpeedMh(now, 60000);
	v180 = h.verticalSpeedMh(now, 180000);
	v300 = h.verticalSpeedMh(now, 300000);
	logger.debug("Salvan at 11:09:21: 60 s -> " + v60 + ", 180 s -> " + v180 + ", 300 s -> " + v300);
	Test.assertMessage(v60 != null && v60 > 745.7 && v60 < 747.7, "Salvan 11:09:21, 60 s: 746.7 m/h, got " + v60);
	Test.assertMessage(v180 != null && v180 > 542.4 && v180 < 544.4, "Salvan 11:09:21, 180 s: 543.4 m/h, got " + v180);
	Test.assertMessage(v300 != null && v300 > 542.4 && v300 < 544.4, "Salvan 11:09:21, 300 s: 543.4 m/h, got " + v300);
	Test.assertEqualMessage($.formatVerticalSpeed(v60), "+750", "60 s displayed +750");
	Test.assertEqualMessage($.formatVerticalSpeed(v300), "+540", "300 s displayed +540");
	return true;
}

// Window longer than the data held. Documented behaviour: the regression runs
// on whatever samples the window contains, so it gives a partial value as
// soon as there are 3 samples over 20 s, and null ("--") before that. A 5 min
// window therefore shows a value after 20 s, not after 5 min.
(:test)
function testHikeHistoryWindowLongerThanData(logger)
{
	var h = new HikeHistory();
	var t0 = 3600000;

	// 15 s of data (4 samples): "--" whatever the window.
	for (var s = 0; s <= 15; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0 + s / 6.0, null);
	}
	var wins = $.vsWindowChoicesMs();
	for (var i = 0; i < wins.size(); i++)
	{
		var v = h.verticalSpeedMh(t0 + 15000, wins[i]);
		Test.assertMessage(v == null, "15 s of data, window " + wins[i] + " -> null");
		Test.assertEqualMessage($.formatVerticalSpeed(v), "--", "15 s of data, window " + wins[i] + " -> --");
	}

	// 20 s of data: the minimum, value in every window.
	h.add(t0 + 20000, 1500.0 + 20 / 6.0, null);
	for (var i = 0; i < wins.size(); i++)
	{
		var v = h.verticalSpeedMh(t0 + 20000, wins[i]);
		Test.assertMessage(v != null && v > 599.0 && v < 601.0, "20 s of data, window " + wins[i] + " -> 600, got " + v);
	}

	// 90 s of steady 600 m/h: 180 and 300 s windows give the partial value
	// over the 90 s held, the same as a 90 s window.
	for (var s = 25; s <= 90; s += 5)
	{
		h.add(t0 + s * 1000, 1500.0 + s / 6.0, null);
	}
	var v90 = h.verticalSpeedMh(t0 + 90000, 90000);
	var v180 = h.verticalSpeedMh(t0 + 90000, 180000);
	var v300 = h.verticalSpeedMh(t0 + 90000, 300000);
	Test.assertMessage(v180 != null && v180 > 599.0 && v180 < 601.0, "90 s of data, 180 s window -> 600, got " + v180);
	Test.assertMessage(v300 != null && v300 > 599.0 && v300 < 601.0, "90 s of data, 300 s window -> 600, got " + v300);
	Test.assertEqualMessage(v180, v90, "180 s window over 90 s of data = the 90 s regression");
	Test.assertEqualMessage(v300, v90, "300 s window over 90 s of data = the 90 s regression");

	// Read long after the last sample (no new sample, e.g. altitude lost):
	// every window empties in turn.
	Test.assertMessage(h.verticalSpeedMh(t0 + 400000, 300000) == null, "nothing in the last 5 min -> null");
	return true;
}

// WatchData: default window, setter, and switching window during an outing
// without resetting the buffer. Same parabola as testHikeHistoryWindows60180300,
// fed at 1 Hz like onSensor().
(:test)
function testWatchDataHikeVsWindowSwitch(logger)
{
	var data = new WatchData();
	Test.assertEqualMessage(data.getHikeVsWindowMs(), 60000, "new WatchData -> 60 s window");

	data.setHikeVsWindowMs(180000);
	Test.assertEqualMessage(data.getHikeVsWindowMs(), 180000, "set 3 min");
	data.setHikeVsWindowMs(120000);
	Test.assertEqualMessage(data.getHikeVsWindowMs(), 60000, "invalid window -> 60 s");
	data.setHikeVsWindowMs(300000);
	data.setHikeVsWindowMs(null);
	Test.assertEqualMessage(data.getHikeVsWindowMs(), 60000, "null window -> 60 s");
	data.setHikeVsWindowMs("300000");
	Test.assertEqualMessage(data.getHikeVsWindowMs(), 60000, "corrupted window -> 60 s");

	var t0 = 3600000;
	for (var s = 0; s <= 300; s++)
	{
		data.activityData = { "altitude" => 1500.0 + s * s / 3600.0, "distance" => 1.0 * s };
		data.recordHikeSampleAt(t0 + s * 1000);
	}
	var now = t0 + 300000;
	Test.assertEqualMessage(data.hikeHistory.getCount(), 60, "precondition: full buffer");

	var v = data.getHikeVerticalSpeedAt(now);
	Test.assertMessage(v != null && v > 539.0 && v < 541.0, "default 60 s -> 540, got " + v);

	data.setHikeVsWindowMs(300000);
	Test.assertEqualMessage(data.hikeHistory.getCount(), 60, "switching window keeps the buffer");
	v = data.getHikeVerticalSpeedAt(now);
	Test.assertMessage(v != null && v > 304.0 && v < 306.0, "switched to 5 min -> 305 at once, got " + v);

	data.setHikeVsWindowMs(180000);
	v = data.getHikeVerticalSpeedAt(now);
	Test.assertMessage(v != null && v > 419.0 && v < 421.0, "switched to 3 min -> 420, got " + v);

	// Pace keeps its own 60 s window whatever the VS window (out of scope).
	var sp = data.getHikeSpeedAt(now);
	Test.assertMessage(sp != null && sp > 0.99 && sp < 1.01, "speed unchanged by the VS window, got " + sp);

	// Recording goes on after the switch: the new samples land in the same
	// buffer and the 3 min window follows them.
	for (var s = 301; s <= 360; s++)
	{
		data.activityData = { "altitude" => 1500.0 + s * s / 3600.0, "distance" => 1.0 * s };
		data.recordHikeSampleAt(t0 + s * 1000);
	}
	Test.assertEqualMessage(data.hikeHistory.getCount(), 60, "still a full buffer, no reset");
	v = data.getHikeVerticalSpeedAt(t0 + 360000);
	Test.assertMessage(v != null && v > 539.0 && v < 541.0, "3 min window 180..360 s -> centre 270 -> 540, got " + v);

	data.setHikeVsWindowMs(60000);
	v = data.getHikeVerticalSpeedAt(t0 + 360000);
	Test.assertMessage(v != null && v > 659.0 && v < 661.0, "back to 1 min, 300..360 s -> centre 330 -> 660, got " + v);

	// The flight vario is not involved.
	Test.assertMessage(data.oldAlt == null, "window switch must not touch oldAlt");
	Test.assertMessage(data.getVario() == null, "window switch must not touch the vario");
	return true;
}

// The choice made in the menu goes to both the store and the WatchData read
// by HikePaceView (applyVsWindowChoice), and an invalid one changes nothing
// unexpected. Both stores restored at the end (new Preferences(Application.getApp()) runs the
// migration on the old object store).
(:test)
function testApplyVsWindowChoice(logger)
{
	var snap = new StoredPrefsSnapshot();
	var legacy = new LegacyPrefsSnapshot(Application.getApp());
	try
	{
		var p = new Preferences(Application.getApp());
		var data = new WatchData();
		Test.assertEqualMessage($.applyVsWindowChoice(p, data, 300000), 300000, "5 min applied");
		Test.assertEqualMessage(p.getVsWindowMs(), 300000, "5 min stored");
		Test.assertEqualMessage(data.getHikeVsWindowMs(), 300000, "5 min in WatchData");

		Test.assertEqualMessage($.applyVsWindowChoice(p, data, 180000), 180000, "3 min applied");
		Test.assertEqualMessage(p.getVsWindowMs(), 180000, "3 min stored");
		Test.assertEqualMessage(data.getHikeVsWindowMs(), 180000, "3 min in WatchData");

		Test.assertEqualMessage($.applyVsWindowChoice(p, data, 7), 60000, "invalid -> default applied");
		Test.assertEqualMessage(p.getVsWindowMs(), 60000, "invalid -> default stored");
		Test.assertEqualMessage(data.getHikeVsWindowMs(), 60000, "invalid -> default in WatchData");

		// No WatchData yet (menu before the views exist): store only, no crash.
		Test.assertEqualMessage($.applyVsWindowChoice(p, null, 300000), 300000, "no WatchData -> still stored");
		Test.assertEqualMessage(p.getVsWindowMs(), 300000, "stored without WatchData");
		// No Preferences: WatchData only.
		Test.assertEqualMessage($.applyVsWindowChoice(null, data, 300000), 300000, "no Preferences -> WatchData only");
		Test.assertEqualMessage(data.getHikeVsWindowMs(), 300000, "WatchData set without Preferences");
		Test.assertEqualMessage(Application.Storage.getValue($.PREF_VS_WINDOW_KEY), 300000, "the choice lands in Storage");
	}
	finally
	{
		snap.restore();
		legacy.restore();
	}
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
// run by the test runner as a test. Feeds WatchData ticks for every source
// (speed, altitude, heart rate, position), hence the name.
(:test)
class WatchDataTestHelper
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
	WatchDataTestHelper.feedTick(data, new FakePositionInfo(1000.0, 1.5), null, new FakeSensorInfo(1000.0, null));
	WatchDataTestHelper.assertSpeed(data, 1.5, "null sensor speed must not hide the GPS speed");
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
	WatchDataTestHelper.feedTick(data, new FakePositionInfo(1000.0, null), new FakeActivityInfo(1000.0, null), new FakeSensorInfo(1000.0, null));
	Test.assertMessage(data.getSpeed() == null, "all speeds null -> getSpeed() null");
	return true;
}

// Sensor speed present -> null -> back: getSpeed() follows the GPS while the
// sensor speed is missing and never keeps a stale sensor value.
(:test)
function testWatchDataSpeedRecoversAfterNullSensorSpeed(logger)
{
	var data = new WatchData();

	WatchDataTestHelper.feedTick(data, new FakePositionInfo(1000.0, 1.2), new FakeActivityInfo(1000.0, 0.9), new FakeSensorInfo(1000.0, 2.0));
	WatchDataTestHelper.assertSpeed(data, 2.0, "tick 1: sensor speed wins (priority unchanged)");

	WatchDataTestHelper.feedTick(data, new FakePositionInfo(1000.0, 1.3), new FakeActivityInfo(1000.0, 0.9), new FakeSensorInfo(1000.0, null));
	WatchDataTestHelper.assertSpeed(data, 1.3, "tick 2: sensor speed null -> GPS speed, not stale 2.0");

	WatchDataTestHelper.feedTick(data, new FakePositionInfo(1000.0, null), new FakeActivityInfo(1000.0, 0.8), new FakeSensorInfo(1000.0, null));
	WatchDataTestHelper.assertSpeed(data, 0.8, "tick 3: sensor and GPS null -> activity speed");

	WatchDataTestHelper.feedTick(data, new FakePositionInfo(1000.0, 1.4), new FakeActivityInfo(1000.0, 0.9), new FakeSensorInfo(1000.0, 2.5));
	WatchDataTestHelper.assertSpeed(data, 2.5, "tick 4: sensor speed back -> used again");

	// Without startMeasure() in between: updateSensorInfo() rebuilds its
	// dictionary, so an earlier 2.5 must not survive a later null.
	data.updateSensorInfo(new FakeSensorInfo(1000.0, null));
	WatchDataTestHelper.assertSpeed(data, 1.4, "no reset between calls: still no stale sensor speed");
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
	WatchDataTestHelper.feedTick(data, null, HeartRateTestHelper.act(0), HeartRateTestHelper.sens(118));
	HeartRateTestHelper.assertHr(data, 0, "activity 0 bpm kept and still has priority");

	// A null activity heart rate must not hide the sensor heart rate.
	data = new WatchData();
	WatchDataTestHelper.feedTick(data, null, HeartRateTestHelper.act(null), HeartRateTestHelper.sens(118));
	HeartRateTestHelper.assertHr(data, 118, "null activity heart rate -> sensor heart rate");

	// Both null -> getHeartRate() null (the views show "--"), not a crash.
	data = new WatchData();
	WatchDataTestHelper.feedTick(data, null, HeartRateTestHelper.act(null), HeartRateTestHelper.sens(null));
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
	WatchDataTestHelper.feedTick(data, null, HeartRateTestHelper.act(120), HeartRateTestHelper.sens(120));
	HeartRateTestHelper.assertHr(data, 120, "A tick 1: 120");
	WatchDataTestHelper.feedTick(data, null, HeartRateTestHelper.act(null), HeartRateTestHelper.sens(null));
	HeartRateTestHelper.assertHr(data, null, "A tick 2: both null -> null, not stale 120");
	WatchDataTestHelper.feedTick(data, null, HeartRateTestHelper.act(125), HeartRateTestHelper.sens(125));
	HeartRateTestHelper.assertHr(data, 125, "A tick 3: 125 taken");

	// B: only the activity heart rate drops, the sensor value is shown.
	data = new WatchData();
	WatchDataTestHelper.feedTick(data, null, HeartRateTestHelper.act(120), HeartRateTestHelper.sens(120));
	HeartRateTestHelper.assertHr(data, 120, "B tick 1: 120");
	WatchDataTestHelper.feedTick(data, null, HeartRateTestHelper.act(null), HeartRateTestHelper.sens(119));
	HeartRateTestHelper.assertHr(data, 119, "B tick 2: activity null -> sensor 119");
	WatchDataTestHelper.feedTick(data, null, HeartRateTestHelper.act(125), HeartRateTestHelper.sens(124));
	HeartRateTestHelper.assertHr(data, 125, "B tick 3: activity 125 back, priority unchanged");

	// C: Activity.getActivityInfo() returned null, sensor only.
	data = new WatchData();
	WatchDataTestHelper.feedTick(data, null, null, HeartRateTestHelper.sens(120));
	HeartRateTestHelper.assertHr(data, 120, "C tick 1: sensor 120");
	WatchDataTestHelper.feedTick(data, null, null, HeartRateTestHelper.sens(null));
	HeartRateTestHelper.assertHr(data, null, "C tick 2: sensor null -> null, not stale 120");
	WatchDataTestHelper.feedTick(data, null, null, HeartRateTestHelper.sens(125));
	HeartRateTestHelper.assertHr(data, 125, "C tick 3: sensor 125 taken");

	// Without startMeasure() in between: each update*() rebuilds its
	// dictionary, so an earlier value never survives a later null.
	data = new WatchData();
	WatchDataTestHelper.feedTick(data, null, HeartRateTestHelper.act(125), HeartRateTestHelper.sens(123));
	data.updateActivityInfo(HeartRateTestHelper.act(null));
	HeartRateTestHelper.assertHr(data, 123, "no reset: activity null -> sensor 123");
	data.updateSensorInfo(HeartRateTestHelper.sens(null));
	HeartRateTestHelper.assertHr(data, null, "no reset: both null -> null");
	return true;
}

// ---------------------------------------------------------------------------
// Map 3a: invalid positions are filtered out of the breadcrumb trail, and the
// trail stays visible without a current fix. Without a fix, the forums report
// Position.Info.position at lat/lon = 180 deg; a single (180, 180) point in the
// trail stretches the map's bounding box from 46 to 180 deg and squeezes the
// whole climb into less than a pixel.
// ---------------------------------------------------------------------------

// Position.Location stand-in: updateInfo() only calls toDegrees().
(:test)
class FakeLocation
{
	var lat;
	var lon;

	function initialize(la, lo)
	{
		lat = la;
		lon = lo;
	}

	function toDegrees()
	{
		return [lat, lon];
	}
}

// Position.Info stand-in with only a position and an accuracy.
(:test)
class FakeFixInfo
{
	var position = null;
	var accuracy = null;

	function initialize(lat, lon, acc)
	{
		if (lat != null || lon != null)
		{
			position = new FakeLocation(lat, lon);
		}
		accuracy = acc;
	}
}

(:test)
class MapTestHelper
{
	// gpsData as updateInfo() would leave it.
	static function gps(lat, lon, acc)
	{
		return { "lat" => lat, "long" => lon, "accuracy" => acc };
	}

	// Real Salvan extract: the first 20 GPX track points of
	// garmin_data/activity_24346302742.gpx (10:18:43 UTC onward, lines 17-197),
	// truncated to 9 decimals. Spacing 1-7 m, about 50 m in total.
	static function salvanLats()
	{
		return [46.118051251, 46.118069272, 46.118082432, 46.118100202, 46.118111601,
			46.118133394, 46.118151750, 46.118159881, 46.118170442, 46.118207490,
			46.118211178, 46.118204640, 46.118211262, 46.118212771, 46.118214866,
			46.118202880, 46.118206568, 46.118214196, 46.118259961, 46.118300445];
	}

	static function salvanLons()
	{
		return [6.993609304, 6.993521461, 6.993425321, 6.993360445, 6.993357847,
			6.993356757, 6.993337898, 6.993329935, 6.993322559, 6.993310321,
			6.993313842, 6.993274782, 6.993259778, 6.993220216, 6.993210828,
			6.993153999, 6.993151400, 6.993111586, 6.993081328, 6.993074538];
	}

	static function nan()
	{
		return Toybox.Math.sqrt(-1.0);
	}

	static function inf()
	{
		var big = 3.0e38;
		return big * 10.0;
	}
}

(:test)
function testIsValidLatLon(logger)
{
	// Real point and spec values.
	Test.assertMessage($.isValidLatLon(46.118, 6.993), "Salvan 46.118 / 6.993 -> valid");
	Test.assertMessage($.isValidLatLon(46.0, 7.0), "46 / 7 -> valid");
	Test.assertMessage(!$.isValidLatLon(180.0, 180.0), "180 / 180 (no fix) -> invalid");
	Test.assertMessage(!$.isValidLatLon(0.0, 0.0), "0 / 0 -> invalid");

	// Bounds are excluded.
	Test.assertMessage(!$.isValidLatLon(90.0, 7.0), "lat 90 -> invalid");
	Test.assertMessage(!$.isValidLatLon(-90.0, 7.0), "lat -90 -> invalid");
	Test.assertMessage(!$.isValidLatLon(46.0, 180.0), "lon 180 -> invalid");
	Test.assertMessage(!$.isValidLatLon(46.0, -180.0), "lon -180 -> invalid");
	Test.assertMessage(!$.isValidLatLon(180.0, 7.0), "lat 180 -> invalid");
	Test.assertMessage(!$.isValidLatLon(46.0, 360.0), "lon 360 -> invalid");
	Test.assertMessage($.isValidLatLon(89.9999, 179.9999), "just inside the upper bounds -> valid");
	Test.assertMessage($.isValidLatLon(-89.9999, -179.9999), "just inside the lower bounds -> valid");

	// Only the exact (0, 0) pair is rejected, -0.0 included.
	Test.assertMessage(!$.isValidLatLon(-0.0, 0.0), "-0 / 0 -> invalid");
	Test.assertMessage(!$.isValidLatLon(0.0, -0.0), "0 / -0 -> invalid");
	Test.assertMessage(!$.isValidLatLon(0, 0), "Number 0 / 0 -> invalid");
	Test.assertMessage($.isValidLatLon(0.0, 7.0), "equator, lon 7 -> valid");
	Test.assertMessage($.isValidLatLon(46.0, 0.0), "Greenwich meridian, lat 46 -> valid");

	// Null, NaN, Infinity.
	Test.assertMessage(!$.isValidLatLon(null, 7.0), "null lat -> invalid");
	Test.assertMessage(!$.isValidLatLon(46.0, null), "null lon -> invalid");
	Test.assertMessage(!$.isValidLatLon(null, null), "null / null -> invalid");
	var nan = MapTestHelper.nan();
	var inf = MapTestHelper.inf();
	Test.assertMessage(!$.isValidLatLon(nan, 7.0), "NaN lat -> invalid");
	Test.assertMessage(!$.isValidLatLon(46.0, nan), "NaN lon -> invalid");
	Test.assertMessage(!$.isValidLatLon(inf, 7.0), "+Inf lat -> invalid");
	Test.assertMessage(!$.isValidLatLon(46.0, -inf), "-Inf lon -> invalid");

	// Other numeric types: Number and Double (Location.toDegrees() returns Doubles).
	Test.assertMessage($.isValidLatLon(46, 7), "Number 46 / 7 -> valid");
	Test.assertMessage($.isValidLatLon(46.118d, 6.993d), "Double 46.118 / 6.993 -> valid");
	Test.assertMessage(!$.isValidLatLon(180.0d, 180.0d), "Double 180 / 180 -> invalid");
	Test.assertMessage(!$.isValidLatLon(0.0d, 0.0d), "Double 0 / 0 -> invalid");
	return true;
}

(:test)
function testBreadcrumbTrailRejectsInvalidPositions(logger)
{
	var trail = new BreadcrumbTrail();

	// Spec case.
	trail.update(180.0, 180.0);
	Test.assertEqualMessage(trail.getCount(), 0, "(180, 180) ignored");
	trail.update(0.0, 0.0);
	Test.assertEqualMessage(trail.getCount(), 0, "(0, 0) ignored");
	trail.update(46.118, 6.993);
	Test.assertEqualMessage(trail.getCount(), 1, "first valid point accepted");
	Test.assertMessage((trail.getLats()[0] - 46.118).abs() < 0.00001, "stored lat is the valid one, got " + trail.getLats()[0]);
	Test.assertMessage((trail.getLons()[0] - 6.993).abs() < 0.00001, "stored lon is the valid one, got " + trail.getLons()[0]);

	// An ignored point must not become the decimation reference: ~3.3 m from
	// the last valid point is still decimated after a (180, 180).
	trail.update(180.0, 180.0);
	trail.update(46.11803, 6.993);
	Test.assertEqualMessage(trail.getCount(), 1, "invalid point does not move the 15 m reference");

	// Other invalid inputs, all ignored.
	trail.update(null, 6.993);
	trail.update(46.2, null);
	trail.update(MapTestHelper.nan(), 6.993);
	trail.update(46.2, MapTestHelper.nan());
	trail.update(90.0, 6.993);
	trail.update(46.2, -180.0);
	trail.update(-0.0, 0.0);
	Test.assertEqualMessage(trail.getCount(), 1, "null, NaN, bounds and (-0, 0) ignored");

	// ~22 m north of the last valid point: accepted as usual.
	trail.update(46.1182, 6.993);
	Test.assertEqualMessage(trail.getCount(), 2, "next valid point beyond 15 m accepted");
	return true;
}

(:test)
function testWatchDataUsableFixFromGpsData(logger)
{
	// The numeric values below rely on the Position.Quality enum.
	Test.assertEqualMessage(Position.QUALITY_NOT_AVAILABLE, 0, "QUALITY_NOT_AVAILABLE == 0");
	Test.assertEqualMessage(Position.QUALITY_LAST_KNOWN, 1, "QUALITY_LAST_KNOWN == 1");
	Test.assertEqualMessage(Position.QUALITY_POOR, 2, "QUALITY_POOR == 2");
	Test.assertEqualMessage(Position.QUALITY_USABLE, 3, "QUALITY_USABLE == 3");
	Test.assertEqualMessage(Position.QUALITY_GOOD, 4, "QUALITY_GOOD == 4");

	var data = new WatchData();
	Test.assertEqualMessage(data.MIN_MAP_QUALITY, Position.QUALITY_USABLE, "map threshold is QUALITY_USABLE (3D fix)");

	// No GPS data at all.
	Test.assertMessage(data.getAccuracy() == null, "no gpsData -> accuracy null");
	Test.assertMessage(!data.hasUsableFix(), "no gpsData -> no usable fix");

	// Spec case: accuracy 0..4 on a valid position, true only for 3 and 4.
	var expected = [false, false, false, true, true];
	for (var acc = 0; acc <= 4; acc++)
	{
		data.gpsData = MapTestHelper.gps(46.118, 6.993, acc);
		Test.assertEqualMessage(data.getAccuracy(), acc, "getAccuracy() returns gpsData accuracy " + acc);
		Test.assertEqualMessage(data.hasUsableFix(), expected[acc], "accuracy " + acc + " -> usable fix " + expected[acc]);
	}

	// Accuracy missing or null.
	data.gpsData = { "lat" => 46.118, "long" => 6.993 };
	Test.assertMessage(data.getAccuracy() == null, "no accuracy key -> null");
	Test.assertMessage(!data.hasUsableFix(), "no accuracy key -> no usable fix");
	data.gpsData = MapTestHelper.gps(46.118, 6.993, null);
	Test.assertMessage(data.getAccuracy() == null, "null accuracy -> null");
	Test.assertMessage(!data.hasUsableFix(), "null accuracy -> no usable fix");

	// Good accuracy but an unusable position.
	data.gpsData = MapTestHelper.gps(180.0, 180.0, 4);
	Test.assertMessage(!data.hasUsableFix(), "(180, 180) even with QUALITY_GOOD -> no usable fix");
	data.gpsData = MapTestHelper.gps(0.0, 0.0, 4);
	Test.assertMessage(!data.hasUsableFix(), "(0, 0) -> no usable fix");
	data.gpsData = MapTestHelper.gps(null, 6.993, 4);
	Test.assertMessage(!data.hasUsableFix(), "null lat -> no usable fix");
	data.gpsData = { "accuracy" => 4 };
	Test.assertMessage(!data.hasUsableFix(), "no position keys -> no usable fix");
	data.gpsData = MapTestHelper.gps(46.118, MapTestHelper.nan(), 4);
	Test.assertMessage(!data.hasUsableFix(), "NaN lon -> no usable fix");
	return true;
}

// Same rule through the real updateInfo(), with Position.Info stand-ins.
(:test)
function testWatchDataUsableFixThroughUpdateInfo(logger)
{
	var data = new WatchData();

	// What the forums describe before the first fix.
	data.updateInfo(new FakeFixInfo(180.0d, 180.0d, Position.QUALITY_NOT_AVAILABLE));
	Test.assertMessage(!data.hasUsableFix(), "no fix (180, 180, NOT_AVAILABLE) -> not usable");
	Test.assertMessage(data.getLat() != null, "the raw position is still stored (compass page shows it)");

	data.updateInfo(new FakeFixInfo(46.118d, 6.993d, Position.QUALITY_LAST_KNOWN));
	Test.assertMessage(!data.hasUsableFix(), "LAST_KNOWN -> not usable");
	data.updateInfo(new FakeFixInfo(46.118d, 6.993d, Position.QUALITY_POOR));
	Test.assertMessage(!data.hasUsableFix(), "POOR (2D) -> not usable");
	data.updateInfo(new FakeFixInfo(46.118d, 6.993d, Position.QUALITY_USABLE));
	Test.assertMessage(data.hasUsableFix(), "USABLE (3D) -> usable");
	data.updateInfo(new FakeFixInfo(46.118d, 6.993d, Position.QUALITY_GOOD));
	Test.assertMessage(data.hasUsableFix(), "GOOD -> usable");

	// Position null but accuracy good: no lat/lon key, not usable.
	data.updateInfo(new FakeFixInfo(null, null, Position.QUALITY_GOOD));
	Test.assertMessage(!data.gpsData.hasKey("lat"), "null position -> no lat key");
	Test.assertMessage(!data.hasUsableFix(), "null position -> not usable");

	// Accuracy null.
	data.updateInfo(new FakeFixInfo(46.118d, 6.993d, null));
	Test.assertMessage(!data.hasUsableFix(), "null accuracy -> not usable");
	return true;
}

// The trail as onSensor() feeds it (feedBreadcrumbTrail), on the real Salvan
// extract preceded by the no-fix ticks: the resulting trail must be exactly
// the one built from the real points alone, with no (180, 180) point in it.
(:test)
function testFeedBreadcrumbTrailSkipsTicksWithoutFix(logger)
{
	var lats = MapTestHelper.salvanLats();
	var lons = MapTestHelper.salvanLons();

	// Reference: real points only.
	var reference = new BreadcrumbTrail();
	for (var i = 0; i < lats.size(); i++)
	{
		reference.update(lats[i], lons[i]);
	}
	Test.assertMessage(reference.getCount() >= 2, "precondition: the 50 m extract gives several points, got " + reference.getCount());

	// App: no-fix ticks first, then the real points with a 3D fix, with a
	// short loss of fix (POOR) in the middle.
	var data = new WatchData();
	var trail = new BreadcrumbTrail();
	var noFix = [
		MapTestHelper.gps(180.0, 180.0, Position.QUALITY_NOT_AVAILABLE),
		MapTestHelper.gps(180.0, 180.0, Position.QUALITY_NOT_AVAILABLE),
		MapTestHelper.gps(0.0, 0.0, Position.QUALITY_NOT_AVAILABLE),
		MapTestHelper.gps(45.0, 6.0, Position.QUALITY_LAST_KNOWN),
		MapTestHelper.gps(46.2, 7.1, Position.QUALITY_POOR)
	];
	for (var i = 0; i < noFix.size(); i++)
	{
		data.gpsData = noFix[i];
		$.feedBreadcrumbTrail(trail, data);
	}
	Test.assertEqualMessage(trail.getCount(), 0, "no point stored before a 3D fix");

	for (var i = 0; i < lats.size(); i++)
	{
		data.gpsData = MapTestHelper.gps(lats[i], lons[i], Position.QUALITY_GOOD);
		$.feedBreadcrumbTrail(trail, data);
		if (i == 10)
		{
			data.gpsData = MapTestHelper.gps(180.0, 180.0, Position.QUALITY_POOR);
			$.feedBreadcrumbTrail(trail, data);
			data.gpsData = null;
			$.feedBreadcrumbTrail(trail, data);
		}
	}

	logger.debug("Salvan extract: " + lats.size() + " GPX points -> " + trail.getCount() + " trail points");
	Test.assertEqualMessage(trail.getCount(), reference.getCount(), "same point count as the real points alone");
	for (var i = 0; i < trail.getCount(); i++)
	{
		var lat = trail.getLats()[i];
		var lon = trail.getLons()[i];
		Test.assertMessage(lat == reference.getLats()[i] && lon == reference.getLons()[i], "point " + i + " identical to the reference");
		Test.assertMessage(lat > 46.118 && lat < 46.119 && lon > 6.993 && lon < 6.994, "point " + i + " inside the Salvan extract, got " + lat + " / " + lon);
	}
	Test.assertMessage((trail.getLats()[0] - lats[0]).abs() < 0.000001, "first trail point is the first GPX point");
	return true;
}

// What map() draws: "Waiting for GPS" only with no trail and no current
// position; the trail alone when the fix is lost; trail + marker otherwise.
(:test)
function testMapDrawMode(logger)
{
	Test.assertEqualMessage($.mapDrawMode(0, false), :waiting, "no trail, no fix -> waiting");
	Test.assertEqualMessage($.mapDrawMode(0, true), :trailAndMarker, "no trail, fix -> marker (trail of 0)");
	Test.assertEqualMessage($.mapDrawMode(1, false), :trailOnly, "1 point, no fix -> trail only");
	Test.assertEqualMessage($.mapDrawMode(120, false), :trailOnly, "trail, fix lost -> trail only, not waiting");
	Test.assertEqualMessage($.mapDrawMode(250, false), :trailOnly, "full buffer, no fix -> trail only");
	Test.assertEqualMessage($.mapDrawMode(120, true), :trailAndMarker, "trail and fix -> trail and marker");

	// Edge cases: unknown or incoherent inputs.
	Test.assertEqualMessage($.mapDrawMode(null, false), :waiting, "null count, no fix -> waiting");
	Test.assertEqualMessage($.mapDrawMode(null, true), :trailAndMarker, "null count, fix -> marker");
	Test.assertEqualMessage($.mapDrawMode(-1, false), :waiting, "negative count -> treated as 0");
	Test.assertEqualMessage($.mapDrawMode(5, null), :trailOnly, "null hasCurrent -> treated as no fix");
	Test.assertEqualMessage($.mapDrawMode(0, null), :waiting, "null hasCurrent, no trail -> waiting");
	return true;
}

// Checks a pickScaleBar() result: [meters, pixels], both whole Numbers.
(:test)
class ScaleBarTestHelper
{
	static function check(bar, meters, pixels, msg)
	{
		Test.assertMessage(bar != null, msg + ": expected a bar, got null");
		Test.assertEqualMessage(bar.size(), 2, msg + ": [meters, pixels]");
		Test.assertEqualMessage(bar[0], meters, msg + ": meters, got " + bar[0]);
		Test.assertEqualMessage(bar[1], pixels, msg + ": pixels, got " + bar[1]);
		Test.assertMessage(bar[1] instanceof Toybox.Lang.Number, msg + ": pixels is a Number");
	}

	// Test.assertEqual(x, null) cannot be used: it calls x.equals(), which
	// fails on null itself.
	static function checkNull(value, msg)
	{
		Test.assertMessage(value == null, msg + ", got " + value);
	}
}

// map()'s scale is in pixels per degree of latitude (longitudes are
// compressed by cos(lat) first), so 1 degree = 111 320 m on both axes.
(:test)
function testMetersPerPixelFromScale(logger)
{
	var mpp = $.metersPerPixelFromScale(1113.2);
	Test.assertMessage(mpp != null && (mpp - 100.0).abs() < 0.01, "1113.2 px/deg -> 100 m/px, got " + mpp);
	mpp = $.metersPerPixelFromScale(111320);
	Test.assertMessage(mpp != null && (mpp - 1.0).abs() < 0.0001, "111320 px/deg (Number) -> 1 m/px, got " + mpp);
	mpp = $.metersPerPixelFromScale(500000.0);
	Test.assertMessage(mpp != null && (mpp - 0.22264).abs() < 0.0001, "500000 px/deg -> 0.22264 m/px, got " + mpp);

	// Unusable scales: no conversion.
	var big = 3.0e38;
	ScaleBarTestHelper.checkNull($.metersPerPixelFromScale(null), "null -> null");
	ScaleBarTestHelper.checkNull($.metersPerPixelFromScale(0.0), "0 -> null (no divide by zero)");
	ScaleBarTestHelper.checkNull($.metersPerPixelFromScale(0), "0 (Number) -> null");
	ScaleBarTestHelper.checkNull($.metersPerPixelFromScale(-1000.0), "negative -> null");
	ScaleBarTestHelper.checkNull($.metersPerPixelFromScale(MapTestHelper.nan()), "NaN -> null");
	ScaleBarTestHelper.checkNull($.metersPerPixelFromScale(big * 10.0), "+Inf -> null");
	ScaleBarTestHelper.checkNull($.metersPerPixelFromScale(-big * 10.0), "-Inf -> null");
	return true;
}

// Largest round length (50/100/200/500 m, 1/2/5 km) that fits in maxPixels,
// shown only if it is at least a quarter of maxPixels long.
(:test)
function testPickScaleBar(logger)
{
	// The three reference scales.
	ScaleBarTestHelper.check($.pickScaleBar(2.0, 80), 100, 50, "2 m/px, 80 px (spec example)");
	ScaleBarTestHelper.check($.pickScaleBar(10.0, 86), 500, 50, "10 m/px, 86 px");
	ScaleBarTestHelper.check($.pickScaleBar(100.0, 80), 5000, 50, "100 m/px, 80 px");

	// Every round length is reachable; a length exactly equal to the room fits.
	ScaleBarTestHelper.check($.pickScaleBar(1.0, 80), 50, 50, "1 m/px -> 50 m");
	ScaleBarTestHelper.check($.pickScaleBar(0.625, 80), 50, 80, "50 m exactly 80 px -> fits");
	ScaleBarTestHelper.check($.pickScaleBar(4.0, 80), 200, 50, "4 m/px -> 200 m");
	ScaleBarTestHelper.check($.pickScaleBar(12.5, 80), 1000, 80, "1 km exactly 80 px -> fits");
	ScaleBarTestHelper.check($.pickScaleBar(25.0, 80), 2000, 80, "2 km exactly 80 px -> fits");
	ScaleBarTestHelper.check($.pickScaleBar(2.1, 80), 100, 48, "100 m / 2.1 = 47.6 px, rounded to 48");
	ScaleBarTestHelper.check($.pickScaleBar(60.0, 80), 2000, 33, "5 km too long -> 2 km, 33 px");
	ScaleBarTestHelper.check($.pickScaleBar(2, 80), 100, 50, "Number m/px");
	ScaleBarTestHelper.check($.pickScaleBar(2.0, 80.0), 100, 50, "Float maxPixels");
	ScaleBarTestHelper.check($.pickScaleBar(2.0d, 80), 100, 50, "Double m/px");

	// Too zoomed in: even 50 m does not fit -> no bar.
	ScaleBarTestHelper.checkNull($.pickScaleBar(0.5, 80), "0.5 m/px: 50 m = 100 px > 80 -> null");
	ScaleBarTestHelper.checkNull($.pickScaleBar(0.001, 80), "tiny m/px -> null");

	// Too zoomed out: 5 km is shorter than a quarter of the room -> no bar.
	ScaleBarTestHelper.check($.pickScaleBar(250.0, 80), 5000, 20, "5 km = 20 px = 80 / 4 -> still shown");
	ScaleBarTestHelper.checkNull($.pickScaleBar(300.0, 80), "5 km = 16.7 px < 20 -> null");
	ScaleBarTestHelper.checkNull($.pickScaleBar(100000.0, 80), "huge m/px -> null");

	// Unusable inputs.
	var big = 3.0e38;
	var nan = MapTestHelper.nan();
	ScaleBarTestHelper.checkNull($.pickScaleBar(null, 80), "null m/px -> null");
	ScaleBarTestHelper.checkNull($.pickScaleBar(0.0, 80), "0 m/px -> null");
	ScaleBarTestHelper.checkNull($.pickScaleBar(-2.0, 80), "negative m/px -> null");
	ScaleBarTestHelper.checkNull($.pickScaleBar(nan, 80), "NaN m/px -> null");
	ScaleBarTestHelper.checkNull($.pickScaleBar(big * 10.0, 80), "+Inf m/px -> null");
	ScaleBarTestHelper.checkNull($.pickScaleBar(-big * 10.0, 80), "-Inf m/px -> null");
	ScaleBarTestHelper.checkNull($.pickScaleBar(2.0, 0), "0 px -> null");
	ScaleBarTestHelper.checkNull($.pickScaleBar(2.0, -80), "negative px -> null");
	ScaleBarTestHelper.checkNull($.pickScaleBar(2.0, null), "null px -> null");
	ScaleBarTestHelper.checkNull($.pickScaleBar(2.0, nan), "NaN px -> null");
	ScaleBarTestHelper.checkNull($.pickScaleBar(2.0, big * 10.0), "+Inf px -> null");
	return true;
}

(:test)
function testFormatScaleBarLabel(logger)
{
	Test.assertEqualMessage($.formatScaleBarLabel(50), "50 m", "50");
	Test.assertEqualMessage($.formatScaleBarLabel(100), "100 m", "100");
	Test.assertEqualMessage($.formatScaleBarLabel(200), "200 m", "200");
	Test.assertEqualMessage($.formatScaleBarLabel(500), "500 m", "500");
	Test.assertEqualMessage($.formatScaleBarLabel(1000), "1 km", "1000");
	Test.assertEqualMessage($.formatScaleBarLabel(2000), "2 km", "2000");
	Test.assertEqualMessage($.formatScaleBarLabel(5000), "5 km", "5000");
	Test.assertEqualMessage($.formatScaleBarLabel(1500), "1.5 km", "1500, not a round km");
	Test.assertEqualMessage($.formatScaleBarLabel(100.0), "100 m", "Float 100");

	Test.assertEqualMessage($.formatScaleBarLabel(null), "", "null -> empty");
	Test.assertEqualMessage($.formatScaleBarLabel(0), "", "0 -> empty");
	Test.assertEqualMessage($.formatScaleBarLabel(-100), "", "negative -> empty");
	Test.assertEqualMessage($.formatScaleBarLabel(MapTestHelper.nan()), "", "NaN -> empty");
	var big = 3.0e38;
	Test.assertEqualMessage($.formatScaleBarLabel(big * 10.0), "", "+Inf -> empty");
	return true;
}

(:test)
class MapProjectionTestHelper
{
	// Fails unless actual is within tol of expected (and not null).
	static function near(actual, expected, tol, msg)
	{
		Test.assertMessage(actual != null && (actual - expected).abs() <= tol, msg + " (expected " + expected + " +- " + tol + ", got " + actual + ")");
	}
}

// Center of map()'s projection: middle of the bounding box of the trail
// (ring buffer read oldest to newest) plus the current position, and the
// cosine of its latitude.
(:test)
function testMapProjectionCenter(logger)
{
	// Trail alone (no fix): bounding box of the trail only.
	var c = $.mapProjectionCenter([46.0, 46.01], [7.0, 7.02], 2, 0, null, null);
	Test.assertMessage(c != null && c.size() == 3, "trail alone -> [centerLat, centerLon, cosLat]");
	MapProjectionTestHelper.near(c[0], 46.005, 0.00001, "trail alone: center lat");
	MapProjectionTestHelper.near(c[1], 7.01, 0.00001, "trail alone: center lon");
	MapProjectionTestHelper.near(c[2], Toybox.Math.cos(Toybox.Math.toRadians(46.005)), 0.000001, "trail alone: cos(center lat)");

	// The current position widens the box.
	c = $.mapProjectionCenter([46.0, 46.0], [7.0, 7.0], 2, 0, 46.02, 7.04);
	MapProjectionTestHelper.near(c[0], 46.01, 0.00001, "with fix: center lat includes the fix");
	MapProjectionTestHelper.near(c[1], 7.02, 0.00001, "with fix: center lon includes the fix");

	// Current position only (empty trail): centered on it.
	c = $.mapProjectionCenter([0.0, 0.0], [0.0, 0.0], 0, 0, 46.5, 7.5);
	MapProjectionTestHelper.near(c[0], 46.5, 0.00001, "fix only: center lat = fix");
	MapProjectionTestHelper.near(c[1], 7.5, 0.00001, "fix only: center lon = fix");
	MapProjectionTestHelper.near(c[2], 0.6883546, 0.00001, "fix only: cos(46.5 deg)");

	// Half a fix (lat without lon) counts as no fix.
	c = $.mapProjectionCenter([46.0, 46.01], [7.0, 7.0], 2, 0, 50.0, null);
	MapProjectionTestHelper.near(c[0], 46.005, 0.00001, "lat without lon -> ignored");

	// Wrapped ring buffer: capacity 4, 3 points, writeIndex 1 -> slots 2, 3, 0.
	// Slot 1 holds a stale far away point that must be ignored.
	c = $.mapProjectionCenter([46.01, 60.0, 46.0, 46.005], [7.0, 20.0, 7.0, 7.0], 3, 1, null, null);
	MapProjectionTestHelper.near(c[0], 46.005, 0.00001, "wrapped buffer: stale slot ignored (lat)");
	MapProjectionTestHelper.near(c[1], 7.0, 0.00001, "wrapped buffer: stale slot ignored (lon)");

	// Partly filled buffer: capacity 4, 2 points at slots 0 and 1.
	c = $.mapProjectionCenter([46.0, 46.01, 0.0, 0.0], [7.0, 7.0, 0.0, 0.0], 2, 2, null, null);
	MapProjectionTestHelper.near(c[0], 46.005, 0.00001, "partly filled buffer: empty slots ignored");

	// Nothing to project: null (assertEqualMessage() throws on a null actual).
	Test.assertMessage($.mapProjectionCenter([0.0], [0.0], 0, 0, null, null) == null, "no trail, no fix -> null");
	Test.assertMessage($.mapProjectionCenter([0.0], [0.0], null, 0, null, null) == null, "null count, no fix -> null");
	Test.assertMessage($.mapProjectionCenter([0.0], [0.0], -1, 0, null, null) == null, "negative count, no fix -> null");
	return true;
}

// Scale of map()'s projection, in pixels per degree of latitude: 85 % of the
// screen radius over the largest projected offset from the center (trail and
// current position, longitudes times cos(lat)), floored at 0.0001 degree.
(:test)
function testMapPixelsPerDegree(logger)
{
	// North-south 0.01 deg trail: offset 0.005 deg -> 85 / 0.005 = 17000.
	var lats = [46.0, 46.01];
	var lons = [7.0, 7.0];
	var c = $.mapProjectionCenter(lats, lons, 2, 0, null, null);
	MapProjectionTestHelper.near($.mapPixelsPerDegree(lats, lons, 2, 0, null, null, c, 100), 17000.0, 20.0, "N-S 0.01 deg, radius 100");

	// East-west at 60 deg: 0.02 deg of longitude * cos 60 = 0.01 -> 17000.
	lats = [60.0, 60.0];
	lons = [7.0, 7.02];
	c = $.mapProjectionCenter(lats, lons, 2, 0, null, null);
	MapProjectionTestHelper.near($.mapPixelsPerDegree(lats, lons, 2, 0, null, null, c, 100), 17000.0, 20.0, "E-W at 60 deg uses cos(lat)");

	// The current position sets the range when it is the farthest point.
	lats = [46.0, 46.0];
	lons = [7.0, 7.0];
	c = $.mapProjectionCenter(lats, lons, 2, 0, 46.01, 7.0);
	MapProjectionTestHelper.near($.mapPixelsPerDegree(lats, lons, 2, 0, 46.01, 7.0, c, 100), 17000.0, 20.0, "fix 0.01 deg away sets the range");

	// Stationary: one point, or a fix alone, uses the 0.0001 deg floor.
	c = $.mapProjectionCenter([46.0], [7.0], 1, 0, null, null);
	MapProjectionTestHelper.near($.mapPixelsPerDegree([46.0], [7.0], 1, 0, null, null, c, 100), 850000.0, 1000.0, "single point -> floor");
	c = $.mapProjectionCenter([0.0], [0.0], 0, 0, 46.0, 7.0);
	MapProjectionTestHelper.near($.mapPixelsPerDegree([0.0], [0.0], 0, 0, 46.0, 7.0, c, 100), 850000.0, 1000.0, "fix alone -> floor");

	// Wrapped ring buffer: the stale slot 1 (far away) must not shrink the scale.
	lats = [46.01, 60.0, 46.0, 46.005];
	lons = [7.0, 20.0, 7.0, 7.0];
	c = $.mapProjectionCenter(lats, lons, 3, 1, null, null);
	MapProjectionTestHelper.near($.mapPixelsPerDegree(lats, lons, 3, 1, null, null, c, 100), 17000.0, 20.0, "wrapped buffer: stale slot ignored");

	// Screen radius scales linearly (fenix6pro map radius 109 px).
	lats = [46.0, 46.01];
	lons = [7.0, 7.0];
	c = $.mapProjectionCenter(lats, lons, 2, 0, null, null);
	MapProjectionTestHelper.near($.mapPixelsPerDegree(lats, lons, 2, 0, null, null, c, 109), 18530.0, 25.0, "radius 109 -> 92.65 / 0.005");

	// No projection center (nothing to draw): null.
	Test.assertMessage($.mapPixelsPerDegree([0.0], [0.0], 0, 0, null, null, null, 100) == null, "null center -> null");
	return true;
}

// Real Salvan extract (about 50 m of trail) projected with map()'s own
// projection (mapProjectionCenter() / mapPixelsPerDegree()) on a fenix6pro
// (radius 109 px, trail fitted to 85 % of it, bar room 260 / 3 = 86 px):
// about 0.22 m/px, so even 50 m (about 224 px) does not fit and no bar is
// drawn; with 240 px of room it would be 50 m.
(:test)
function testScaleBarOnSalvanExtract(logger)
{
	var lats = MapTestHelper.salvanLats();
	var lons = MapTestHelper.salvanLons();
	var n = lats.size();
	// Full ring buffer, oldest point in slot 0 (writeIndex wrapped to 0), no fix.
	var center = $.mapProjectionCenter(lats, lons, n, 0, null, null);
	var pixelsPerDegree = $.mapPixelsPerDegree(lats, lons, n, 0, null, null, center, 109);

	var mpp = $.metersPerPixelFromScale(pixelsPerDegree);
	logger.debug("Salvan extract: " + pixelsPerDegree + " px/deg, " + mpp + " m/px");
	// Independent check: half the east-west extent (about 20.6 m) over 92.65 px.
	var minLon = lons[0], maxLon = lons[0];
	for (var i = 1; i < n; i++)
	{
		if (lons[i] < minLon) { minLon = lons[i]; }
		if (lons[i] > maxLon) { maxLon = lons[i]; }
	}
	var cosLat = Toybox.Math.cos(Toybox.Math.toRadians(46.118175848));
	var halfWidthMeters = (maxLon - minLon) * cosLat * 111320.0 / 2.0;
	Test.assertMessage(halfWidthMeters > 19.0 && halfWidthMeters < 22.0, "half width about 20.6 m, got " + halfWidthMeters);
	Test.assertMessage(mpp != null && (mpp - halfWidthMeters / 92.65).abs() < 0.005, "m/px = half width / fitted radius, got " + mpp);

	ScaleBarTestHelper.checkNull($.pickScaleBar(mpp, 86), "50 m extract on fenix6pro: no round length fits -> no bar");
	var bar = $.pickScaleBar(mpp, 240);
	Test.assertMessage(bar != null && bar[0] == 50 && bar[1] >= 215 && bar[1] <= 235, "240 px of room -> 50 m, about 224 px, got " + bar);
	return true;
}

// Diagnostic for the "180/180" cause, run inside the simulator: logs what
// Position.getInfo() returns right now (the test runner starts the app, so
// location events are enabled) and checks the invariant that a fix accepted
// for the map always has a valid position. Its log line is what to read
// before and after loading a GPX in the simulator.
(:test)
function testDiagSimulatorPositionInfo(logger)
{
	var info = Position.getInfo();
	if (info == null)
	{
		logger.debug("Position.getInfo() -> null");
		return true;
	}

	var lat = null;
	var lon = null;
	if (info.position != null)
	{
		var deg = info.position.toDegrees();
		lat = deg[0];
		lon = deg[1];
	}
	var data = new WatchData();
	data.updateInfo(info);
	logger.debug("Position.getInfo(): lat=" + lat + " lon=" + lon + " accuracy=" + info.accuracy
		+ " isValidLatLon=" + $.isValidLatLon(lat, lon) + " hasUsableFix=" + data.hasUsableFix());

	if (data.hasUsableFix())
	{
		Test.assertMessage($.isValidLatLon(data.getLat(), data.getLon()), "a usable fix always has a valid position");
	}
	return true;
}

// The app name shown in the launcher and the Store (manifest name="@Strings.AppName")
// is "Glidator2", the same as the Store listing.
// WatchUi.loadResource (API 1.0.0) rather than Application.loadResource (3.1.0):
// minSdkVersion is 3.0.0.
(:test)
function testAppNameIsGlidator2(logger)
{
	var name = WatchUi.loadResource(Rez.Strings.AppName);
	Test.assertMessage(name != null, "AppName resource must load");
	Test.assertEqualMessage(name, "Glidator2", "AppName must be Glidator2");
	return true;
}
