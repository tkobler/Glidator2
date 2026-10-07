using Toybox.Test;
using Toybox.Graphics;
using Toybox.Position;
using Toybox.System;
using Toybox.WatchUi;

// ---------------------------------------------------------------------------
// Display bench (plan docs/tests/plan-test-approfondi.md, sections 2.4 and
// 3.2): every page is drawn on a fake Dc (BenchDc) that records each text,
// measured with the device's real fonts (the Dc of a small BufferedBitmap),
// in 5 states: Empty, Normal, Extreme, Paused, Recording. Checks, on the ink
// box of each text (its text box shrunk by LAYOUT_INK_K x height at the top
// and at the bottom and by 1 px on each side):
//   OVERLAP    two texts of the same image overlap (touching is fine);
//   OFFSCREEN  a corner is outside the screen (circle on round screens,
//              [0, w] x [0, h] otherwise; Instinct cut corners: manual M08);
//   SUBSCREEN  a text cuts the Instinct sub-window (WatchUi.getSubscreen(),
//              or the table of section 2.2 when the API gives nothing);
//   STATE      the texts drawn are not the ones the state should give (the
//              state setup is wrong, the layout result would mean nothing).
// Each defect is logged as one ERROR line
//   LAYOUT <w>x<h> <shape> <View>/<State>: OVERLAP "a"(x0,y0,x1,y1) x "b"(...)
// and the test returns false (FAIL). A real layout defect found here is an
// expected result: the app code is not changed by this bench.
//
// Annotated :layouttest as well as :test so that the functional suite can be
// built without the bench (and the bench without :chaintest), from a
// temporary jungle with base.excludeAnnotations = layouttest (plan 4.3).
// The bench depends on Tests.mc only (MapTestHelper), never on TestsChain.mc.
// ---------------------------------------------------------------------------

// Everything lives in one module: the device limits the 'globals' module to
// 253 members, and the 39 bench tests plus their classes would not fit there.
(:test, :layouttest)
module LayoutBenchTests
{

// Ink margin, as a share of the text height, removed at the top and at the
// bottom of each text box (fonts carry a lot of empty leading). Calibrated on
// fenix6pro: HikePosition/Normal and HikePace/Normal must give 0 defect.
// The plan's 0.15 left 1 px between "TIMER" (FONT_XTINY, 19 px, margin 2)
// and the timer (FONT_NUMBER_MEDIUM, 74 px, margin 11) there; 0.16 gives
// XTINY a 3 px margin and the two boxes only touch. Same value everywhere.
const LAYOUT_INK_K = 0.16;

// Fake Dc: records every drawText() as [text, font, x, y, justify, width,
// height], width and height measured by the real Dc `m`; any other drawing
// call is ignored. `bmp` keeps the measuring BufferedBitmap alive.
(:test, :layouttest, :typecheck(false))
class BenchDc
{
	var w;
	var h;
	var m;
	var bmp;
	var texts = [];

	function initialize(width, height, measureDc, bitmap)
	{
		w = width;
		h = height;
		m = measureDc;
		bmp = bitmap;
	}

	function getWidth() { return w; }
	function getHeight() { return h; }
	function getTextDimensions(t, f) { return m.getTextDimensions(t, f); }
	function getTextWidthInPixels(t, f) { return m.getTextWidthInPixels(t, f); }
	function getFontHeight(f) { return m.getFontHeight(f); }
	function drawText(x, y, f, t, j)
	{
		var d = m.getTextDimensions(t, f);
		texts.add([t, f, x, y, j, d[0], d[1]]);
	}
	function setColor(fg, b) {}
	function clear() {}
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

// ActivityRecording.Session stand-in: isRecording() only, no FIT file. Also
// answers start/stop/save/discard/addLap, so that a test stopped half way
// cannot break a later one.
(:test, :layouttest)
class BenchSession
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

// What the hike views and PausedView read from the app.
(:test, :layouttest)
class BenchMainView
{
	var data;

	function initialize(d) { data = d; }
}

(:test, :layouttest)
class BenchApp
{
	var mainView;
	var breadcrumbTrail;

	function initialize(d, trail)
	{
		mainView = new BenchMainView(d);
		breadcrumbTrail = trail;
	}
}

// Helpers live in a class: a (:test) global function would be run as a test.
(:test, :layouttest, :typecheck(false))
class LayoutBench
{
	// --- Globals the views read; each test starts and ends without a session.
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

	// --- Screen -------------------------------------------------------------

	// A BenchDc of the screen size, measuring with a 16 x 16 BufferedBitmap
	// (Graphics.createBufferedBitmap from CIQ 4.0.0, the constructor before).
	static function newDc()
	{
		var s = System.getDeviceSettings();
		var bmp;
		if (Graphics has :createBufferedBitmap)
		{
			bmp = Graphics.createBufferedBitmap({:width => 16, :height => 16}).get();
		}
		else
		{
			bmp = new Graphics.BufferedBitmap({:width => 16, :height => 16});
		}
		return new BenchDc(s.screenWidth, s.screenHeight, bmp.getDc(), bmp);
	}

	static function isRound()
	{
		return System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
	}

