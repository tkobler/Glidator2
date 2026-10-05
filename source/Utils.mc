// --------------------------------------------------------------------------------
// Small shared formatting helpers, usable from any view without owning a Dc.
// --------------------------------------------------------------------------------

// Formats a duration in milliseconds as "mm:ss", or "h:mm:ss" once it reaches an hour.
function formatDuration(ms)
{
	if (ms == null)
	{
		return "--:--";
	}

	var totalSeconds = (ms / 1000).toNumber();
	var hours = totalSeconds / 3600;
	var minutes = (totalSeconds % 3600) / 60;
	var seconds = totalSeconds % 60;

	if (hours > 0)
	{
		return hours.toString() + ":" + minutes.format("%02d") + ":" + seconds.format("%02d");
	}

	return minutes.format("%02d") + ":" + seconds.format("%02d");
}

// Formats a vertical speed in m/h for the hike pages: "--" when there is no
// value (or NaN / +-Infinity), otherwise rounded to the nearest 10 m/h (halves away from
// zero, the same way for climbs and descents) with a "+" only when the rounded
// value is positive, so a near-zero rate reads "0", never "+0" or "-0".
// Rounding is done on the absolute value with toLong() so that a glitch-sized
// value cannot overflow a 32-bit Number.
function formatVerticalSpeed(mh)
{
	if (mh == null)
	{
		return "--";
	}
	var v = mh.toFloat();
	if (v != v)
	{
		return "--"; // NaN
	}
	if (v - v != 0.0)
	{
		return "--"; // +/-Infinity (Inf - Inf is NaN; any finite v - v is 0)
	}

	var negative = v < 0.0;
	var magnitude = negative ? -v : v;
	var tens = (magnitude / 10.0 + 0.5).toLong();
	if (tens == 0)
	{
		return "0";
	}
	return (negative ? "-" : "+") + (tens * 10).toString();
}

// Formats a speed in m/s as a pace "m:ss" per km for the hike pages.
// The total pace in seconds is rounded first and only then split into
// minutes and seconds, so 359.6 s/km reads "6:00", never "5:60".
// "--:--" when there is no usable speed: null, NaN, +-Infinity, zero or
// negative, a pace slower than 60:00 /km (60:00 itself is shown: the check is
// on the rounded total, which Float noise around 3600 s cannot flip), or a
// pace that rounds to 0 s (speed > 2000 m/s, a glitch).
// The 60:00 check runs on the Float pace before any toNumber(), so a tiny
// speed (huge pace) cannot overflow a 32-bit Number.
function formatPace(speedMps)
{
	if (speedMps == null)
	{
		return "--:--";
	}
	var v = speedMps.toFloat();
	if (v != v || v <= 0.0)
	{
		return "--:--"; // NaN, zero, negative, -Infinity
	}

	var paceSeconds = 1000.0 / v; // +Infinity speed -> 0.0, caught below
	if (paceSeconds >= 3600.5)
	{
		return "--:--"; // rounds to more than 60:00 /km
	}
	var total = (paceSeconds + 0.5).toNumber();
	if (total <= 0)
	{
		return "--:--";
	}
	return (total / 60).toString() + ":" + (total % 60).format("%02d");
}
