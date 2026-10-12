using Toybox.Test;
using Toybox.Lang;
using Toybox.System as Sys;

// ---------------------------------------------------------------------------
// Recording that does not start (decision D3 A of 12/10): Session.start()
// returns false when the watch could not start the FIT recording. Before, the
// app ignored it: start tone and vibration, then a session that exists but is
// not recording, i.e. the "paused" state (SELECT resumes, pages show a
// session). Now (RecordStart in FlyInstrumentApp.mc):
//   - no tone, no vibration (RecordStart.alertWanted());
//   - the session is discarded and dropped: no paused state, SELECT starts
//     again;
//   - a short "Recording failed" message replaces the start icon, on every
//     page, for RECORD_FLASH_DURATION_MS (WatchDisplay.recordingStartIcon()).
// Only an explicit false is a failure: a null result (a start() that returns
// nothing) keeps the old behaviour, recording assumed started.
//
// The session is a stand-in (StartSession below): the simulator's real
// session cannot be made to fail on demand.
//
// In a module: the 'globals' module of the device is limited to 253 members.
// Each test resets RecordStart.failed and the session itself, and collects its
// mismatches before asserting, so that a failure never leaks a "failed" state
// into the layout bench (whose "Recording" state shows the start icon).
// ---------------------------------------------------------------------------
(:test, :chaintest)
module RecordStartTests
{

// ActivityRecording.Session stand-in whose start() returns `result`
// (true, false or null) and records the calls.
(:test, :chaintest)
class StartSession
{
	var result;
	var recording = false;
	var startCalls = 0;
	var discardCalls = 0;
	var throwOnDiscard = false;

	function initialize(r) { result = r; }
	function isRecording() { return recording; }
	function start()
	{
		startCalls += 1;
		if (result != false)
		{
			recording = true;
		}
		return result;
	}
	function stop() { recording = false; return true; }
	function save() { return true; }
	function discard()
	{
		discardCalls += 1;
		if (throwOnDiscard)
		{
			throw new DiscardError();
		}
		return true;
	}
	function addLap() {}
}

(:test, :chaintest)
class DiscardError extends Lang.Exception
{
	function initialize() { Exception.initialize(); }
}

(:test, :chaintest, :typecheck(false))
class RS
{
	static function cleanup()
	{
		RecordStart.failed = false;
		$.ChainHelper.reset();
	}

	static function check(errs, label, ok)
	{
		if (ok != true)
		{
			errs.add(label);
		}
	}

	static function finish(errs, logger)
	{
		RecordStart.failed = false;
		return $.ChainHelper.finish(errs, logger);
	}

