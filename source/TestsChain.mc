using Toybox.Test;
using Toybox.Graphics;
using Toybox.Position;
using Toybox.Sensor;

// ---------------------------------------------------------------------------
// Functional chain tests (plan docs/tests/plan-test-approfondi.md, section 3.1):
// fake Info objects -> WatchData -> HikeHistory / BreadcrumbTrail -> the text
// each view draws, read back from a fake Dc (ChainDc) without any real drawing.
//
// Annotated :chaintest as well as :test so that a temporary jungle can leave
// them out (base.excludeAnnotations = chaintest) on a device short of memory.
//
// Naming:
//   testChain*       expected to pass (current behaviour is the right one);
//   testDefect*      check the RIGHT value for a defect found by this plan
//                    (D2 hike page, D3, D5, D6, D7, D8, D9), red until fixed;
//                    all fixed since (formatters in Utils.mc, unit tested
//                    in TestsFormat.mc); the "Today" notes give the old output;
//   testKnownDefect* pin a defect the user chose NOT to fix (D1, D4, decision
//                    of 2026-10-06): they pass today and fail if that
//                    behaviour changes (D1: the source of the flight vario).
// Display bounds decided on 2026-10-06: altitude -100..6000 m, heart rate
// 25..250 bpm, anything else (or non finite) reads "--".
// ---------------------------------------------------------------------------

// Fake Dc: records every drawText() string (and font), measures text with a
// fixed 10 px per character x 20 px, and ignores every other drawing call.
(:test, :chaintest, :typecheck(false))
class ChainDc
{
	var w;
	var h;
	var texts = [];
	var fonts = [];
	var bg = null;
	var clearedWith = null;

	function initialize(width, height)
	{
		w = width;
		h = height;
	}

	function getWidth() { return w; }
	function getHeight() { return h; }
	function getTextDimensions(t, f) { return [10 * t.length(), 20]; }
	function getTextWidthInPixels(t, f) { return 10 * t.length(); }
	function getFontHeight(f) { return 20; }
	function drawText(x, y, f, t, j) { texts.add(t); fonts.add(f); }
	function setColor(fg, b) { bg = b; }
	function clear() { clearedWith = bg; }
	function drawLine(x0, y0, x1, y1) {}
	function drawCircle(x, y, r) {}
	function fillCircle(x, y, r) {}
	function fillPolygon(p) {}
	function drawRectangle(x, y, a, b) {}
	function fillRectangle(x, y, a, b) {}
	function setPenWidth(p) {}
	function setClip(x, y, a, b) {}
	function clearClip() {}
}

// Activity.Info stand-in with every field the app reads. A field left null
// still exists, as on a real device: this is what reproduces D1.
(:test, :chaintest)
class FakeFullActivityInfo
{
	var altitude = null;
	var currentSpeed = null;
	var currentHeartRate = null;
	var currentHeading = null;
	var totalAscent = null;
	var elapsedDistance = null;
	var timerTime = null;

	function initialize() {}
}

// Activity.Info without any altitude field (the `has :altitude` check fails).
(:test, :chaintest)
class FakeActivityNoAltitude
{
	var currentHeartRate = null;

	function initialize() {}
}

// Position.Info stand-in.
(:test, :chaintest)
class FakeGpsInfo
{
	var position = null;
	var accuracy = null;
	var altitude = null;
	var speed = null;
	var heading = null;

	function initialize() {}
}

// ActivityRecording.Session stand-in: isRecording() only, no FIT file.
(:test, :chaintest)
class FakeSession
{
	var recording;

	function initialize(r) { recording = r; }
	function isRecording() { return recording; }
	function start() { recording = true; }
	function stop() { recording = false; }
	function save() {}
	function discard() {}
	function addLap() {}
}

// What the hike views read from the app: mainView.data and breadcrumbTrail.
(:test, :chaintest)
class ChainMainView
{
	var data;

	function initialize(d) { data = d; }
}

(:test, :chaintest)
class ChainApp
{
	var mainView;
	var breadcrumbTrail;

	function initialize(d, trail)
	{
		mainView = new ChainMainView(d);
		breadcrumbTrail = trail;
	}
}

// Helpers live in a class: a (:test) global function would be run as a test.
(:test, :chaintest, :typecheck(false))
class ChainHelper
{
	// Globals the views read; each test starts and ends without a session.
	static function reset()
	{
		$.session = null;
		$.recordFlashStartMs = null;
		$.sensorsOffForPause = false;
		if ($.preferences == null)
		{
			$.preferences = new Preferences();
		}
	}

	static function newDc()
	{
		var s = Toybox.System.getDeviceSettings();
		return new ChainDc(s.screenWidth, s.screenHeight);
	}

	static function join(texts)
	{
		var s = "";
		for (var i = 0; i < texts.size(); i++)
		{
			if (i > 0) { s += "|"; }
			s += texts[i];
		}
		return s;
	}

	// The 4 values of a hikeGrid() page as "top|left|right|bottom".
	static function pick(texts, idx)
	{
		if (texts.size() <= idx[idx.size() - 1])
		{
			return "unexpected texts: " + join(texts);
		}
		var out = [];
		for (var i = 0; i < idx.size(); i++)
		{
			out.add(texts[idx[i]]);
		}
		return join(out);
	}

	static function render(view)
	{
		var dc = newDc();
		view.onLayout(dc);
		view.onUpdate(dc);
		return dc.texts;
	}

	// HikePositionView draws [topLabel, top, leftLabel, rightLabel, left,
	// right, bottomLabel, bottom]: ALTITUDE | ELEV. GAIN | DISTANCE | TIMER.
	static function position(data)
	{
		return pick(render(new HikePositionView(new ChainApp(data, null))), [1, 4, 5, 7]);
	}

	// HikePaceView draws [top, leftLabel, rightLabel, left, right,
	// bottomLabel, bottom] (heart icon, no top label): HR | VERT. SPD. | PACE | TIMER.
	static function pace(data)
	{
		return pick(render(new HikePaceView(new ChainApp(data, null))), [0, 3, 4, 6]);
	}

	static function map(data, trail)
	{
		return join(render(new HikeMapView(new ChainApp(data, trail))));
	}