	static function shapeName(shape)
	{
		if (shape == 1) { return "round"; }
		if (shape == 2) { return "semi-round"; }
		if (shape == 3) { return "rectangle"; }
		if (shape == 4) { return "semi-octagon"; }
		return "shape" + shape;
	}

	// Sub-window of the plan's table (section 2.2), app screen coordinates,
	// for a non-round screen of this size; null when there is none.
	static function tableSubscreen(w, h, round)
	{
		if (round) { return null; }
		if (w == 176 && h == 176) { return [113, 0, 62, 62]; }
		if (w == 166 && h == 166) { return [113, 0, 52, 52]; }
		if (w == 163 && h == 156) { return [108, 0, 54, 54]; }
		return null;
	}

	// WatchUi.getSubscreen() (CIQ 3.2.7) as [x, y, width, height], or null.
	static function apiSubscreen()
	{
		if (!(WatchUi has :getSubscreen))
		{
			return null;
		}
		var b = WatchUi.getSubscreen();
		if (b == null)
		{
			return null;
		}
		return [b.x == null ? 0 : b.x, b.y == null ? 0 : b.y, b.width, b.height];
	}

	// The sub-window the checks use: the API's, else the table's.
	static function subscreen()
	{
		var api = apiSubscreen();
		if (api != null)
		{
			return api;
		}
		var s = System.getDeviceSettings();
		return tableSubscreen(s.screenWidth, s.screenHeight, isRound());
	}

	// --- Boxes (pure) -------------------------------------------------------

	// Text box [x0, y0, x1, y1] of a recorded text [t, f, x, y, j, tw, th]:
	// j & 3 gives RIGHT (0), CENTER (1) or LEFT (2); VCENTER (4) centres it
	// vertically on y, otherwise y is the top.
	static function box(e)
	{
		var x = e[2].toFloat();
		var y = e[3].toFloat();
		var j = e[4];
		var tw = e[5].toFloat();
		var th = e[6].toFloat();
		var x0 = x;
		var hj = j & 3;
		if (hj == Graphics.TEXT_JUSTIFY_RIGHT) { x0 = x - tw; }
		else if (hj == Graphics.TEXT_JUSTIFY_CENTER) { x0 = x - tw / 2.0; }
		var y0 = ((j & Graphics.TEXT_JUSTIFY_VCENTER) != 0) ? y - th / 2.0 : y;
		return [x0, y0, x0 + tw, y0 + th];
	}

	// Ink box: the text box less floor(k x height) at the top and the bottom
	// and 1 px on each side.
	static function inkBox(e, k)
	{
		var b = box(e);
		var margin = (k * e[6]).toNumber();
		return [b[0] + 1, b[1] + margin, b[2] - 1, b[3] - margin];
	}

	// True if the two boxes share an area: width AND height strictly > 0.
	static function overlaps(a, b)
	{
		var w = (a[2] < b[2] ? a[2] : b[2]) - (a[0] > b[0] ? a[0] : b[0]);
		var h = (a[3] < b[3] ? a[3] : b[3]) - (a[1] > b[1] ? a[1] : b[1]);
		return w > 0 && h > 0;
	}

	// True if the 4 corners are on the screen: within the circle of radius
	// w/2 + 1 on a round screen, within [0, w] x [0, h] otherwise.
	static function onScreen(b, w, h, round)
	{
		if (!round)
		{
			return b[0] >= 0 && b[1] >= 0 && b[2] <= w && b[3] <= h;
		}
		var cx = w / 2.0;
		var cy = h / 2.0;
		var r = w / 2.0 + 1;
		var xs = [b[0], b[2]];
		var ys = [b[1], b[3]];
		for (var i = 0; i < 2; i++)
		{
			for (var k = 0; k < 2; k++)
			{
				var dx = xs[i] - cx;
				var dy = ys[k] - cy;
				if (dx * dx + dy * dy > r * r)
				{
					return false;
				}
			}
		}
		return true;
	}

	static function fmtBox(b)
	{
		var s = "(";
		for (var i = 0; i < 4; i++)
		{
			s += (i > 0 ? "," : "") + b[i].toFloat().format("%.0f");
		}
		return s + ")";
	}

	static function named(e, b)
	{
		return "\"" + e[0] + "\"" + fmtBox(b);
	}

	// Every OVERLAP / OFFSCREEN / SUBSCREEN defect of a list of recorded
	// texts, one string each. sub: [x, y, width, height] or null.
	static function findDefects(texts, w, h, round, sub, k)
	{
		var out = [];
		var inks = [];
		for (var i = 0; i < texts.size(); i++)
		{
			inks.add(inkBox(texts[i], k));
		}
		for (var i = 0; i < texts.size(); i++)
		{
			for (var j = i + 1; j < texts.size(); j++)
			{
				if (overlaps(inks[i], inks[j]))
				{
					out.add("OVERLAP " + named(texts[i], inks[i]) + " x " + named(texts[j], inks[j]));
				}
			}
		}
		for (var i = 0; i < texts.size(); i++)
		{
			if (!onScreen(inks[i], w, h, round))
			{
				out.add("OFFSCREEN " + named(texts[i], inks[i]));
			}
		}
		if (sub != null)
		{
			var sb = [sub[0], sub[1], sub[0] + sub[2], sub[1] + sub[3]];
			for (var i = 0; i < texts.size(); i++)
			{
				if (overlaps(inks[i], sb))
				{
					out.add("SUBSCREEN " + named(texts[i], inks[i]) + " in " + fmtBox(sb));
				}
			}
		}
		return out;
	}

