using Toybox.Math;

// Fixed-size ring buffer of lat/lon points for the live Map page.
// Fed once per second from FlyInstrumentApp.onSensor() regardless of which
// page is on screen, so the trail keeps growing even while the Map page
// isn't visible. Points are decimated by distance (not time) so the fixed
// buffer spans the whole hike instead of filling up in a few minutes.
class BreadcrumbTrail
{
	const MAX_POINTS = 250;
	const MIN_DISTANCE_M = 15.0;

	var lats = new [MAX_POINTS];
	var lons = new [MAX_POINTS];
	var writeIndex = 0;
	var count = 0;

	var lastLat = null;
	var lastLon = null;

	(:typecheck(false))
	// See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
	function update(lat, lon)
	{
		if (lat == null || lon == null)
		{
			return;
		}

		if (lastLat != null)
		{
			var dLat = (lat - lastLat) * 111320.0;
			var dLon = (lon - lastLon) * 111320.0 * Math.cos(Math.toRadians(lat));
			var dist = Math.sqrt(dLat * dLat + dLon * dLon);
			if (dist < MIN_DISTANCE_M)
			{
				return;
			}
		}

		lats[writeIndex] = lat;
		lons[writeIndex] = lon;
		writeIndex = (writeIndex + 1) % MAX_POINTS;
		if (count < MAX_POINTS)
		{
			count += 1;
		}

		lastLat = lat;
		lastLon = lon;
	}

	function getLats()
	{
		return lats;
	}

	function getLons()
	{
		return lons;
	}

	function getCount()
	{
		return count;
	}

	function getWriteIndex()
	{
		return writeIndex;
	}
}
