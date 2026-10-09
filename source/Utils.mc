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

// Altitude range shown by the hike pages (decision of 2026-10-06). The
// flight page (FlyInstrumentView) does not use it.
const HIKE_ALTITUDE_MIN_M = -100.0;
const HIKE_ALTITUDE_MAX_M = 6000.0;

// Formats an altitude in meters for the hike Position page, rounded to the
// meter as before (Math.round). "--" when null, NaN, +-Infinity or outside
// HIKE_ALTITUDE_MIN_M..HIKE_ALTITUDE_MAX_M (bounds included). The range is
// checked on the raw value, before rounding: 6000.4 reads "--", not "6000".
function formatHikeAltitude(alt)
{
	if (alt == null)
	{
		return "--";
	}
	var v = alt.toFloat();
	if (!isFiniteFloat(v) || v < HIKE_ALTITUDE_MIN_M || v > HIKE_ALTITUDE_MAX_M)
	{
		return "--";
	}
	return Toybox.Math.round(v).toNumber().toString();
}

// Largest elevation gain shown by the hike Position page, in meters, bound
// included (decision of 07/10, Position ascent guard). Far above any real
// day out (Salvan climb: 908 m); a larger Activity totalAscent is a glitch.
const HIKE_ASCENT_MAX_M = 20000.0d;

// Formats the elevation gain (Activity totalAscent) in meters for the hike
// Position page, rounded to the meter (halves up) like the altitude. "--"
// when null, NaN, +-Infinity, negative or above HIKE_ASCENT_MAX_M. The range
// is checked on the raw value, in Double so that a Double or Long input is
// not rounded first: 20000.4 reads "--", not "20000", and -0.1 reads "--".
// -0.0 is a zero and reads "0".
function formatHikeAscent(ascent)
{
	if (ascent == null)
	{
		return "--";
	}
	var v = ascent.toDouble();
	if (!isFiniteFloat(v) || v < 0.0d || v > HIKE_ASCENT_MAX_M)
	{
		return "--";
	}
	return (v + 0.5d).toNumber().toString(); // v in 0..20000: no overflow, -0.0 -> 0
}

// Heart rate range shown by the hike pages (decision of 2026-10-06).
const HEART_RATE_MIN_BPM = 25.0;
const HEART_RATE_MAX_BPM = 250.0;

// Formats a heart rate for the hike Pace page: "--" when null, NaN,
// +-Infinity or outside HEART_RATE_MIN_BPM..HEART_RATE_MAX_BPM (bounds
// included, checked on the raw value); otherwise the whole bpm (a Float is
// rounded). Only a display bound: WatchData.getHeartRate() keeps its source
// priority, so an out of range Activity value reads "--" even with a valid
// sensor value.
function formatHeartRate(bpm)
{
	if (bpm == null)
	{
		return "--";
	}
	var v = bpm.toFloat();
	if (!isFiniteFloat(v) || v < HEART_RATE_MIN_BPM || v > HEART_RATE_MAX_BPM)
	{
		return "--";
	}
	return Toybox.Math.round(v).toNumber().toString();
}

// Rotation, in radians, of the compass dial (WatchDisplay.compass()) for a
// heading in radians: the heading negated, so that the dial turns
// counter-clockwise when the watch turns clockwise. 0.0 (no rotation) when
// the heading is null (Position.Info.heading can be), NaN or +-Infinity.
function compassRotation(heading)
{
	if (heading == null)
	{
		return 0.0;
	}
	var v = heading.toFloat();
	if (!isFiniteFloat(v) || v == 0.0)
	{
		return 0.0;
	}
	return -v;
}