	static function join(texts)
	{
		var s = "";
		for (var i = 0; i < texts.size(); i++)
		{
			if (i > 0) { s += "|"; }
			s += texts[i][0];
		}
		return s;
	}

	// --- States (injected data) --------------------------------------------

	// Real extract M (steep climb, lap 1 of garmin_data/activity_24346302742.tcx):
	// HikeHistory samples 10:50:30 -> 10:51:28 UTC (line 11859), [seconds
	// before 10:51:28, AltitudeMeters, DistanceMeters]: +944.6 m/h ("+940"),
	// 36.06 m / 58 s ("26:48").
	static function extractM()
	{
		return [
			[-58, -52, -47, -41, -35, -29, -23, -18, -13, -8, 0],
			[2134.2, 2136.0, 2137.0, 2138.6, 2140.4, 2142.2, 2143.6, 2144.8, 2146.0, 2147.4, 2149.4],
			[1656.43, 1660.53, 1663.43, 1667.27, 1671.53, 1673.65, 1677.24, 1679.69, 1683.31, 1686.73, 1692.49]
		];
	}

	// Last sample 500 ms ahead of now: still in the 60 s window when the view
	// reads System.getTimer() a few ms later (see TestsChain.mc, viewEndMs).
	static function feedHistory(data, ex)
	{
		var end = System.getTimer() + 500;
		for (var i = 0; i < ex[0].size(); i++)
		{
			data.activityData = { "altitude" => ex[1][i], "distance" => ex[2][i] };
			data.recordHikeSampleAt(end + ex[0][i] * 1000);
		}
	}

	// Normal: real tick 10:51:28 (altitude 2149.4, distance 1692.49, HR 139,
	// speed 0.0), D+ 335 (synthetic), timer 32:45, heading 0.785 rad, fix,
	// flight vario +0.4.
	static function normalData()
	{
		var d = new WatchData();
		feedHistory(d, extractM());
		d.activityData = { "altitude" => 2149.4, "distance" => 1692.49, "heartRate" => 139,
			"totalAscent" => 335.0, "timerTime" => 1965000, "speed" => 0.0 };
		d.gpsData = { "lat" => 46.12446558661759d, "long" => 6.985453460365534d,
			"accuracy" => Position.QUALITY_GOOD, "heading" => 0.785 };
		d.vario = 0.4;
		return d;
	}

	// Extreme: the widest texts each page can really show. Hike: altitude
	// 6000 (upper bound), D+ 20000 (upper bound), 999.9 km, 99:59:59, HR 250
	// (upper bound), vertical speed -2998 m/h -> "-3000" (cap +-3000 m/h),
	// pace 0.2778 m/s -> "60:00" (slowest shown). Flight: `alt` (8849 m,
	// no bound there), 33.3 m/s -> "120" km/h, vario -10.0.
	static function extremeData(alt, timerMs)
	{
		var d = new WatchData();
		var secs = [];
		var alts = [];
		var dists = [];
		for (var s = -55; s <= 0; s += 5)
		{
			secs.add(s);
			alts.add(3000.0 - (2998.0 / 3600.0) * (s + 55));
			dists.add(1000.0 + 0.2778 * (s + 55));
		}
		feedHistory(d, [secs, alts, dists]);
		d.activityData = { "altitude" => alt, "distance" => 999900.0, "heartRate" => 250,
			"totalAscent" => 20000.0, "timerTime" => timerMs, "speed" => 33.3 };
		d.gpsData = { "lat" => 46.12446558661759d, "long" => 6.985453460365534d,
			"accuracy" => Position.QUALITY_GOOD, "heading" => 0.785 };
		d.vario = -10.0;
		return d;
	}

	static function dataFor(state, extremeAlt, extremeTimer)
	{
		if (state.equals("Empty")) { return new WatchData(); }
		if (state.equals("Extreme")) { return extremeData(extremeAlt, extremeTimer); }
		return normalData();
	}

	// Session and start icon of a state: Empty none; Paused a paused session;
	// Normal, Extreme and Recording a recording one; Recording adds the icon.
	static function applyState(state)
	{
		reset();
		if (state.equals("Empty"))
		{
			return;
		}
		$.session = new BenchSession(!state.equals("Paused"));
		if (state.equals("Recording"))
		{
			$.recordFlashStartMs = System.getTimer();
		}
	}