	// Flight page: every text, e.g. "2149| m|35| km/h|+0.4| m/s".
	static function fly(data)
	{
		var view = new FlyInstrumentView();
		view.data = data;
		return join(render(view));
	}

	static function paused(app)
	{
		var dc = newDc();
		new PausedView(app).onUpdate(dc);
		return join(dc.texts);
	}

	static function compass(heading, lat, lon)
	{
		var dc = newDc();
		new WatchDisplay(dc).compass(heading, lat, lon);
		return join(dc.texts);
	}

	static function act(alt, dist, hr, speed, timer)
	{
		var info = new FakeFullActivityInfo();
		info.altitude = alt;
		info.elapsedDistance = dist;
		info.currentHeartRate = hr;
		info.currentSpeed = speed;
		info.timerTime = timer;
		return info;
	}

	static function gps(lat, lon, acc, alt, speed)
	{
		var info = new FakeGpsInfo();
		if (lat != null)
		{
			info.position = new FakeLocation(lat, lon);
		}
		info.accuracy = acc;
		info.altitude = alt;
		info.speed = speed;
		return info;
	}

	static function sensor(alt, speed, hr)
	{
		var info = new FakeSensorInfo(alt, speed);
		info.heartRate = hr;
		return info;
	}

	// One tick with only an Activity.Info (altitude, distance, HR, timer).
	static function actTick(data, alt, dist, hr, timer)
	{
		SpeedTestHelper.feedTick(data, null, act(alt, dist, hr, null, timer), null);
	}

	// Collects mismatches so that one run lists every wrong value.
	static function expect(errs, label, actual, expected)
	{
		if (actual == null || !actual.equals(expected))
		{
			errs.add(label + ": expected \"" + expected + "\", got \"" + actual + "\"");
		}
	}

	static function near(errs, label, actual, expected, tol)
	{
		if (actual == null || actual != actual || (actual - expected).abs() > tol)
		{
			errs.add(label + ": expected " + expected + " +/- " + tol + ", got " + actual);
		}
	}

	// Logs every mismatch and returns the test result: false makes the runner
	// report FAIL (a failed assertion is reported as ERROR, without its text).
	static function finish(errs, logger)
	{
		reset();
		for (var i = 0; i < errs.size(); i++)
		{
			logger.error(errs[i]);
		}
		return errs.size() == 0;
	}

	// Real extract M (steep climb, lap 1): HikeHistory samples 10:50:30 ->
	// 10:51:28 UTC of garmin_data/activity_24346302742.tcx (10:51:28 is line
	// 11859). [seconds before 10:51:28, AltitudeMeters, DistanceMeters].
	static function extractM()
	{
		return [
			[-58, -52, -47, -41, -35, -29, -23, -18, -13, -8, 0],
			[2134.2, 2136.0, 2137.0, 2138.6, 2140.4, 2142.2, 2143.6, 2144.8, 2146.0, 2147.4, 2149.4],
			[1656.43, 1660.53, 1663.43, 1667.27, 1671.53, 1673.65, 1677.24, 1679.69, 1683.31, 1686.73, 1692.49]
		];
	}

	// Real extract S (spiral, lap 2): samples 13:00:50 -> 13:01:47 UTC
	// (13:01:47 is line 64937).
	static function extractS()
	{
		return [
			[-57, -52, -47, -41, -36, -31, -26, -21, -16, -10, -5, 0],
			[1951.4, 1942.4, 1917.0, 1879.2, 1872.8, 1865.2, 1852.0, 1827.8, 1779.2, 1760.0, 1744.4, 1732.2],
			[21538.03, 21589.81, 21626.31, 21687.91, 21737.70, 21778.32, 21826.32, 21861.61, 21900.24, 21946.63, 21998.51, 22048.72]
		];
	}

	// Feeds an extract into data.hikeHistory, the last sample at endMs.
	static function feedExtract(data, ex, endMs)
	{
		for (var i = 0; i < ex[0].size(); i++)
		{
			data.activityData = { "altitude" => ex[1][i], "distance" => ex[2][i] };
			data.recordHikeSampleAt(endMs + ex[0][i] * 1000);
		}
	}

	// End time for samples read back by a view (System.getTimer() inside):
	// 500 ms ahead, so that a sample 59.5 s old is still in the 60 s window
	// when onUpdate() reads the clock a few ms later. The regression and the
	// speed do not depend on a shift of all the times.
	static function viewEndMs()
	{
		return Toybox.System.getTimer() + 500;
	}

	// Same, for a test that does a lot of work (61 ticks) between this call
	// and the render: 30 s ahead. A sample in the future is still in the
	// window (nowMs - t <= windowMs), so only a render more than 30 s later
	// could drop the oldest sample; the results do not depend on the shift.
	static function slowViewEndMs()
	{
		return Toybox.System.getTimer() + 30000;
	}

	// Number / Boolean check that records the mismatch instead of throwing,
	// so that finish() (and its reset()) always runs.
	static function expectEq(errs, label, actual, expected)
	{
		if (actual != expected)
		{
			errs.add(label + ": expected " + expected + ", got " + actual);
		}
	}
}

// ---------------------------------------------------------------------------
// Altitude (F01-F05, D1, D2)
// ---------------------------------------------------------------------------

// F01: priority Activity -> Sensor -> GPS, down to the ALTITUDE field.
(:test, :chaintest, :typecheck(false))
function testChainAltitudeSourcePriority(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();

	SpeedTestHelper.feedTick(data, ChainHelper.gps(null, null, 0, 2155.0, null),
		ChainHelper.act(2149.4, null, null, null, null), ChainHelper.sensor(2150.0, null, null));
	ChainHelper.near(errs, "all 3 sources -> Activity", data.getAltitude(), 2149.4, 0.001);
	ChainHelper.expect(errs, "all 3 sources, page", ChainHelper.position(data), "2149|--|--|--:--");

	SpeedTestHelper.feedTick(data, ChainHelper.gps(null, null, 0, 2155.0, null),
		new FakeActivityNoAltitude(), ChainHelper.sensor(2150.0, null, null));
	ChainHelper.near(errs, "no Activity altitude field -> Sensor", data.getAltitude(), 2150.0, 0.001);
	ChainHelper.expect(errs, "Sensor, page", ChainHelper.position(data), "2150|--|--|--:--");

	SpeedTestHelper.feedTick(data, ChainHelper.gps(null, null, 0, 2155.0, null), null, null);
	ChainHelper.near(errs, "GPS only", data.getAltitude(), 2155.0, 0.001);
	ChainHelper.expect(errs, "GPS only, page", ChainHelper.position(data), "2155|--|--|--:--");
	return ChainHelper.finish(errs, logger);
}

