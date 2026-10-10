using Toybox.Math;

// --------------------------------------------------------------------------------
// Layout of WatchDisplay.compass() (flight Position page, plan point V3a), a
// pure function of the font metrics, unit tested in TestsCompass.mc without
// a Dc. "Inside the screen" uses the ink model of the display bench
// (TestsLayout.mc), shared with HikeGridLayout (INK_K), so that the letters
// move exactly where the bench finds a defect.
// --------------------------------------------------------------------------------
module CompassLayout
{
    // Distance of the centre of the N / S / E / W letters from the rim of
    // the dial, tuned on fenix6pro.
    const LETTER_INSET = 18;

    // Length of the short graduations of the dial (every 5 degrees).
    const SHORT_MARK = 10;

    // Inset (px) of the centres of the 4 letters from the rim of the dial.
    // fontHeight: Dc.getFontHeight(FONT_LARGE); letterDims: getTextDimensions()
    // [width, height] of "N", "S", "E", "W" in FONT_LARGE.
    // Not written yet (red tests first): always the old inset.
    function letterInset(fontHeight, letterDims)
    {
        return LETTER_INSET;
    }
}