	// Map trail of a state, with the current fix put in `data`: Empty none;
	// Extreme the 2 km north-south trail of F21 (scale bar "500 m"); else
	// the 20 first real Salvan GPX points (MapTestHelper), fix on the last.
	static function mapTrail(state, data)
	{
		var trail = new BreadcrumbTrail();
		if (state.equals("Empty"))
		{
			return trail;
		}
		if (state.equals("Extreme"))
		{
			for (var k = 0; k <= 36; k++)
			{
				var lat = (k == 36) ? 46.1179662 : 46.1 + 0.0005 * k;
				data.gpsData = { "lat" => lat, "long" => 7.0, "accuracy" => Position.QUALITY_GOOD, "heading" => 0.0 };
				$.feedBreadcrumbTrail(trail, data);
			}
			return trail;
		}
		var lats = MapTestHelper.salvanLats();
		var lons = MapTestHelper.salvanLons();
		for (var i = 0; i < lats.size(); i++)
		{
			data.gpsData = { "lat" => lats[i], "long" => lons[i], "accuracy" => Position.QUALITY_GOOD, "heading" => 0.785 };
			$.feedBreadcrumbTrail(trail, data);
		}
		return trail;
	}

	// Draws `view` in `state` on a new BenchDc and returns it.
	static function render(view, state)
	{
		applyState(state);
		var dc = newDc();
		if (view.equals("HikePosition"))
		{
			var v = new HikePositionView(new BenchApp(dataFor(state, 6000.0, 359999000), null));
			v.onLayout(dc);
			v.onUpdate(dc);
		}
		else if (view.equals("HikePace"))
		{
			var v = new HikePaceView(new BenchApp(dataFor(state, 6000.0, 359999000), null));
			v.onLayout(dc);
			v.onUpdate(dc);
		}
		else if (view.equals("HikeMap"))
		{
			var data = state.equals("Empty") ? new WatchData() : normalData();
			var trail = mapTrail(state, data);
			var v = new HikeMapView(new BenchApp(data, trail));
			v.onLayout(dc);
			v.onUpdate(dc);
		}
		else if (view.equals("Fly"))
		{
			var v = new FlyInstrumentView();
			v.data = dataFor(state, 8848.6, 359999000);
			v.onLayout(dc);
			v.onUpdate(dc);
		}
		else if (view.equals("Paused"))
		{
			var v = new PausedView(new BenchApp(dataFor(state, 6000.0, 360000000), null));
			v.onUpdate(dc);
		}
		else if (view.equals("Time"))
		{
			// TimeView reads the clock and the battery: same drawing call
			// with chosen values (plan 2.4, limit 2).
			var display = new WatchDisplay(dc);
			if (state.equals("Empty")) { display.time_and_battery("00:00", 0); }
			else if (state.equals("Extreme")) { display.time_and_battery("23:59", 100); }
			else { display.time_and_battery("10:51", 76); }
			if ($.isRecordFlashActive()) { display.recordingStartIcon(); }
		}
		else if (view.equals("Compass"))
		{
			// PositionView reads Position.getInfo() itself: same drawing call
			// with chosen values (plan 2.4, limit 1).
			var display = new WatchDisplay(dc);
			if (state.equals("Empty")) { display.compass(0.0, null, null); }
			else if (state.equals("Extreme")) { display.compass(0.785, -89.999972d, -179.999972d); }
			else { display.compass(0.785, 46.12446558661759d, 6.985453460365534d); }
			if ($.isRecordFlashActive()) { display.recordingStartIcon(); }
		}
		return dc;
	}

	// Texts each view must draw in each state, in drawing order.
	static function expected(view, state)
	{
		if (view.equals("HikePosition"))
		{
			if (state.equals("Empty")) { return "ALTITUDE|--|ELEV. GAIN|DISTANCE|--|--|TIMER|--:--"; }
			if (state.equals("Extreme")) { return "ALTITUDE|6000|ELEV. GAIN|DISTANCE|20000|999.9|TIMER|99:59:59"; }
			return "ALTITUDE|2149|ELEV. GAIN|DISTANCE|335|1.7|TIMER|32:45";
		}
		if (view.equals("HikePace"))
		{
			if (state.equals("Empty")) { return "--|VERT. SPD.|PACE|--|--:--|TIMER|--:--"; }
			if (state.equals("Extreme")) { return "250|VERT. SPD.|PACE|-3000|60:00|TIMER|99:59:59"; }
			return "139|VERT. SPD.|PACE|+940|26:48|TIMER|32:45";
		}
		if (view.equals("HikeMap"))
		{
			if (state.equals("Empty")) { return "Waiting for|GPS"; }
			if (state.equals("Extreme")) { return "500 m"; }
			return "";
		}
		if (view.equals("Fly"))
		{
			if (state.equals("Empty")) { return "starting ..."; }
			if (state.equals("Extreme")) { return "8849| m|120| km/h|-10.0| m/s"; }
			return "2149| m|0| km/h|+0.4| m/s";
		}
		if (view.equals("Paused"))
		{
			if (state.equals("Empty")) { return "Paused|--:--|START: resume"; }
			if (state.equals("Extreme")) { return "Paused|100:00:00|START: resume"; }
			return "Paused|32:45|START: resume";
		}
		if (view.equals("Time"))
		{
			if (state.equals("Empty")) { return "00:00|0%"; }
			if (state.equals("Extreme")) { return "23:59|100%"; }
			return "10:51|76%";
		}
		if (view.equals("Compass"))
		{
			if (state.equals("Empty")) { return "N|S|E|W|Waiting for|GPS"; }
			if (state.equals("Extreme")) { return "N|S|E|W|89°59'59.9\"S|179°59'59.9\"W"; }
			return "N|S|E|W|46°07'28.1\"N|6°59'7.6\"E";
		}
		return "unknown view " + view;
	}

