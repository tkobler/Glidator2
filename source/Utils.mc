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