// Formats a latitude (isLat true) or longitude in degrees as D°MM'S.S" plus
// N/S or E/W; the letter alone gives the hemisphere (no minus sign).
// The absolute value is rounded once to the nearest 0.1" (in Double, then a
// Long count of tenths) and only then split into degrees, minutes and
// seconds, so 59.96" carries into the minutes and the degrees instead of
// reading 60.0". A value that rounds to 0.0" reads N / E.
// "--" when null, NaN, +-Infinity, or beyond 90 (latitude) / 180 (longitude).
function formatLatLon(value, isLat)
{
	if (value == null)
	{
		return "--";
	}
	var v = value.toDouble();
	if (!isFiniteFloat(v))
	{
		return "--";
	}
	var negative = v < 0.0d;
	var a = negative ? -v : v;
	if (a > (isLat ? 90.0d : 180.0d))
	{
		return "--";
	}

	var tenths = (a * 36000.0d + 0.5d).toLong(); // 0.1" per unit
	var deg = (tenths / 36000).toNumber();
	var rest = (tenths % 36000).toNumber();
	var min = rest / 600;
	var sec = rest % 600;

	var letter;
	if (isLat)
	{
		letter = (negative && tenths > 0) ? "S" : "N";
	}
	else
	{
		letter = (negative && tenths > 0) ? "W" : "E";
	}
	return deg.toString() + "°" + min.format("%02d") + "'" + (sec / 10).toString() + "." + (sec % 10).toString() + "\"" + letter;
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

// Largest hike vertical speed shown by formatVerticalSpeed(), in m/h, bound
// included (decision of 07/10, VS cap). Walking or running uphill stays well under
// it (Salvan climb, 60 s window: median +636 m/h, p95 +891 m/h); anything
// faster on the Pace page is an altitude glitch or a flight phase (spiral),
// and reads "--". The flight vario (m/s) does not use this function.
// 3000.0 is exact in a 32-bit Float. The cap also keeps the Long rounding
// far from overflow.
const VERTICAL_SPEED_MAX_MH = 3000.0;

// Formats a vertical speed in m/h for the hike pages: "--" when there is no
// value (or NaN / +-Infinity, or beyond +-VERTICAL_SPEED_MAX_MH), otherwise
// rounded to the nearest 10 m/h (halves away from zero, the same way for
// climbs and descents) with a "+" only when the rounded value is positive, so
// a near-zero rate reads "0", never "+0" or "-0".
// The cap is checked on the value BEFORE rounding: 3000.4 m/h would round
// to "+3000" but is above the cap, so it reads "--".
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
	if (magnitude > VERTICAL_SPEED_MAX_MH)
	{
		return "--"; // beyond the hike cap, checked before rounding
	}
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

// Projection of WatchDisplay.map(), part 1: the center of the bounding box (in
// degrees) of the trail plus the current position, as
// [centerLat, centerLon, cosLat]. The trail is the ring buffer lats / lons
// (capacity lats.size()), its count points read oldest to newest from
// writeIndex - count; the other slots are ignored. The current position
// counts only when curLat and curLon are both set; without it the box is
// seeded with the oldest trail point. null when there is neither (a null or
// negative count counts as 0).
function mapProjectionCenter(lats, lons, count, writeIndex, curLat, curLon)
{
	var n = (count == null || count < 0) ? 0 : count;
	var hasCurrent = (curLat != null && curLon != null);
	if (!hasCurrent && n == 0)
	{
		return null;
	}

	var capacity = lats.size();
	var seedLat = curLat, seedLon = curLon;
	if (!hasCurrent)
	{
		var oldest = (writeIndex - n + capacity) % capacity;
		seedLat = lats[oldest];
		seedLon = lons[oldest];
	}
	var minLat = seedLat, maxLat = seedLat, minLon = seedLon, maxLon = seedLon;
	for (var i = 0; i < n; i++)
	{
		var idx = (writeIndex - n + i + capacity) % capacity;
		var lat = lats[idx];
		var lon = lons[idx];
		if (lat < minLat) { minLat = lat; }
		if (lat > maxLat) { maxLat = lat; }
		if (lon < minLon) { minLon = lon; }
		if (lon > maxLon) { maxLon = lon; }
	}

	var centerLat = (minLat + maxLat) / 2.0;
	var centerLon = (minLon + maxLon) / 2.0;
	return [centerLat, centerLon, Toybox.Math.cos(Toybox.Math.toRadians(centerLat))];
}

// Projection of WatchDisplay.map(), part 2: its scale in pixels per degree of
// latitude. The projection is a longitude-compressed local one
// (equirectangular): offsets from center ([centerLat, centerLon, cosLat] from
// mapProjectionCenter()) are (lon - centerLon) * cosLat and lat - centerLat,
// in degrees of latitude on both axes. The largest offset over the trail
// (same ring buffer reading as mapProjectionCenter()) and the current
// position (when curLat and curLon are both set) is fitted to 85 % of
// screenRadius, with a 0.0001 degree floor so a stationary trail does not
// divide by zero. null when center is null.
function mapPixelsPerDegree(lats, lons, count, writeIndex, curLat, curLon, center, screenRadius)
{
	if (center == null)
	{
		return null;
	}
	var n = (count == null || count < 0) ? 0 : count;
	var capacity = lats.size();
	var centerLat = center[0];
	var centerLon = center[1];
	var cosLat = center[2];

	var maxRange = 0.0001; // floor avoids a divide-by-zero when stationary
	for (var i = 0; i < n; i++)
	{
		var idx = (writeIndex - n + i + capacity) % capacity;
		var dx = (lons[idx] - centerLon) * cosLat;
		var dy = lats[idx] - centerLat;
		var r = (dx.abs() > dy.abs()) ? dx.abs() : dy.abs();
		if (r > maxRange) { maxRange = r; }
	}
	if (curLat != null && curLon != null)
	{
		var curDx = (curLon - centerLon) * cosLat;
		var curDy = curLat - centerLat;
		var curR = (curDx.abs() > curDy.abs()) ? curDx.abs() : curDy.abs();
		if (curR > maxRange) { maxRange = curR; }
	}

	return (screenRadius * 0.85) / maxRange;
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
