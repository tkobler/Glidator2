// --------------------------------------------------------------------------------
// Small shared formatting helpers, usable from any view without owning a Dc.
// --------------------------------------------------------------------------------

// Formats a duration in milliseconds as "mm:ss", or "h:mm:ss" once it reaches an hour.
// "--:--" when null or negative (a timer never runs backwards; -0.0 is zero).
function formatDuration(ms)
{
	if (ms == null || ms < 0)
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

// Formats a distance in meters as km with one decimal for the Position page.
// "--" when null, NaN, +-Infinity or negative (an elapsed distance never is).
// Zero, -0.0 included, reads "0.0" (format() would print "-0.0").
function formatDistanceKm(meters)
{
	if (meters == null)
	{
		return "--";
	}
	var v = meters.toFloat();
	if (!isFiniteFloat(v) || v < 0.0)
	{
		return "--";
	}
	if (v == 0.0)
	{
		return "0.0";
	}
	return (v / 1000.0).format("%.1f");
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

// What WatchDisplay.map() draws, from the number of trail points and whether
// a current position is known (usable fix):
//   :trailAndMarker  current position known (the trail may be empty),
//   :trailOnly       no current position but a trail exists (fix lost),
//   :waiting         neither: "Waiting for GPS".
// A null or negative count counts as 0; hasCurrent must be exactly true.
function mapDrawMode(count, hasCurrent)
{
	if (hasCurrent == true)
	{
		return :trailAndMarker;
	}
	if (count != null && count > 0)
	{
		return :trailOnly;
	}
	return :waiting;
}

// True for a usable Float: not NaN, not +-Infinity (Inf - Inf is NaN; any
// finite v - v is 0).
function isFiniteFloat(v)
{
	return v == v && v - v == 0.0;
}

// Meters in one degree of latitude (and, once map() has multiplied
// longitudes by cos(lat), in one projected degree of longitude too).
const METERS_PER_DEGREE = 111320.0;

// Converts map()'s scale, in pixels per degree of latitude, to meters per
// pixel. null when the scale is null, zero, negative, NaN or infinite.
function metersPerPixelFromScale(pixelsPerDegree)
{
	if (pixelsPerDegree == null)
	{
		return null;
	}
	var p = pixelsPerDegree.toFloat();
	if (!isFiniteFloat(p) || p <= 0.0)
	{
		return null;
	}
	return METERS_PER_DEGREE / p;
}

// Round scale bar lengths, longest first.
const SCALE_BAR_LENGTHS_M = [5000, 2000, 1000, 500, 200, 100, 50];

// Picks the map scale bar: the longest round length (50/100/200/500 m,
// 1/2/5 km) that fits in maxPixels at metersPerPixel, as [meters, pixels]
// with pixels rounded to a whole Number. A length exactly as long as the
// room fits. null (no bar) when:
//   - even 50 m is longer than maxPixels (zoomed in, e.g. a short trail),
//   - the chosen bar is shorter than a quarter of maxPixels (only possible
//     with 5 km: consecutive lengths differ by 2.5x at most), too short to read,
//   - an input is null, zero, negative, NaN or infinite.
function pickScaleBar(metersPerPixel, maxPixels)
{
	if (metersPerPixel == null || maxPixels == null)
	{
		return null;
	}
	var mpp = metersPerPixel.toFloat();
	var room = maxPixels.toFloat();
	if (!isFiniteFloat(mpp) || mpp <= 0.0 || !isFiniteFloat(room) || room <= 0.0)
	{
		return null;
	}

	for (var i = 0; i < SCALE_BAR_LENGTHS_M.size(); i++)
	{
		var meters = SCALE_BAR_LENGTHS_M[i];
		var pixels = meters / mpp;
		if (pixels <= room)
		{
			if (pixels < room / 4.0)
			{
				return null;
			}
			return [meters, (pixels + 0.5).toNumber()];
		}
	}
	return null;
}

// Scale bar label: "50 m" ... "500 m", then "1 km", "2 km", "5 km"
// ("1.5 km" for a length that is not a whole km). Empty for null, zero,
// negative, NaN or infinite.
function formatScaleBarLabel(meters)
{
	if (meters == null)
	{
		return "";
	}
	var v = meters.toFloat();
	if (!isFiniteFloat(v) || v <= 0.0)
	{
		return "";
	}
	var m = (v + 0.5).toLong();
	if (m < 1000)
	{
		return m.toString() + " m";
	}
	if (m % 1000 == 0)
	{
		return (m / 1000).toString() + " km";
	}
	return (m / 1000.0).format("%.1f") + " km";
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