// Known defect D1, NOT fixed (user decision 2026-10-06): an Activity.Info
// whose altitude field exists but is null stores "altitude" => null, and
// getAltitude() returns that null, hiding the sensor altitude. This pins the
// current behaviour: fixing it would change the source of the flight vario
// (sensitive zone). If this test fails, getAltitude() has changed.
(:test, :chaintest, :typecheck(false))
function testKnownDefectD1NullActivityAltitudeHidesSensor(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	SpeedTestHelper.feedTick(data, null, ChainHelper.act(null, null, null, null, null), ChainHelper.sensor(1500.0, null, null));
	data.endMeasure();

	Test.assertMessage(data.activityData.hasKey("altitude") && data.activityData["altitude"] == null, "setup: null Activity altitude stored as a key");
	Test.assertMessage(data.sensorData["altitude"] == 1500.0, "setup: the sensor altitude is there");
	Test.assertMessage(data.getAltitude() == null, "D1 pinned: getAltitude() stays null (sensor 1500 hidden), got " + data.getAltitude());
	ChainHelper.expect(errs, "D1 pinned: ALTITUDE", ChainHelper.position(data), "--|--|--|--:--");
	ChainHelper.expect(errs, "D1 pinned: flight page", ChainHelper.fly(data), "starting ...");
	data.recordHikeSampleAt(100000);
	Test.assertMessage(data.hikeHistory.getCount() == 0, "D1 pinned: no hike sample");
	Test.assertMessage(data.oldAlt == null && data.getVario() == null, "D1 pinned: vario untouched");
	return ChainHelper.finish(errs, logger);
}

// F03: no altitude anywhere: "--" on the hike page, "starting ..." in flight,
// and the vario stays null.
(:test, :chaintest, :typecheck(false))
function testChainAltitudeAbsent(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();

	SpeedTestHelper.feedTick(data, ChainHelper.gps(null, null, 0, null, null), new FakeActivityNoAltitude(), ChainHelper.sensor(null, null, null));
	data.endMeasure();
	Test.assertMessage(data.getAltitude() == null, "no altitude -> null");
	ChainHelper.expect(errs, "hike page", ChainHelper.position(data), "--|--|--|--:--");
	ChainHelper.expect(errs, "flight page", ChainHelper.fly(data), "starting ...");

	// All three getInfo() returned null.
	SpeedTestHelper.feedTick(data, null, null, null);
	data.endMeasure();
	Test.assertMessage(data.getAltitude() == null, "no Info at all -> null");
	ChainHelper.expect(errs, "no Info, hike page", ChainHelper.position(data), "--|--|--|--:--");
	ChainHelper.expect(errs, "no Info, flight page", ChainHelper.fly(data), "starting ...");
	Test.assertMessage(data.getVario() == null && data.oldAlt == null, "vario stays null");
	return ChainHelper.finish(errs, logger);
}

// F04: valid bounds of the hike page (-100 and 6000 m shown), and the flight
// page, left as is (FlyInstrumentView is not touched), shows any altitude.
(:test, :chaintest, :typecheck(false))
function testChainAltitudeNegativeAndHigh(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	var cases = [[-100.0, "-100"], [6000.0, "6000"], [0.0, "0"], [-99.6, "-100"], [5999.4, "5999"]];
	for (var i = 0; i < cases.size(); i++)
	{
		ChainHelper.actTick(data, cases[i][0], null, null, null);
		ChainHelper.expect(errs, "hike page " + cases[i][0], ChainHelper.position(data), cases[i][1] + "|--|--|--:--");
	}

	ChainHelper.actTick(data, -432.4, null, null, null);
	ChainHelper.expect(errs, "flight -432.4", ChainHelper.fly(data), "-432| m");
	ChainHelper.actTick(data, 8848.6, null, null, null);
	ChainHelper.expect(errs, "flight 8848.6", ChainHelper.fly(data), "8849| m");
	return ChainHelper.finish(errs, logger);
}

// D2 (hike page part, to fix): altitude outside -100..6000 m -> "--".
// Today: "-100", "6000", "-432", "8849" and an overflowed Number for 1e10.
(:test, :chaintest, :typecheck(false))
function testDefectAltitudeOutOfBounds(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	var alts = [-100.1, 6000.1, -432.4, 8848.6, -1000.0, 1.0e10, -1.0e10];
	for (var i = 0; i < alts.size(); i++)
	{
		ChainHelper.actTick(data, alts[i], null, null, null);
		ChainHelper.expect(errs, "altitude " + alts[i], ChainHelper.position(data), "--|--|--|--:--");
	}
	return ChainHelper.finish(errs, logger);
}

// D2 (hike page part, to fix): NaN and +/-Infinity -> "--". Today
// Math.round(x).toNumber() gives a meaningless number (or an error).
(:test, :chaintest, :typecheck(false))
function testDefectAltitudeNonFinite(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	var alts = [MapTestHelper.inf(), -MapTestHelper.inf(), MapTestHelper.nan()];
	var names = ["+Inf", "-Inf", "NaN"];
	for (var i = 0; i < alts.size(); i++)
	{
		ChainHelper.actTick(data, alts[i], null, null, null);
		ChainHelper.expect(errs, "altitude " + names[i], ChainHelper.position(data), "--|--|--|--:--");
	}
	return ChainHelper.finish(errs, logger);
}

// ---------------------------------------------------------------------------
// Hike vertical speed and pace (F06-F11), real extracts
// ---------------------------------------------------------------------------

// F06: real steep climb (extract M): least squares 944.6 m/h (hand computed:
// sxy 935.91, sxx 3566.73), shown "+940"; pace 36.06 m / 58 s -> 26:48.
(:test, :chaintest, :typecheck(false))
function testChainVerticalSpeedSalvanSteepClimb(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	var end = ChainHelper.viewEndMs();
	ChainHelper.feedExtract(data, ChainHelper.extractM(), end);

	Test.assertEqualMessage(data.hikeHistory.getCount(), 11, "11 real samples kept");
	var v = data.getHikeVerticalSpeedAt(end);
	logger.debug("extract M: " + v + " m/h");
	ChainHelper.near(errs, "vertical speed", v, 944.6, 0.5);
	ChainHelper.expect(errs, "formatVerticalSpeed", $.formatVerticalSpeed(v), "+940");
	ChainHelper.expect(errs, "pace page", ChainHelper.pace(data), "--|+940|26:48|--:--");
	return ChainHelper.finish(errs, logger);
}