	static function sameBox(errs, label, actual, want)
	{
		if (want == null || actual == null)
		{
			if (want != actual)
			{
				errs.add(label + ": expected " + want + ", got " + actual);
			}
			return;
		}
		if (!(actual instanceof Lang.Array) || actual.size() != 4)
		{
			errs.add(label + ": expected " + want + ", got " + actual);
			return;
		}
		for (var i = 0; i < 4; i++)
		{
			if (actual[i] != want[i])
			{
				errs.add(label + ": expected " + want + ", got " + actual);
				return;
			}
		}
	}
}

// Start result -> outcome: only an explicit false is a failure.
(:test, :chaintest, :typecheck(false))
function testRecordStartOutcome(logger)
{
	var errs = [];
	$.ChainHelper.expectEq(errs, "start() true", RecordStart.outcome(true), :started);
	$.ChainHelper.expectEq(errs, "start() false", RecordStart.outcome(false), :failed);
	// Edge cases.
	$.ChainHelper.expectEq(errs, "start() null (returns nothing) -> old behaviour, started", RecordStart.outcome(null), :started);
	$.ChainHelper.expectEq(errs, "start() 0 (not a Boolean) -> started", RecordStart.outcome(0), :started);
	return RS.finish(errs, logger);
}

// Tone and vibration only for a recording that started.
(:test, :chaintest, :typecheck(false))
function testRecordStartAlertOnlyWhenStarted(logger)
{
	var errs = [];
	RS.check(errs, "started -> tone + vibration", RecordStart.alertWanted(:started) == true);
	RS.check(errs, "failed -> no tone, no vibration", RecordStart.alertWanted(:failed) == false);
	// Edge cases.
	RS.check(errs, "unknown outcome (null) -> no alert", RecordStart.alertWanted(null) == false);
	RS.check(errs, "unknown outcome (:other) -> no alert", RecordStart.alertWanted(:other) == false);
	return RS.finish(errs, logger);
}

// start() true: the session is kept and records; start icon, not the message.
(:test, :chaintest, :typecheck(false))
function testRecordStartBeginStarted(logger)
{
	RS.cleanup();
	var errs = [];
	var s = new StartSession(true);
	var outcome = RecordStart.begin(s, Sys.getTimer());
	$.ChainHelper.expectEq(errs, "outcome", outcome, :started);
	RS.check(errs, "session kept", $.session == s);
	RS.check(errs, "recording", $.isRecording());
	RS.check(errs, "not paused", !$.isPaused());
	$.ChainHelper.expectEq(errs, "SELECT -> pause menu", $.selectAction($.hasActiveSession(), $.isRecording()), :pauseMenu);
	$.ChainHelper.expectEq(errs, "start() called once", s.startCalls, 1);
	$.ChainHelper.expectEq(errs, "not discarded", s.discardCalls, 0);
	RS.check(errs, "flash shown", $.isRecordFlashActive());
	RS.check(errs, "flash is the start icon, not the failure message", RecordStart.failed == false);
	RS.check(errs, "alert wanted", RecordStart.alertWanted(outcome));
	RS.cleanup();
	return RS.finish(errs, logger);
}

// start() false: no session left (no paused state), SELECT starts again,
// no alert, the failure message is shown.
(:test, :chaintest, :typecheck(false))
function testRecordStartBeginFailedNoPausedState(logger)
{
	RS.cleanup();
	var errs = [];
	var s = new StartSession(false);
	var outcome = RecordStart.begin(s, Sys.getTimer());
	$.ChainHelper.expectEq(errs, "outcome", outcome, :failed);
	RS.check(errs, "no session left", $.session == null && !$.hasActiveSession());
	RS.check(errs, "not recording", !$.isRecording());
	RS.check(errs, "no paused state", !$.isPaused());
	$.ChainHelper.expectEq(errs, "SELECT -> start again", $.selectAction($.hasActiveSession(), $.isRecording()), :start);
	$.ChainHelper.expectEq(errs, "start() called once", s.startCalls, 1);
	$.ChainHelper.expectEq(errs, "failed session discarded once", s.discardCalls, 1);
	RS.check(errs, "no tone, no vibration", RecordStart.alertWanted(outcome) == false);
	RS.check(errs, "message shown", $.isRecordFlashActive() && RecordStart.failed == true);
	// The hike samples keep flowing (no session = hiking without recording).
	RS.check(errs, "hike samples still recorded", $.shouldRecordHikeSample($.hasActiveSession(), $.isRecording()));
	RS.check(errs, "nothing to save on stop", !$.shouldSaveOnStop($.hasActiveSession(), $.isRecording()));
	RS.cleanup();
	return RS.finish(errs, logger);
}

// Edge case: discard() of the failed session throws -> still no session,
// no exception out of begin().
(:test, :chaintest, :typecheck(false))
function testRecordStartBeginFailedDiscardThrows(logger)
{
	RS.cleanup();
	var errs = [];
	var s = new StartSession(false);
	s.throwOnDiscard = true;
	var outcome = null;
	try
	{
		outcome = RecordStart.begin(s, Sys.getTimer());
	}
	catch (e)
	{
		errs.add("begin() let the discard() exception out");
	}
	$.ChainHelper.expectEq(errs, "outcome", outcome, :failed);
	RS.check(errs, "no session left", $.session == null);
	$.ChainHelper.expectEq(errs, "discard() tried once", s.discardCalls, 1);
	RS.check(errs, "message shown", RecordStart.failed == true);
	RS.cleanup();
	return RS.finish(errs, logger);
}

// Edge case: no session object at all (createSession() gave null) -> failed,
// nothing called, no crash.
(:test, :chaintest, :typecheck(false))
function testRecordStartBeginNullSession(logger)
{
	RS.cleanup();
	var errs = [];
	var outcome = RecordStart.begin(null, Sys.getTimer());
	$.ChainHelper.expectEq(errs, "outcome", outcome, :failed);
	RS.check(errs, "no session", $.session == null && !$.isPaused());
	RS.check(errs, "no alert", RecordStart.alertWanted(outcome) == false);
	RS.check(errs, "message shown", $.isRecordFlashActive() && RecordStart.failed == true);
	RS.cleanup();
	return RS.finish(errs, logger);
}

// start() null (returns nothing): old behaviour, recording assumed started.
(:test, :chaintest, :typecheck(false))
function testRecordStartBeginNullResultKeepsSession(logger)
{
	RS.cleanup();
	var errs = [];
	var s = new StartSession(null);
	$.ChainHelper.expectEq(errs, "outcome", RecordStart.begin(s, Sys.getTimer()), :started);
	RS.check(errs, "session kept", $.session == s);
	$.ChainHelper.expectEq(errs, "not discarded", s.discardCalls, 0);
	RS.check(errs, "start icon", RecordStart.failed == false);
	RS.cleanup();
	return RS.finish(errs, logger);
}

// A failed start, then SELECT again with a start that works: recording, the
// start icon replaces the message at once.
(:test, :chaintest, :typecheck(false))
function testRecordStartFailedThenRetry(logger)
{
	RS.cleanup();
	var errs = [];
	var t0 = Sys.getTimer();
	RecordStart.begin(new StartSession(false), t0);
	RS.check(errs, "first try failed", RecordStart.failed == true && $.session == null);
	var ok = new StartSession(true);
	$.ChainHelper.expectEq(errs, "second try", RecordStart.begin(ok, t0 + 1000), :started);
	RS.check(errs, "session of the second try", $.session == ok && $.isRecording());
	RS.check(errs, "start icon, not the message", RecordStart.failed == false);
	$.ChainHelper.expectEq(errs, "flash restarted at the second try", $.recordFlashStartMs, t0 + 1000);
	RS.cleanup();
	return RS.finish(errs, logger);
}

// Box behind the message: text + padding (a quarter of the text height, at
// least 2 px), centred, clamped to the screen; null on unusable input.
(:test, :chaintest, :typecheck(false))
function testRecordStartMessageBox(logger)
{
	var errs = [];
	RS.sameBox(errs, "fenix6pro-like", RecordStart.messageBox(260, 260, 140, 26), [54, 111, 152, 38]);
	RS.sameBox(errs, "odd width (integer pixels)", RecordStart.messageBox(261, 260, 140, 26), [54, 111, 152, 38]);
	RS.sameBox(errs, "Float inputs", RecordStart.messageBox(260.0, 260.0, 140.0, 26.0), [54, 111, 152, 38]);
	// Edge cases.
	RS.sameBox(errs, "empty text -> 2 px padding", RecordStart.messageBox(260, 260, 0, 0), [128, 128, 4, 4]);
	RS.sameBox(errs, "text wider than the screen -> clamped to the width", RecordStart.messageBox(100, 100, 150, 20), [0, 35, 100, 30]);
	RS.sameBox(errs, "text taller than the screen -> clamped to the height", RecordStart.messageBox(100, 20, 50, 40), [15, 0, 70, 20]);
	RS.sameBox(errs, "null width", RecordStart.messageBox(null, 260, 140, 26), null);
	RS.sameBox(errs, "null text height", RecordStart.messageBox(260, 260, 140, null), null);
	RS.sameBox(errs, "zero screen", RecordStart.messageBox(0, 0, 140, 26), null);
	RS.sameBox(errs, "negative text width", RecordStart.messageBox(260, 260, -1, 26), null);
	return RS.finish(errs, logger);
}

// The message is drawn over the page (last text), on the hike pages and on
// the flight page (FlyInstrumentView unchanged: it already calls
// recordingStartIcon() while the flash is on); a successful start or an
// expired flash draws no text at all.
(:test, :chaintest, :typecheck(false))
function testRecordStartFailedMessageOnPages(logger)
{
	RS.cleanup();
	var errs = [];
	var data = new WatchData();
	$.ChainHelper.actTick(data, 2149.0, null, null, null);
	var app = new $.ChainApp(data, null);
	var msg = RecordStart.FAILED_TEXT;
	$.ChainHelper.expect(errs, "message text", msg, "Recording failed");

	var hikeBase = $.ChainHelper.join($.ChainHelper.render(new HikePositionView(app)));
	var paceBase = $.ChainHelper.join($.ChainHelper.render(new HikePaceView(app)));
	var flyBase = $.ChainHelper.fly(data);
	var flyWaitBase = $.ChainHelper.fly(new WatchData());

	// Failed start.
	RecordStart.begin(new StartSession(false), Sys.getTimer());
	$.ChainHelper.expect(errs, "Position page, failed", $.ChainHelper.join($.ChainHelper.render(new HikePositionView(app))), hikeBase + "|" + msg);
	$.ChainHelper.expect(errs, "Pace page, failed", $.ChainHelper.join($.ChainHelper.render(new HikePaceView(app))), paceBase + "|" + msg);
	$.ChainHelper.expect(errs, "flight page, failed", $.ChainHelper.fly(data), flyBase + "|" + msg);
	$.ChainHelper.expect(errs, "flight page without altitude, failed", $.ChainHelper.fly(new WatchData()), flyWaitBase + "|" + msg);

	// Message gone once the flash is over.
	$.recordFlashStartMs = Sys.getTimer() - $.RECORD_FLASH_DURATION_MS - 1;
	$.ChainHelper.expect(errs, "Position page, flash over", $.ChainHelper.join($.ChainHelper.render(new HikePositionView(app))), hikeBase);
	$.ChainHelper.expect(errs, "flight page, flash over", $.ChainHelper.fly(data), flyBase);

	// Successful start: the start icon draws no text (pages as before).
	RecordStart.begin(new StartSession(true), Sys.getTimer());
	$.session = null; // the pages compared without a session
	$.ChainHelper.expect(errs, "Position page, started", $.ChainHelper.join($.ChainHelper.render(new HikePositionView(app))), hikeBase);
	$.ChainHelper.expect(errs, "flight page, started", $.ChainHelper.fly(data), flyBase);

	RS.cleanup();
	return RS.finish(errs, logger);
}

} // module RecordStartTests
