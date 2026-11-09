// Hiking page list. One module = one global member (the old watches have a
// small limit on globals).
module HikePages
{
	// The Map page (HikeMapView) is hidden in the next published version.
	// The map code and its tests stay compiled: set this to true to bring
	// the 4th page back.
	const MAP_ENABLED = false;

	// The hiking pages in display order: the base pages, then the map page
	// when it is enabled and its view exists.
	function list(basePages, mapPage, mapEnabled)
	{
		var pages = [];
		for (var i = 0; i < basePages.size(); i++)
		{
			pages.add(basePages[i]);
		}
		if (mapEnabled == true && mapPage != null)
		{
			pages.add(mapPage);
		}
		return pages;
	}

	// Index reached from `index` by `delta` (+1 DOWN, -1 UP) in a list of
	// `size` pages, wrapping around. 0 for an empty list.
	function step(index, delta, size)
	{
		if (size <= 0)
		{
			return 0;
		}
		return (index + delta + size) % size;
	}
}