// F07: real spiral (extract S): -14 419.8 m/h -> "-14420"; 510.69 m / 57 s
// = 8.9595 m/s -> 1:52 /km; position page with a session: 1732 m, 22.0 km.
(:test, :chaintest, :typecheck(false))
function testChainVerticalSpeedSalvanSpiralDescent(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	var end = ChainHelper.viewEndMs();
	ChainHelper.feedExtract(data, ChainHelper.extractS(), end);

	var v = data.getHikeVerticalSpeedAt(end);
	logger.debug("extract S: " + v + " m/h");
	ChainHelper.near(errs, "vertical speed", v, -14419.8, 2.0);
	ChainHelper.near(errs, "speed", data.getHikeSpeedAt(end), 8.9595, 0.001);
	$.session = new FakeSession(true);
	ChainHelper.expect(errs, "pace page", ChainHelper.pace(data), "--|-14420|1:52|--:--");
	ChainHelper.expect(errs, "position page", ChainHelper.position(data), "1732|--|22.0|--:--");
	return ChainHelper.finish(errs, logger);
}

// F08: a +1000 m jump on the last of 13 samples (5 s apart) is not filtered:
// sxy 30 000, sxx 4550 -> 23 736.3 m/h, "+23740" (current behaviour pinned).
(:test, :chaintest, :typecheck(false))
function testChainVerticalSpeedAltitudeJump(logger)
{
	var data = new WatchData();
	var t0 = 3600000;
	for (var s = 0; s <= 60; s += 5)
	{
		data.activityData = { "altitude" => (s == 60) ? 3000.0 : 2000.0 };
		data.recordHikeSampleAt(t0 + s * 1000);
	}
	var v = data.getHikeVerticalSpeedAt(t0 + 60000);
	Test.assertMessage(v != null && (v - 23736.3).abs() < 1.0, "jump -> 23 736.3 m/h, got " + v);
	Test.assertEqualMessage($.formatVerticalSpeed(v), "+23740", "jump displayed +23740");
	return true;
}

// F09: a NaN altitude sample gives "--" while it is in the window, then the
// value comes back once it has left it (600 m/h climb, NaN at s = 30).
(:test, :chaintest, :typecheck(false))
function testChainVerticalSpeedNaNAltitudeRecovers(logger)
{
	var errs = [];
	var data = new WatchData();
	var t0 = 3600000;
	for (var s = 0; s <= 125; s += 5)
	{
		data.activityData = { "altitude" => (s == 30) ? MapTestHelper.nan() : 2000.0 + s / 6.0 };
		data.recordHikeSampleAt(t0 + s * 1000);
		var shown = $.formatVerticalSpeed(data.getHikeVerticalSpeedAt(t0 + s * 1000));
		if (s >= 20)
		{
			ChainHelper.expect(errs, "s=" + s, shown, (s >= 30 && s <= 90) ? "--" : "+600");
		}
	}
	return ChainHelper.finish(errs, logger);
}

// F10: real 1 Hz replay (extract T, 10:50:28 -> 10:51:28, every TCX point
// of 10:50:26 -> 10:51:28 held until the next one) through the whole tick:
// feedTick, endMeasure, recordHikeSampleAt, feedBreadcrumbTrail. HikeHistory
// keeps 13 samples; hand computed: sxy 1205, sxx 4550 -> 953.4 m/h ("+950");
// speed 38.47 m / 60 s = 0.6412 m/s ("26:00"). The trail keeps 2 points
// (the GPS moves about 30 m, decimation 15 m: 10:50:26 and 10:50:57).
(:test, :chaintest, :typecheck(false))
function testChainTickSalvanClimb1Hz(logger)
{
	ChainHelper.reset();
	var errs = [];
	var secs = [-2, 2, 6, 8, 10, 11, 13, 17, 19, 21, 25, 29, 31, 33, 37, 42, 43, 47, 48, 52, 54, 56, 60];
	var alts = [2133.2, 2134.2, 2135.4, 2136.0, 2136.4, 2136.6, 2137.0, 2138.0, 2138.6, 2139.2, 2140.4, 2141.6,
		2142.2, 2142.6, 2143.6, 2144.8, 2144.8, 2146.0, 2146.2, 2147.4, 2148.0, 2148.6, 2149.4];
	var dists = [1654.02, 1656.43, 1658.94, 1660.53, 1661.71, 1661.98, 1663.43, 1666.47, 1667.27, 1669.32, 1671.53, 1672.86,
		1673.65, 1675.06, 1677.24, 1679.69, 1680.09, 1683.31, 1683.71, 1686.73, 1688.20, 1689.86, 1692.49];
	var lats = [46.1244388, 46.1244548, 46.1244570, 46.1244680, 46.1244735, 46.1244712, 46.1244583, 46.1244555,
		46.1244554, 46.1244595, 46.1244642, 46.1244625, 46.1244583, 46.1244585, 46.1244678, 46.1244589,
		46.1244559, 46.1244617, 46.1244658, 46.1244748, 46.1244715, 46.1244802, 46.1244656];
	var lons = [6.9858358, 6.9858156, 6.9857825, 6.9857683, 6.9857552, 6.9857560, 6.9857520, 6.9857142,
		6.9857039, 6.9856781, 6.9856489, 6.9856320, 6.9856234, 6.9856060, 6.9855851, 6.9855806,
		6.9855770, 6.9855445, 6.9855460, 6.9855144, 6.9854968, 6.9854803, 6.9854535];

	var data = new WatchData();
	var trail = new BreadcrumbTrail();
	$.session = new FakeSession(true);
	var end = ChainHelper.slowViewEndMs();
	var row = 0;
	for (var k = 0; k <= 60; k++)
	{
		while (row + 1 < secs.size() && secs[row + 1] <= k)
		{
			row += 1;
		}
		SpeedTestHelper.feedTick(data,
			ChainHelper.gps(lats[row], lons[row], Position.QUALITY_GOOD, alts[row], null),
			ChainHelper.act(alts[row], dists[row], 139, 0.0, 1905000 + k * 1000),
			ChainHelper.sensor(alts[row], null, null));
		data.endMeasure();
		if ($.shouldRecordHikeSample($.hasActiveSession(), $.isRecording()))
		{
			data.recordHikeSampleAt(end - (60 - k) * 1000);
		}
		$.feedBreadcrumbTrail(trail, data);
	}

	ChainHelper.expectEq(errs, "13 samples (one every 5 s)", data.hikeHistory.getCount(), 13);
	var v = data.getHikeVerticalSpeedAt(end);
	var sp = data.getHikeSpeedAt(end);
	logger.debug("extract T: " + v + " m/h, " + sp + " m/s, trail " + trail.getCount());
	ChainHelper.near(errs, "vertical speed", v, 953.4, 0.5);
	ChainHelper.near(errs, "speed", sp, 0.6412, 0.001);
	ChainHelper.expect(errs, "pace page", ChainHelper.pace(data), "139|+950|26:00|32:45");
	ChainHelper.near(errs, "flight vario (1 s, last tick)", data.getVario(), 0.8, 0.01);
	if (trail.getCount() != 2)
	{
		errs.add("trail: expected 2 points, got " + trail.getCount());
	}
	return ChainHelper.finish(errs, logger);
}

