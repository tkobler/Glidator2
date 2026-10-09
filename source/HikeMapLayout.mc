// --------------------------------------------------------------------------------
// Layout of WatchDisplay.map() (hike Map page), pure functions of the screen
// height and the font metrics, unit tested in TestsHikeMap.mc without a Dc.
// "Overlap" uses the ink model of the display bench (TestsLayout.mc), shared
// with HikeGridLayout (INK_K), so that the layout changes exactly where the
// bench finds a defect.
// --------------------------------------------------------------------------------
module HikeMapLayout
{
    // Offset of the two "Waiting for" / "GPS" lines above and below the
    // screen centre, tuned on fenix6pro.
    const LINE_OFFSET = 15;

    // Centres [y1, y2] of the two "Waiting for" / "GPS" lines (drawn
    // TEXT_JUSTIFY_VCENTER) on a screen h px high, fontHeight being the
    // height of their font. The tuned h / 2 -+ LINE_OFFSET (Numbers, as the
    // original drawText() calls) wherever the two lines do not overlap or
    // the font height is unknown; otherwise the lines one font height apart
    // (the font's own line spacing), centred on h / 2.
    function waitingLinesY(h, fontHeight)
    {
        var c = h / 2;
        var y1 = c - LINE_OFFSET;
        var y2 = c + LINE_OFFSET;
        if (fontHeight == null || fontHeight <= 0 || !inksOverlap(y1, y2, fontHeight))
        {
            return [y1, y2];
        }
        var half = fontHeight / 2.0;
        return [c - half, c + half];
    }

    // True if two lines of a th px high font centred on y1 < y2 overlap:
    // each line's ink is its box less floor(INK_K x th) at the top and at
    // the bottom (touching is not overlapping).
    function inksOverlap(y1, y2, th)
    {
        var m = (HikeGridLayout.INK_K * th).toNumber();
        return y1 + th / 2.0 - m > y2 - th / 2.0 + m;
    }
}