	static function header(view, state)
	{
		var s = System.getDeviceSettings();
		return "LAYOUT " + s.screenWidth + "x" + s.screenHeight + " " + shapeName(s.screenShape) + " " + view + "/" + state + ": ";
	}

	// One layout test: draw, check the texts are the state's, check the
	// layout; one ERROR line per defect, then FAIL (return false).
	static function run(logger, view, state)
	{
		var dc = render(view, state);
		reset();
		var s = System.getDeviceSettings();
		var head = header(view, state);
		var errs = [];
		var drawn = join(dc.texts);
		var want = expected(view, state);
		if (!drawn.equals(want))
		{
			errs.add("STATE texts \"" + drawn + "\", expected \"" + want + "\"");
		}
		var defects = findDefects(dc.texts, s.screenWidth, s.screenHeight, isRound(), subscreen(), LAYOUT_INK_K);
		for (var i = 0; i < defects.size(); i++)
		{
			errs.add(defects[i]);
		}

		var boxes = "";
		for (var i = 0; i < dc.texts.size(); i++)
		{
			boxes += " " + named(dc.texts[i], inkBox(dc.texts[i], LAYOUT_INK_K));
		}
		logger.debug(head + "ink" + boxes);
		for (var i = 0; i < errs.size(); i++)
		{
			logger.error(head + errs[i]);
		}
		return errs.size() == 0;
	}

	static function entry(t, x, y, j, tw, th)
	{
		return [t, Graphics.FONT_XTINY, x, y, j, tw, th];
	}

	// Checks that the defects starting with `prefix` are exactly one per
	// name in `names` (each name found in its line), in that order.
	static function expectDefects(errs, label, defs, prefix, names)
	{
		var found = [];
		for (var i = 0; i < defs.size(); i++)
		{
			if (defs[i].find(prefix) == 0)
			{
				found.add(defs[i]);
			}
		}
		var ok = found.size() == names.size();
		for (var i = 0; ok && i < names.size(); i++)
		{
			ok = found[i].find(names[i]) != null;
		}
		if (!ok)
		{
			errs.add(label + ": expected " + names.size() + " \"" + prefix + "\" defect(s) " + names + ", got " + defs);
		}
	}

	static function sameBox(errs, label, actual, x0, y0, x1, y1)
	{
		var want = [x0, y0, x1, y1];
		for (var i = 0; i < 4; i++)
		{
			if ((actual[i] - want[i]).abs() > 0.01)
			{
				errs.add(label + ": expected " + fmtBox(want) + ", got " + fmtBox(actual));
				return;
			}
		}
	}

