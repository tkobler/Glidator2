using Toybox.Test;

// Tests of the hiking page list (HikePages module): the Map page can be hidden
// with HikePages.MAP_ENABLED, and the UP/DOWN navigation wraps around whatever
// number of pages remains. Views are replaced by plain strings: the logic only
// handles the list.
(:test)
module HikePageTests
{

(:test)
function testHikePagesMapDisabledHasThreePages(logger)
{
	var pages = HikePages.list(["position", "pace", "time"], "map", false);
	Test.assertEqualMessage(pages.size(), 3, "3 hiking pages with the map hidden");
	Test.assertEqualMessage(pages[0], "position", "first page is Position");
	Test.assertEqualMessage(pages[1], "pace", "second page is Pace");
	Test.assertEqualMessage(pages[2], "time", "third page is Time");
	return true;
}

(:test)
function testHikePagesMapEnabledHasFourPages(logger)
{
	var pages = HikePages.list(["position", "pace", "time"], "map", true);
	Test.assertEqualMessage(pages.size(), 4, "4 hiking pages with the map shown");
	Test.assertEqualMessage(pages[3], "map", "the map is the last page");
	return true;
}

(:test)
function testHikePagesMapDisabledNoMapViewNeeded(logger)
{
	// The app does not even build the map view when it is hidden.
	var pages = HikePages.list(["position", "pace", "time"], null, false);
	Test.assertEqualMessage(pages.size(), 3, "null map view, map hidden: 3 pages");
	return true;
}

(:test)
function testHikePagesEnabledWithoutMapViewIgnored(logger)
{
	// No null entry may ever land in the list.
	var pages = HikePages.list(["position", "pace", "time"], null, true);
	Test.assertEqualMessage(pages.size(), 3, "map enabled but no view: no null page");
	return true;
}

(:test)
function testHikePagesConstantDrivesList(logger)
{
	// Whatever the constant, the list built from it has 3 pages (false) or 4 (true).
	var pages = HikePages.list(["position", "pace", "time"], "map", HikePages.MAP_ENABLED);
	Test.assertEqualMessage(pages.size(), HikePages.MAP_ENABLED ? 4 : 3, "page count follows the constant");
	return true;
}

(:test)
function testHikePagesNavigationThreePages(logger)
{
	// DOWN from 0 -> 1 -> 2 -> 0, UP from 0 -> 2 -> 1 -> 0.
	Test.assertEqualMessage(HikePages.step(0, 1, 3), 1, "down from Position");
	Test.assertEqualMessage(HikePages.step(1, 1, 3), 2, "down from Pace");
	Test.assertEqualMessage(HikePages.step(2, 1, 3), 0, "down from Time wraps to Position");
	Test.assertEqualMessage(HikePages.step(0, -1, 3), 2, "up from Position wraps to Time");
	Test.assertEqualMessage(HikePages.step(2, -1, 3), 1, "up from Time");
	Test.assertEqualMessage(HikePages.step(1, -1, 3), 0, "up from Pace");
	return true;
}

(:test)
function testHikePagesNavigationFourPages(logger)
{
	Test.assertEqualMessage(HikePages.step(3, 1, 4), 0, "down from Map wraps to Position");
	Test.assertEqualMessage(HikePages.step(0, -1, 4), 3, "up from Position wraps to Map");
	return true;
}

(:test)
function testHikePagesNavigationEdgeCases(logger)
{
	Test.assertEqualMessage(HikePages.step(0, 1, 1), 0, "single page stays on itself");
	Test.assertEqualMessage(HikePages.step(0, -1, 1), 0, "single page, up");
	Test.assertEqualMessage(HikePages.step(0, 1, 0), 0, "empty list falls back to 0");
	return true;
}

}
