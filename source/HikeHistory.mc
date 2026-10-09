// Hike-mode history: a fixed ring buffer of (time, altitude, distance)
// samples, at most one every 5 s, so 60 samples cover about 5 minutes.
// Pure logic (timestamps are passed in, no System.getTimer() here) so that
// it can be unit tested with synthetic and recorded data.
//
// Not used by the flight vario: this is a separate, slower estimate meant for
// walking, where the barometer's 0.2 m steps make a 1 s difference useless.
class HikeHistory
{
	const MAX_SAMPLES = 60;
	const MIN_SPACING_MS = 5000;   // samples closer than this are dropped
	const MAX_GAP_MS = 15000;      // a longer gap (pause, lost data) resets
	const MIN_POINTS = 3;
	const MIN_COVERAGE_MS = 20000;

	var times = new [MAX_SAMPLES];
	var alts = new [MAX_SAMPLES];
	var dists = new [MAX_SAMPLES];
	var writeIndex = 0;
	var count = 0;
	var lastTime = null;

	function initialize()
	{
	}

	// tMs: timestamp in ms (System.getTimer() in the app).
	// alt: altitude in m; the sample is ignored if null.
	// dist: elapsed distance in m, or null (no session yet).
	function add(tMs, alt, dist)
	{
		if (tMs == null || alt == null)
		{
			return;
		}

		if (lastTime != null)
		{
			// 32-bit difference: when System.getTimer() wraps past 2^31 ms
			// (~24.8 days) the subtraction wraps too and dt stays small and
			// positive, so no reset. A negative dt therefore means time really
			// went backwards (timer restarted): treat it like a gap.
			var dt = tMs - lastTime;
			if (dt < 0 || dt > MAX_GAP_MS)
			{
				reset();
			}
			else if (dt < MIN_SPACING_MS)
			{
				return;
			}
		}

		times[writeIndex] = tMs;
		alts[writeIndex] = alt.toFloat();
		dists[writeIndex] = (dist == null) ? null : dist.toFloat();
		writeIndex = (writeIndex + 1) % MAX_SAMPLES;
		if (count < MAX_SAMPLES)
		{
			count += 1;
		}
		lastTime = tMs;
	}

	function reset()
	{
		for (var i = 0; i < MAX_SAMPLES; i++)
		{
			times[i] = null;
			alts[i] = null;
			dists[i] = null;
		}
		writeIndex = 0;
		count = 0;
		lastTime = null;
	}

	function getCount()
	{
		return count;
	}

	// True if sample i is older than the window. Compared as a difference
	// (nowMs - t > windowMs) rather than t < nowMs - windowMs: the difference
	// stays right across the 2^31 ms timer wrap, and nowMs - windowMs could
	// itself overflow.
	hidden function outOfWindow(i, nowMs, windowMs)
	{
		return nowMs - times[i] > windowMs;
	}

	// Vertical speed in m/h: least-squares slope of altitude against time over
	// the samples with nowMs - t <= windowMs. Times are taken relative to nowMs
	// and both axes are centred on their means, because Float is 32-bit.
	// Returns null with fewer than 3 samples or less than 20 s covered.
	function verticalSpeedMh(nowMs, windowMs)
	{
		if (nowMs == null || windowMs == null)
		{
			return null;
		}
		var oldest = (writeIndex - count + MAX_SAMPLES) % MAX_SAMPLES;

		// First pass: means, and the time span covered.
		var n = 0;
		var sumT = 0.0;
		var sumA = 0.0;
		var altRef = null;
		var firstTime = null;
		var lastT = null;
		for (var k = 0; k < count; k++)
		{
			var i = (oldest + k) % MAX_SAMPLES;
			if (outOfWindow(i, nowMs, windowMs))
			{
				continue;
			}
			if (altRef == null)
			{
				altRef = alts[i];
				firstTime = times[i];
			}
			lastT = times[i];
			sumT += (times[i] - nowMs) / 1000.0;
			sumA += alts[i] - altRef;
			n += 1;
		}
		if (n < MIN_POINTS || lastT - firstTime < MIN_COVERAGE_MS)
		{
			return null;
		}
		var meanT = sumT / n;
		var meanA = sumA / n;

		// Second pass: centred covariance and variance.
		var sxy = 0.0;
		var sxx = 0.0;
		for (var k = 0; k < count; k++)
		{
			var i = (oldest + k) % MAX_SAMPLES;
			if (outOfWindow(i, nowMs, windowMs))
			{
				continue;
			}
			// Integer difference first (wrap-safe), then to seconds.
			var dt =(times[i] - nowMs) / 1000.0 - meanT;
			var da = (alts[i] - altRef) - meanA;
			sxy += dt * da;
			sxx += dt * dt;
		}
		if (sxx <= 0.0)
		{
			return null;
		}
		return sxy / sxx * 3600.0;
	}

	// Horizontal speed in m/s: (last distance - first distance) / elapsed time
	// over the samples in the window that carry a distance. Same null rules as
	// verticalSpeedMh(), counted on those samples only. Also null if the
	// distance went down over the window (a new session restarted
	// elapsedDistance): better no speed than a negative one.
	function speedMps(nowMs, windowMs)
	{
		if (nowMs == null || windowMs == null)
		{
			return null;
		}
		var oldest = (writeIndex - count + MAX_SAMPLES) % MAX_SAMPLES;

		var n = 0;
		var firstTime = null;
		var firstDist = null;
		var lastT = null;
		var lastDist = null;
		for (var k = 0; k < count; k++)
		{
			var i = (oldest + k) % MAX_SAMPLES;
			if (dists[i] == null || outOfWindow(i, nowMs, windowMs))
			{
				continue;
			}
			if (firstTime == null)
			{
				firstTime = times[i];
				firstDist = dists[i];
			}
			lastT = times[i];
			lastDist = dists[i];
			n += 1;
		}
		if (n < MIN_POINTS || lastT - firstTime < MIN_COVERAGE_MS || lastDist < firstDist)
		{
			return null;
		}
		return (lastDist - firstDist) / ((lastT - firstTime) / 1000.0);
	}
}