// F11: instantaneous speed 0 (as at 10:51:28 in the TCX) while walking: the
// flight page reads 0 km/h, but PACE uses the distance -> 26:48, not --:--.
(:test, :chaintest, :typecheck(false))
function testChainPaceWhenInstantSpeedZero(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	var end = ChainHelper.viewEndMs();
	ChainHelper.feedExtract(data, ChainHelper.extractM(), end);
	SpeedTestHelper.feedTick(data, ChainHelper.gps(null, null, 0, null, null),
		ChainHelper.act(2149.4, 1692.49, null, 0.0, null), ChainHelper.sensor(null, null, null));

	Test.assertMessage(data.getSpeed() == 0.0, "getSpeed() = 0.0, got " + data.getSpeed());
	ChainHelper.expect(errs, "flight page", ChainHelper.fly(data), "2149| m|0| km/h");
	ChainHelper.expect(errs, "pace page", ChainHelper.pace(data), "--|+940|26:48|--:--");
	return ChainHelper.finish(errs, logger);
}

// ---------------------------------------------------------------------------
// Position page fields (F12, F13 / D3) and flight speed (F14, D4)
// ---------------------------------------------------------------------------

// F12: ALTITUDE | ELEV. GAIN | DISTANCE | TIMER with and without a session.
(:test, :chaintest, :typecheck(false))
function testChainPositionPageFields(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	var info = ChainHelper.act(2149.4, 1692.49, null, null, 1965000);
	info.totalAscent = 335.0;
	SpeedTestHelper.feedTick(data, null, info, null);

	$.session = new FakeSession(true);
	ChainHelper.expect(errs, "session", ChainHelper.position(data), "2149|335|1.7|32:45");
	$.session = null;
	ChainHelper.expect(errs, "no session", ChainHelper.position(data), "2149|--|--|--:--");

	$.session = new FakeSession(true);
	info.elapsedDistance = 0.0;
	SpeedTestHelper.feedTick(data, null, info, null);
	ChainHelper.expect(errs, "distance 0", ChainHelper.position(data), "2149|335|0.0|32:45");
	info.elapsedDistance = 999900.0;
	SpeedTestHelper.feedTick(data, null, info, null);
	ChainHelper.expect(errs, "distance 999.9 km", ChainHelper.position(data), "2149|335|999.9|32:45");
	info.totalAscent = null;
	info.elapsedDistance = null;
	SpeedTestHelper.feedTick(data, null, info, null);
	ChainHelper.expect(errs, "ascent and distance null", ChainHelper.position(data), "2149|--|--|32:45");
	info.totalAscent = 0.0;
	SpeedTestHelper.feedTick(data, null, info, null);
	ChainHelper.expect(errs, "ascent 0", ChainHelper.position(data), "2149|0|--|32:45");
	return ChainHelper.finish(errs, logger);
}

// D3 (to fix): a negative distance reads "--". Today "-0.0" and "-1.0".
(:test, :chaintest, :typecheck(false))
function testDefectNegativeDistance(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	$.session = new FakeSession(true);
	var dists = [-5.0, -1000.0];
	for (var i = 0; i < dists.size(); i++)
	{
		ChainHelper.actTick(data, 2149.4, dists[i], null, 1965000);
		ChainHelper.expect(errs, "distance " + dists[i], ChainHelper.position(data), "2149|--|--|32:45");
	}
	return ChainHelper.finish(errs, logger);
}

// F14: flight speed in km/h, source priority Sensor -> GPS -> Activity.
(:test, :chaintest, :typecheck(false))
function testChainFlightSpeedKmh(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();

	SpeedTestHelper.feedTick(data, ChainHelper.gps(null, null, 0, null, 9.844), ChainHelper.act(1732.2, null, null, null, null), ChainHelper.sensor(null, null, null));
	ChainHelper.expect(errs, "sensor null, GPS 9.844", ChainHelper.fly(data), "1732| m|35| km/h");
	SpeedTestHelper.feedTick(data, ChainHelper.gps(null, null, 0, null, 9.844), ChainHelper.act(1732.2, null, null, null, null), ChainHelper.sensor(null, 2.0, null));
	ChainHelper.expect(errs, "sensor 2.0 wins", ChainHelper.fly(data), "1732| m|7| km/h");
	SpeedTestHelper.feedTick(data, ChainHelper.gps(null, null, 0, null, null), ChainHelper.act(1732.2, null, null, 0.0, null), ChainHelper.sensor(null, null, null));
	ChainHelper.expect(errs, "Activity 0.0 only", ChainHelper.fly(data), "1732| m|0| km/h");
	SpeedTestHelper.feedTick(data, ChainHelper.gps(null, null, 0, null, null), ChainHelper.act(1732.2, null, null, null, null), ChainHelper.sensor(null, null, null));
	ChainHelper.expect(errs, "no speed -> no km/h text", ChainHelper.fly(data), "1732| m");
	SpeedTestHelper.feedTick(data, ChainHelper.gps(null, null, 0, null, 1000.0), ChainHelper.act(1732.2, null, null, null, null), null);
	ChainHelper.expect(errs, "GPS 1000 m/s", ChainHelper.fly(data), "1732| m|3600| km/h");
	return ChainHelper.finish(errs, logger);
}

