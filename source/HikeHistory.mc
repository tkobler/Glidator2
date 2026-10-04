// Hike mode history: fixed ring buffer of (time, altitude, distance) samples.
// Skeleton only -- implementation follows once the tests are in place.
class HikeHistory
{
	const MAX_SAMPLES = 60;

	function initialize()
	{
	}

	function add(tMs, alt, dist)
	{
	}

	function reset()
	{
	}

	function getCount()
	{
		return 0;
	}

	function verticalSpeedMh(nowMs, windowMs)
	{
		return null;
	}

	function speedMps(nowMs, windowMs)
	{
		return null;
	}
}