	static function finish(errs, logger)
	{
		reset();
		for (var i = 0; i < errs.size(); i++)
		{
			logger.error(errs[i]);
		}
		return errs.size() == 0;
	}
}

// ---------------------------------------------------------------------------
// Bench self-tests (B01-B04)
// ---------------------------------------------------------------------------

// B01: text box of each justification, measured with the real font; logs
// the metrics of every font the pages use (one line per device).
(:test, :layouttest, :typecheck(false))
function testBenchSelfTextBoxes(logger)
{
	LayoutBench.reset();
	var errs = [];
	var dc = LayoutBench.newDc();
	var d = dc.getTextDimensions("ABC", Graphics.FONT_XTINY);
	var l = d[0].toFloat();
	var h = d[1].toFloat();
	if (l <= 0 || h <= 0)
	{
		errs.add("measure: \"ABC\" in FONT_XTINY gives " + l + " x " + h);
	}
	var C = Graphics.TEXT_JUSTIFY_CENTER;
	var L = Graphics.TEXT_JUSTIFY_LEFT;
	var R = Graphics.TEXT_JUSTIFY_RIGHT;
	var V = Graphics.TEXT_JUSTIFY_VCENTER;
	dc.drawText(100, 50, Graphics.FONT_XTINY, "ABC", C | V);
	dc.drawText(100, 50, Graphics.FONT_XTINY, "ABC", C);
	dc.drawText(100, 50, Graphics.FONT_XTINY, "ABC", L | V);
	dc.drawText(100, 50, Graphics.FONT_XTINY, "ABC", L);
	dc.drawText(100, 50, Graphics.FONT_XTINY, "ABC", R | V);
	dc.drawText(100, 50, Graphics.FONT_XTINY, "ABC", R);
	var t = dc.texts;
	if (t.size() != 6 || t[0][5] != d[0] || t[0][6] != d[1])
	{
		errs.add("drawText must record the real dimensions " + d);
	}
	else
	{
		LayoutBench.sameBox(errs, "CENTER|VCENTER", LayoutBench.box(t[0]), 100 - l / 2, 50 - h / 2, 100 + l / 2, 50 + h / 2);
		LayoutBench.sameBox(errs, "CENTER", LayoutBench.box(t[1]), 100 - l / 2, 50, 100 + l / 2, 50 + h);
		LayoutBench.sameBox(errs, "LEFT|VCENTER", LayoutBench.box(t[2]), 100, 50 - h / 2, 100 + l, 50 + h / 2);
		LayoutBench.sameBox(errs, "LEFT", LayoutBench.box(t[3]), 100, 50, 100 + l, 50 + h);
		LayoutBench.sameBox(errs, "RIGHT|VCENTER", LayoutBench.box(t[4]), 100 - l, 50 - h / 2, 100, 50 + h / 2);
		LayoutBench.sameBox(errs, "RIGHT", LayoutBench.box(t[5]), 100 - l, 50, 100, 50 + h);
		// Ink box: floor(k x h) off the top and the bottom, 1 px off each side.
		var m = (LAYOUT_INK_K * d[1]).toNumber();
		LayoutBench.sameBox(errs, "ink LEFT", LayoutBench.inkBox(t[3], LAYOUT_INK_K), 101, 50 + m, 99 + l, 50 + h - m);
	}

	var fonts = [Graphics.FONT_XTINY, Graphics.FONT_TINY, Graphics.FONT_SMALL, Graphics.FONT_MEDIUM, Graphics.FONT_LARGE,
		Graphics.FONT_NUMBER_MILD, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_HOT];
	var names = ["XTINY", "TINY", "SMALL", "MEDIUM", "LARGE", "NUMBER_MILD", "NUMBER_MEDIUM", "NUMBER_HOT"];
	var line = "fonts (height/ascent/descent):";
	for (var i = 0; i < fonts.size(); i++)
	{
		line += " " + names[i] + " " + dc.getFontHeight(fonts[i]) + "/" + Graphics.getFontAscent(fonts[i]) + "/" + Graphics.getFontDescent(fonts[i]);
	}
	logger.debug(line);
	return LayoutBench.finish(errs, logger);
}

// B02: overlap rule on ink boxes: 1 px of overlap is a defect, touching is not.
(:test, :layouttest, :typecheck(false))
function testBenchSelfOverlapRule(logger)
{
	LayoutBench.reset();
	var errs = [];
	var L = Graphics.TEXT_JUSTIFY_LEFT;
	// Height 1: no vertical ink margin for any k < 1. Ink = box less 1 px on each side.
	var a = LayoutBench.entry("a", 0, 10, L, 12, 1);       // ink x 1..11
	var b = LayoutBench.entry("b", 9, 10, L, 12, 1);       // ink x 10..20: 1 px over a
	var c = LayoutBench.entry("c", 10, 10, L, 12, 1);      // ink x 11..21: touches a
	var unit = LayoutBench.entry("u", 12, 10, L, 12, 1);   // box starts where a's ends (value + unit)
	var below = LayoutBench.entry("v", 0, 11, L, 12, 1);   // box y 11..12, a's 10..11: touch
	var n = LayoutBench.findDefects([a, b], 200, 200, false, null, LAYOUT_INK_K).size();
	if (n != 1) { errs.add("1 px overlap: expected 1 defect, got " + n); }
	n = LayoutBench.findDefects([a, c], 200, 200, false, null, LAYOUT_INK_K).size();
	if (n != 0) { errs.add("ink boxes touching: expected 0 defect, got " + n); }
	n = LayoutBench.findDefects([a, unit], 200, 200, false, null, LAYOUT_INK_K).size();
	if (n != 0) { errs.add("text boxes touching (x1 = x0'): expected 0 defect, got " + n); }
	n = LayoutBench.findDefects([a, below], 200, 200, false, null, LAYOUT_INK_K).size();
	if (n != 0) { errs.add("stacked, touching: expected 0 defect, got " + n); }
	if (!LayoutBench.overlaps([0, 0, 10, 10], [9, 9, 20, 20])) { errs.add("overlaps(): 1 x 1 px shared must be true"); }
	if (LayoutBench.overlaps([0, 0, 10, 10], [10, 0, 20, 10])) { errs.add("overlaps(): x1 = x0' must be false"); }
	if (LayoutBench.overlaps([0, 0, 10, 10], [0, 10, 10, 20])) { errs.add("overlaps(): y1 = y0' must be false"); }
	return LayoutBench.finish(errs, logger);
}

// B03: screen shape rule, both kinds, whatever the device; logs the device's.
(:test, :layouttest, :typecheck(false))
function testBenchSelfScreenShapeRule(logger)
{
	LayoutBench.reset();
	var errs = [];
	var s = System.getDeviceSettings();
	var w = s.screenWidth;
	var h = s.screenHeight;
	logger.debug("screen " + w + "x" + h + ", screenShape " + s.screenShape + " (" + LayoutBench.shapeName(s.screenShape) + ")");
	if (!LayoutBench.onScreen([w / 2.0 - 1, 1, w / 2.0 + 1, 3], w, h, true)) { errs.add("round: 2 x 2 box centred on (w/2, 2) must be inside"); }
	if (LayoutBench.onScreen([0, 0, 2, 2], w, h, true)) { errs.add("round: box at (0, 0) must be outside"); }
	if (!LayoutBench.onScreen([0, 0, 2, 2], w, h, false)) { errs.add("rectangle: (0, 0)-(2, 2) must be inside"); }
	if (LayoutBench.onScreen([-1, 0, 2, 2], w, h, false)) { errs.add("rectangle: x0 = -1 must be outside"); }
	if (LayoutBench.onScreen([0, 0, w + 1, 2], w, h, false)) { errs.add("rectangle: x1 = w + 1 must be outside"); }
	// The round rule tolerates 1 px: a corner exactly on radius w/2 + 1 is in.
	if (!LayoutBench.onScreen([w / 2.0, -1, w / 2.0, -1], w, w, true)) { errs.add("round: (w/2, -1) is on the w/2 + 1 circle, must be inside"); }
	if (LayoutBench.onScreen([w / 2.0, -2, w / 2.0, -2], w, w, true)) { errs.add("round: (w/2, -2) must be outside"); }

	// The OFFSCREEN line of findDefects() itself (k = 0: ink = box less 1 px
	// on each side only). Rectangle 176 x 176, round 200 x 200.
	var L = Graphics.TEXT_JUSTIFY_LEFT;
	var left = LayoutBench.entry("left", -2, 50, L, 20, 10);       // ink x -1..17
	var edge = LayoutBench.entry("edge", -1, 50, L, 20, 10);       // ink x 0..18: on the edge, in
	var bottom = LayoutBench.entry("bottom", 50, 170, L, 20, 10);  // ink y 170..180 > 176
	var corner = LayoutBench.entry("corner", 0, 0, L, 20, 10);     // round: corner (1, 0) out
	var middle = LayoutBench.entry("middle", 90, 95, L, 20, 10);   // round: centred, in
	var defs = LayoutBench.findDefects([left, edge, bottom, middle], 176, 176, false, null, 0.0);
	LayoutBench.expectDefects(errs, "rectangle", defs, "OFFSCREEN ", ["\"left\"", "\"bottom\""]);
	defs = LayoutBench.findDefects([corner, middle], 200, 200, true, null, 0.0);
	LayoutBench.expectDefects(errs, "round", defs, "OFFSCREEN ", ["\"corner\""]);
	return LayoutBench.finish(errs, logger);
}

// B04: the sub-window: WatchUi.getSubscreen() against the plan's table
// (section 2.2). Instinct G11-G13 must match; other round screens give
// null, except perhaps 390 / 416 px (instinct3amoled, value logged).
(:test, :layouttest, :typecheck(false))
function testBenchSelfSubscreenSource(logger)
{
	LayoutBench.reset();
	var errs = [];
	var s = System.getDeviceSettings();
	var w = s.screenWidth;
	var h = s.screenHeight;
	var round = LayoutBench.isRound();
	var api = LayoutBench.apiSubscreen();
	var table = LayoutBench.tableSubscreen(w, h, round);
	logger.debug("getSubscreen available: " + (WatchUi has :getSubscreen) + ", value " + api + ", table " + table + " (" + w + "x" + h + ")");
	if (table != null)
	{
		if (api == null)
		{
			errs.add("getSubscreen() gives null, the table gives " + table + ": the checks use the table");
		}
		else
		{
			for (var i = 0; i < 4; i++)
			{
				if (api[i] != table[i])
				{
					errs.add("getSubscreen() " + api + " differs from the table " + table);
					break;
				}
			}
		}
	}
	else if (api != null && !(round && (w == 390 || w == 416)))
	{
		errs.add("unexpected sub-window " + api + " on a " + w + "x" + h + " screen");
	}

	// The SUBSCREEN line of findDefects(), on the instinct2 sub-window given
	// as [x, y, width, height] = [113, 0, 62, 62]: a disk of centre (144, 31),
	// radius 31, in the square (113, 0)-(175, 62). k = 0: ink = box less 1 px
	// on each side. A [x, y, w, h] box read as [x0, y0, x1, y1] would be empty
	// (x1 = 62 < x0 = 113) and miss "in disk": that mistake makes this red.
	var sub = [113, 0, 62, 62];
	var L = Graphics.TEXT_JUSTIFY_LEFT;
	var inDisk = LayoutBench.entry("in disk", 139, 20, L, 12, 10);      // ink (140,20)-(150,30)
	var touchX = LayoutBench.entry("touch x1", 100, 20, L, 14, 10);     // ink x1 = 113
	var touchY = LayoutBench.entry("touch y0", 139, 62, L, 12, 10);     // ink y0 = 62
	var inCorner = LayoutBench.entry("in corner", 113, 56, L, 6, 5);    // ink (114,56)-(118,61): square, not disk
	var defs = LayoutBench.findDefects([inDisk], 176, 176, false, sub, 0.0);
	LayoutBench.expectDefects(errs, "inside the disk", defs, "SUBSCREEN disk ", ["\"in disk\""]);
	defs = LayoutBench.findDefects([touchX, touchY], 176, 176, false, sub, 0.0);
	LayoutBench.expectDefects(errs, "touching the edges", defs, "SUBSCREEN", []);
	defs = LayoutBench.findDefects([inCorner], 176, 176, false, sub, 0.0);
	LayoutBench.expectDefects(errs, "corner of the square only", defs, "SUBSCREEN corner ", ["\"in corner\""]);
	LayoutBench.expectDefects(errs, "corner is not disk", defs, "SUBSCREEN disk ", []);
	defs = LayoutBench.findDefects([inDisk, inCorner], 176, 176, false, null, 0.0);
	LayoutBench.expectDefects(errs, "no sub-window", defs, "SUBSCREEN", []);
	return LayoutBench.finish(errs, logger);
}

// ---------------------------------------------------------------------------
// Layout tests: testLayout_<View>_<State> (35)
// ---------------------------------------------------------------------------

(:test, :layouttest, :typecheck(false))
function testLayout_HikePosition_Empty(logger) { return LayoutBench.run(logger, "HikePosition", "Empty"); }
(:test, :layouttest, :typecheck(false))
function testLayout_HikePosition_Normal(logger) { return LayoutBench.run(logger, "HikePosition", "Normal"); }
(:test, :layouttest, :typecheck(false))
function testLayout_HikePosition_Extreme(logger) { return LayoutBench.run(logger, "HikePosition", "Extreme"); }
(:test, :layouttest, :typecheck(false))
function testLayout_HikePosition_Paused(logger) { return LayoutBench.run(logger, "HikePosition", "Paused"); }
(:test, :layouttest, :typecheck(false))
function testLayout_HikePosition_Recording(logger) { return LayoutBench.run(logger, "HikePosition", "Recording"); }

(:test, :layouttest, :typecheck(false))
function testLayout_HikePace_Empty(logger) { return LayoutBench.run(logger, "HikePace", "Empty"); }
(:test, :layouttest, :typecheck(false))
function testLayout_HikePace_Normal(logger) { return LayoutBench.run(logger, "HikePace", "Normal"); }
(:test, :layouttest, :typecheck(false))
function testLayout_HikePace_Extreme(logger) { return LayoutBench.run(logger, "HikePace", "Extreme"); }
(:test, :layouttest, :typecheck(false))
function testLayout_HikePace_Paused(logger) { return LayoutBench.run(logger, "HikePace", "Paused"); }
(:test, :layouttest, :typecheck(false))
function testLayout_HikePace_Recording(logger) { return LayoutBench.run(logger, "HikePace", "Recording"); }

(:test, :layouttest, :typecheck(false))
function testLayout_HikeMap_Empty(logger) { return LayoutBench.run(logger, "HikeMap", "Empty"); }
(:test, :layouttest, :typecheck(false))
function testLayout_HikeMap_Normal(logger) { return LayoutBench.run(logger, "HikeMap", "Normal"); }
(:test, :layouttest, :typecheck(false))
function testLayout_HikeMap_Extreme(logger) { return LayoutBench.run(logger, "HikeMap", "Extreme"); }
(:test, :layouttest, :typecheck(false))
function testLayout_HikeMap_Paused(logger) { return LayoutBench.run(logger, "HikeMap", "Paused"); }
(:test, :layouttest, :typecheck(false))
function testLayout_HikeMap_Recording(logger) { return LayoutBench.run(logger, "HikeMap", "Recording"); }

(:test, :layouttest, :typecheck(false))
function testLayout_Time_Empty(logger) { return LayoutBench.run(logger, "Time", "Empty"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Time_Normal(logger) { return LayoutBench.run(logger, "Time", "Normal"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Time_Extreme(logger) { return LayoutBench.run(logger, "Time", "Extreme"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Time_Paused(logger) { return LayoutBench.run(logger, "Time", "Paused"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Time_Recording(logger) { return LayoutBench.run(logger, "Time", "Recording"); }

(:test, :layouttest, :typecheck(false))
function testLayout_Fly_Empty(logger) { return LayoutBench.run(logger, "Fly", "Empty"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Fly_Normal(logger) { return LayoutBench.run(logger, "Fly", "Normal"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Fly_Extreme(logger) { return LayoutBench.run(logger, "Fly", "Extreme"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Fly_Paused(logger) { return LayoutBench.run(logger, "Fly", "Paused"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Fly_Recording(logger) { return LayoutBench.run(logger, "Fly", "Recording"); }

(:test, :layouttest, :typecheck(false))
function testLayout_Compass_Empty(logger) { return LayoutBench.run(logger, "Compass", "Empty"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Compass_Normal(logger) { return LayoutBench.run(logger, "Compass", "Normal"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Compass_Extreme(logger) { return LayoutBench.run(logger, "Compass", "Extreme"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Compass_Paused(logger) { return LayoutBench.run(logger, "Compass", "Paused"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Compass_Recording(logger) { return LayoutBench.run(logger, "Compass", "Recording"); }

(:test, :layouttest, :typecheck(false))
function testLayout_Paused_Empty(logger) { return LayoutBench.run(logger, "Paused", "Empty"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Paused_Normal(logger) { return LayoutBench.run(logger, "Paused", "Normal"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Paused_Extreme(logger) { return LayoutBench.run(logger, "Paused", "Extreme"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Paused_Paused(logger) { return LayoutBench.run(logger, "Paused", "Paused"); }
(:test, :layouttest, :typecheck(false))
function testLayout_Paused_Recording(logger) { return LayoutBench.run(logger, "Paused", "Recording"); }

} // module LayoutBenchTests