// Known defect D4, NOT fixed (FlyInstrumentView untouched, decision
// 2026-10-06): a negative speed is shown, -1 m/s -> "-4" km/h. Pinned.
(:test, :chaintest, :typecheck(false))
function testKnownDefectD4NegativeFlightSpeedShown(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	SpeedTestHelper.feedTick(data, ChainHelper.gps(null, null, 0, null, -1.0), ChainHelper.act(1732.2, null, null, null, null), null);
	ChainHelper.expect(errs, "D4 pinned: -1 m/s", ChainHelper.fly(data), "1732| m|-4| km/h");
	return ChainHelper.finish(errs, logger);
}

// ---------------------------------------------------------------------------
// Heart rate (F16, F17 / D5) and timer (F18, F19 / D6)
// ---------------------------------------------------------------------------

// F16: Activity -> Sensor priority, and the valid bounds 25 and 250 bpm.
(:test, :chaintest, :typecheck(false))
function testChainHeartRateSources(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	var cases = [[139, 141, "139"], [null, 141, "141"], [null, null, "--"], [25, null, "25"], [250, null, "250"], [null, 25, "25"], [null, 250, "250"]];
	for (var i = 0; i < cases.size(); i++)
	{
		SpeedTestHelper.feedTick(data, null, ChainHelper.act(2149.4, null, cases[i][0], null, null), ChainHelper.sensor(null, null, cases[i][1]));
		ChainHelper.expect(errs, "Activity " + cases[i][0] + " / Sensor " + cases[i][1], ChainHelper.pace(data), cases[i][2] + "|--|--:--|--:--");
	}
	return ChainHelper.finish(errs, logger);
}

// D5 (to fix): heart rate outside 25..250 bpm -> "--". Today shown as is.
(:test, :chaintest, :typecheck(false))
function testDefectHeartRateOutOfBounds(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	var hrs = [24, 251, 0, 255, -1];
	for (var i = 0; i < hrs.size(); i++)
	{
		SpeedTestHelper.feedTick(data, null, ChainHelper.act(2149.4, null, hrs[i], null, null), ChainHelper.sensor(null, null, null));
		ChainHelper.expect(errs, "Activity HR " + hrs[i], ChainHelper.pace(data), "--|--|--:--|--:--");
	}
	var sensorHrs = [24, 251, 300];
	for (var i = 0; i < sensorHrs.size(); i++)
	{
		SpeedTestHelper.feedTick(data, null, ChainHelper.act(2149.4, null, null, null, null), ChainHelper.sensor(null, null, sensorHrs[i]));
		ChainHelper.expect(errs, "Sensor HR " + sensorHrs[i], ChainHelper.pace(data), "--|--|--:--|--:--");
	}
	return ChainHelper.finish(errs, logger);
}

// D5, choice of 2026-10-06: the source priority of getHeartRate() is not
// changed (Activity first, even out of range); the bound is applied at
// display time only, so an invalid Activity HR hides a valid Sensor HR and
// the page reads "--" rather than mixing sources.
(:test, :chaintest, :typecheck(false))
function testChainHeartRateInvalidActivityHidesSensor(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	var cases = [[0, 141], [24, 141], [251, 141]];
	for (var i = 0; i < cases.size(); i++)
	{
		SpeedTestHelper.feedTick(data, null, ChainHelper.act(2149.4, null, cases[i][0], null, null), ChainHelper.sensor(null, null, cases[i][1]));
		ChainHelper.expectEq(errs, "getHeartRate() keeps Activity " + cases[i][0], data.getHeartRate(), cases[i][0]);
		ChainHelper.expect(errs, "Activity " + cases[i][0] + " / Sensor " + cases[i][1], ChainHelper.pace(data), "--|--|--:--|--:--");
	}
	return ChainHelper.finish(errs, logger);
}

// F18: TIMER on the Position and Pace pages and on the Paused screen.
(:test, :chaintest, :typecheck(false))
function testChainTimerDisplay(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	$.session = new FakeSession(true);
	var cases = [[1965000, "32:45"], [359999000, "99:59:59"], [360000000, "100:00:00"], [0, "00:00"], [null, "--:--"]];
	for (var i = 0; i < cases.size(); i++)
	{
		ChainHelper.actTick(data, 2149.4, null, null, cases[i][0]);
		ChainHelper.expect(errs, "position " + cases[i][0], ChainHelper.position(data), "2149|--|--|" + cases[i][1]);
		ChainHelper.expect(errs, "pace " + cases[i][0], ChainHelper.pace(data), "--|--|--:--|" + cases[i][1]);
	}

	ChainHelper.actTick(data, 2149.4, null, null, 1965000);
	$.session = null;
	ChainHelper.expect(errs, "no session", ChainHelper.position(data), "2149|--|--|--:--");
	ChainHelper.expect(errs, "no session, pace", ChainHelper.pace(data), "--|--|--:--|--:--");

	$.session = new FakeSession(false);
	ChainHelper.expect(errs, "paused, position", ChainHelper.position(data), "2149|--|--|32:45");
	ChainHelper.expect(errs, "paused, pace", ChainHelper.pace(data), "--|--|--:--|32:45");
	ChainHelper.expect(errs, "paused, Paused screen", ChainHelper.paused(new ChainApp(data, null)), "Paused|32:45|START: resume");
	return ChainHelper.finish(errs, logger);
}

// D6 (to fix): a negative duration reads "--:--". Today -65 000 ms -> "-1:-5".
(:test, :chaintest, :typecheck(false))
function testDefectNegativeDuration(logger)
{
	ChainHelper.reset();
	var errs = [];
	var ms = [-65000, -1000, -1, -3600000];
	for (var i = 0; i < ms.size(); i++)
	{
		ChainHelper.expect(errs, "formatDuration(" + ms[i] + ")", $.formatDuration(ms[i]), "--:--");
	}
	ChainHelper.expect(errs, "Paused screen text", $.pausedScreenTimerText(true, -65000), "--:--");
	var data = new WatchData();
	$.session = new FakeSession(true);
	ChainHelper.actTick(data, 2149.4, null, null, -65000);
	ChainHelper.expect(errs, "position page", ChainHelper.position(data), "2149|--|--|--:--");
	return ChainHelper.finish(errs, logger);
}

