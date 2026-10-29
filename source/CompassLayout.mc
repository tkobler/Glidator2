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
    //
    // A letter centred d px from the centre of a circle of radius r, turned
    // by any heading, keeps its ink box (box less 1 px on each side and
    // floor(INK_K x height) at the top and at the bottom) within r + 1 (the
    // bench's tolerance) if and only if d + its ink half-diagonal <= r + 1:
    // with d = r - inset, if its half-diagonal <= inset + 1, whatever r.
    // - The old LETTER_INSET (the Number 18, same drawText() arguments as
    //   before) wherever every letter passes that test with it: fenix6pro,
    //   fenix5 and every watch where the bench found no OFFSCREEN letter.
    // - Else (AMOLED 360-466 px, fenix7x's "W" at 45 degrees) the plan's
    //   half the FONT_LARGE height plus a short graduation, grown to the
    //   largest half-diagonal - 1 if a letter would still leave the circle.
    // Unknown (null) or non-positive font height, no letters: the old inset.
    // A null letter, width or height is skipped.
    function letterInset(fontHeight, letterDims)
    {
        if (fontHeight == null || fontHeight <= 0 || letterDims == null)
        {
            return LETTER_INSET;
        }
        // Largest squared ink half-diagonal of the letters.
        var worst = 0.0;
        for (var i = 0; i < letterDims.size(); i++)
        {
            var d = letterDims[i];
            if (d == null || d[0] == null || d[1] == null)
            {
                continue;
            }
            var a = d[0] / 2.0 - 1;
            var b = d[1] / 2.0 - (HikeGridLayout.INK_K * d[1]).toNumber();
            a = a < 0 ? 0.0 : a;
            b = b < 0 ? 0.0 : b;
            var q = a * a + b * b;
            if (q > worst)
            {
                worst = q;
            }
        }
        var keep = LETTER_INSET + 1;
        if (worst <= keep * keep)
        {
            return LETTER_INSET;
        }
        var inset = fontHeight / 2.0 + SHORT_MARK;
        var need = Math.sqrt(worst) - 1;
        return inset < need ? need : inset;
    }
}
