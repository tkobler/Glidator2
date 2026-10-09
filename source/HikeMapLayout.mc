// --------------------------------------------------------------------------------
// Layout of WatchDisplay.map() (hike Map page), pure functions of the screen
// height and the font metrics, unit tested in TestsHikeMap.mc without a Dc.
// --------------------------------------------------------------------------------
module HikeMapLayout
{
    // Offset of the two "Waiting for" / "GPS" lines above and below the
    // screen centre, tuned on fenix6pro.
    const LINE_OFFSET = 15;

    // Centres [y1, y2] of the two "Waiting for" / "GPS" lines. Stub.
    function waitingLinesY(h, fontHeight)
    {
        return null;
    }

    // True if two lines of a th px high font centred on y1 < y2 overlap. Stub.
    function inksOverlap(y1, y2, th)
    {
        return false;
    }
}