// ---------------------------------------------------------------------------
// Map (F20, F21) and compass (F22-F25 / D7, D8, D9)
// ---------------------------------------------------------------------------

// F20: "Waiting for GPS" only without trail and fix; the trail alone (no
// text) when the fix is lost. The 20 real Salvan GPX points (about 50 m)
// give 3 trail points after the 15 m decimation, not 20.
(:test, :chaintest, :typecheck(false))
function testChainMapWaitingAndTrailOnly(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	var trail = new BreadcrumbTrail();
	ChainHelper.expect(errs, "no trail, no fix", ChainHelper.map(data, trail), "Waiting for|GPS");

	var lats = MapTestHelper.salvanLats();
	var lons = MapTestHelper.salvanLons();
	var reference = new BreadcrumbTrail();
	for (var i = 0; i < lats.size(); i++)
	{
		data.gpsData = MapTestHelper.gps(lats[i], lons[i], Position.QUALITY_GOOD);
		$.feedBreadcrumbTrail(trail, data);
		reference.update(lats[i], lons[i]);
	}
	var count = trail.getCount();
	ChainHelper.expectEq(errs, "20 GPX points -> 3 trail points", count, 3);
	ChainHelper.expectEq(errs, "same as BreadcrumbTrail.update()", count, reference.getCount());

	data.gpsData = MapTestHelper.gps(lats[19], lons[19], Position.QUALITY_NOT_AVAILABLE);
	$.feedBreadcrumbTrail(trail, data);
	ChainHelper.expectEq(errs, "a tick without fix adds nothing", trail.getCount(), count);
	ChainHelper.expect(errs, "trail, fix lost", ChainHelper.map(data, trail), "");

	data.gpsData = MapTestHelper.gps(lats[19], lons[19], Position.QUALITY_GOOD);
	ChainHelper.expect(errs, "trail and fix (50 m: no scale bar)", ChainHelper.map(data, trail), "");
	return ChainHelper.finish(errs, logger);
}

// F21: a 2 km north-south trail shows a "500 m" scale bar on every screen
// (1000 m is 0.85 r > w/3, 500 m fits; fenix6pro: 10.79 m/px, 46 px).
(:test, :chaintest, :typecheck(false))
function testChainMapScaleBarTwoKmTrail(logger)
{
	ChainHelper.reset();
	var data = new WatchData();
	var trail = new BreadcrumbTrail();
	for (var k = 0; k <= 36; k++)
	{
		var lat = (k == 36) ? 46.1179662 : 46.1 + 0.0005 * k;
		data.gpsData = { "lat" => lat, "long" => 7.0, "accuracy" => Position.QUALITY_GOOD, "heading" => 0.0 };
		$.feedBreadcrumbTrail(trail, data);
	}
	Test.assertEqualMessage(trail.getCount(), 37, "37 points, all more than 15 m apart");
	Test.assertEqualMessage(ChainHelper.map(data, trail), "500 m", "scale bar label");
	return true;
}

// F22: real point (TCX 10:51:28) as Location.toDegrees() gives it (Doubles).
(:test, :chaintest, :typecheck(false))
function testChainCompassNorthEast(logger)
{
	ChainHelper.reset();
	var errs = [];
	ChainHelper.expect(errs, "Salvan", ChainHelper.compass(0.0, 46.12446558661759d, 6.985453460365534d), "N|S|E|W|46°07'28.1\"N|6°59'7.6\"E");
	ChainHelper.expect(errs, "Salvan, Float", ChainHelper.compass(0.785, 46.124466, 6.9854535), "N|S|E|W|46°07'28.1\"N|6°59'7.6\"E");
	ChainHelper.expect(errs, "no position", ChainHelper.compass(0.0, null, null), "N|S|E|W|Waiting for|GPS");
	return ChainHelper.finish(errs, logger);
}

// D7 (to fix): south / west: the letter alone gives the hemisphere, no minus
// sign. Today "-22°57'6.8"S" and "-43°12'37.8"W".
(:test, :chaintest, :typecheck(false))
function testDefectCompassSouthWestSign(logger)
{
	ChainHelper.reset();
	var errs = [];
	ChainHelper.expect(errs, "Rio", ChainHelper.compass(0.0, -22.9519d, -43.2105d), "N|S|E|W|22°57'6.8\"S|43°12'37.8\"W");
	ChainHelper.expect(errs, "just south / west of 0", ChainHelper.compass(0.0, -0.5d, -0.5d), "N|S|E|W|0°30'0.0\"S|0°30'0.0\"W");
	return ChainHelper.finish(errs, logger);
}

// D8 (to fix): seconds that round to 60.0 carry into the minutes (and the
// degrees). Today "45°59'60.0"N" and "6°59'60.0"E".
(:test, :chaintest, :typecheck(false))
function testDefectCompassSecondsRoundTo60(logger)
{
	ChainHelper.reset();
	var errs = [];
	ChainHelper.expect(errs, "north-east", ChainHelper.compass(0.0, 45.99999d, 6.99999d), "N|S|E|W|46°00'0.0\"N|7°00'0.0\"E");
	ChainHelper.expect(errs, "minutes carry", ChainHelper.compass(0.0, 46.4999999d, 7.0d), "N|S|E|W|46°30'0.0\"N|7°00'0.0\"E");
	return ChainHelper.finish(errs, logger);
}

// D9 (to fix): a null heading (Position.Info.heading can be null) must not
// crash the Position page: drawn without rotation. Today WatchDisplay.compass()
// does heading = -heading on null and throws: this test ends in ERROR, alone
// (every test runs in a fresh app instance).
(:test, :chaintest, :typecheck(false))
function testDefectCompassNullHeading(logger)
{
	ChainHelper.reset();
	var errs = [];
	ChainHelper.expect(errs, "null heading, no GPS", ChainHelper.compass(null, null, null), "N|S|E|W|Waiting for|GPS");
	ChainHelper.expect(errs, "null heading, fix", ChainHelper.compass(null, 46.12446558661759d, 6.985453460365534d), "N|S|E|W|46°07'28.1\"N|6°59'7.6\"E");
	return ChainHelper.finish(errs, logger);
}

// ---------------------------------------------------------------------------
// Pause (F26, F27)
// ---------------------------------------------------------------------------

// F26: the Paused screen texts, with and without a session.
(:test, :chaintest, :typecheck(false))
function testChainPausedViewTexts(logger)
{
	ChainHelper.reset();
	var errs = [];
	var data = new WatchData();
	ChainHelper.actTick(data, 2149.4, null, null, 1965000);
	var app = new ChainApp(data, null);

	$.session = new FakeSession(false);
	ChainHelper.expect(errs, "paused", ChainHelper.paused(app), "Paused|32:45|START: resume");
	$.session = new FakeSession(true);
	ChainHelper.expect(errs, "recording", ChainHelper.paused(app), "Paused|32:45|START: resume");
	$.session = null;
	ChainHelper.expect(errs, "no session", ChainHelper.paused(app), "Paused|--:--|START: resume");
	ChainHelper.expect(errs, "no app", ChainHelper.paused(null), "Paused|--:--|START: resume");
	return ChainHelper.finish(errs, logger);
}

// F27: while paused the sensors are off (HR "--"), the GPS keeps feeding the
// trail and no hike sample is taken; after resume HR 139 is back.
(:test, :chaintest, :typecheck(false))
function testChainPauseSensorsOffKeepsGps(logger)
{
	ChainHelper.reset();
	var errs = [];
	Test.assertEqualMessage($.sensorsForState(true, $.activeSensorList()).size(), 0, "paused -> no sensor enabled");

	var data = new WatchData();
	var trail = new BreadcrumbTrail();
	$.session = new FakeSession(false);
	var lat = 46.1244656;
	for (var i = 0; i < 2; i++)
	{
		SpeedTestHelper.feedTick(data, ChainHelper.gps(lat + i * 0.00018, 6.9854535, Position.QUALITY_GOOD, 2149.4, null),
			ChainHelper.act(2149.4, 1692.49, null, null, 1965000), ChainHelper.sensor(2149.4, null, null));
		if ($.shouldRecordHikeSample($.hasActiveSession(), $.isRecording()))
		{
			data.recordHikeSampleAt(100000 + i * 5000);
		}
		$.feedBreadcrumbTrail(trail, data);
		if (trail.getCount() != i + 1)
		{
			errs.add("paused tick " + i + ": trail expected " + (i + 1) + ", got " + trail.getCount());
		}
	}
	ChainHelper.expectEq(errs, "no hike sample while paused", data.hikeHistory.getCount(), 0);
	ChainHelper.expect(errs, "paused, pace page", ChainHelper.pace(data), "--|--|--:--|32:45");

	$.session.start();
	SpeedTestHelper.feedTick(data, ChainHelper.gps(lat, 6.9854535, Position.QUALITY_GOOD, 2149.4, null),
		ChainHelper.act(2149.4, 1692.49, 139, null, 1966000), ChainHelper.sensor(2149.4, null, 139));
	if ($.shouldRecordHikeSample($.hasActiveSession(), $.isRecording()))
	{
		data.recordHikeSampleAt(110000);
	}
	ChainHelper.expectEq(errs, "resumed -> sampling again", data.hikeHistory.getCount(), 1);
	ChainHelper.expect(errs, "resumed, pace page", ChainHelper.pace(data), "139|--|--:--|32:46");
	return ChainHelper.finish(errs, logger);
}

// ---------------------------------------------------------------------------
// Flight vario, read only (F28, F29): current behaviour pinned.
// ---------------------------------------------------------------------------

// F28: endMeasure() over 4 ticks; a tick without altitude keeps the vario.
(:test, :chaintest, :typecheck(false))
function testVarioEndMeasureSequence(logger)
{
	var errs = [];
	var data = new WatchData();
	var alts = [1000.0, 1001.5, null, 1000.5];
	var varios = [null, 1.5, 1.5, -1.0];
	var olds = [1000.0, 1001.5, 1001.5, 1000.5];
	for (var i = 0; i < alts.size(); i++)
	{
		if (alts[i] != null)
		{
			ChainHelper.actTick(data, alts[i], null, null, null);
		}
		else
		{
			SpeedTestHelper.feedTick(data, null, null, null);
		}
		data.endMeasure();
		if (varios[i] == null)
		{
			if (data.getVario() != null) { errs.add("tick " + i + ": vario expected null, got " + data.getVario()); }
		}
		else
		{
			ChainHelper.near(errs, "tick " + i + " vario", data.getVario(), varios[i], 0.0001);
		}
		ChainHelper.near(errs, "tick " + i + " oldAlt", data.oldAlt, olds[i], 0.0001);
	}
	return ChainHelper.finish(errs, logger);
}

// F29: background colour thresholds (climb >= 0.3, sink <= -2.0) and text.
(:test, :chaintest, :typecheck(false))
function testVarioDisplayThresholdsAndText(logger)
{
	ChainHelper.reset();
	var errs = [];
	var values = [0.3, 0.29, -2.0, -1.99, 1.5, -1.0, 0.0];
	var colors = [Graphics.COLOR_GREEN, Graphics.COLOR_LT_GRAY, Graphics.COLOR_RED, Graphics.COLOR_LT_GRAY,
		Graphics.COLOR_GREEN, Graphics.COLOR_LT_GRAY, Graphics.COLOR_LT_GRAY];
	var texts = ["+0.3", "+0.3", "-2.0", "-2.0", "+1.5", "-1.0", "+0.0"];
	for (var i = 0; i < values.size(); i++)
	{
		var dc = ChainHelper.newDc();
		var display = new WatchDisplay(dc);
		display.start(values[i]);
		if (dc.clearedWith != colors[i])
		{
			errs.add("start(" + values[i] + "): colour " + colors[i] + " expected, got " + dc.clearedWith);
		}
		display.vario(values[i]);
		ChainHelper.expect(errs, "vario(" + values[i] + ")", ChainHelper.join(dc.texts), texts[i] + "| m/s");
	}
	return ChainHelper.finish(errs, logger);
}
