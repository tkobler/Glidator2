// --------------------------------------------------------------------------------
// Layout of WatchDisplay.hikeGrid() (hike Position and Pace pages) on watches
// with a round sub-window (WatchUi.getSubscreen(): Instinct 2, 2S, E...).
// Pure functions of the screen size, the sub-window rectangle and the font
// metrics, so that they are unit tested (TestsHikeGrid.mc) without a Dc.
// Every other watch keeps the original hikeGrid() layout.
// --------------------------------------------------------------------------------
module HikeGridLayout
{
    // Indexes of the array returned by compute(). X are text centres, Y are
    // text tops (drawText() without TEXT_JUSTIFY_VCENTER).
    enum
    {
        TOP_X,            // centre of the top field, beside the sub-window
        TOP_LABEL_Y,      // top label
        TOP_VALUE_Y,      // top value, below its label
        TOP_VALUE_ONLY_Y, // top value when it has no label (heart icon)
        COL_LEFT_X,       // centre of the left middle column
        COL_RIGHT_X,      // centre of the right middle column
        MID_LABEL_Y,      // middle labels
        MID_VALUE_Y,      // middle values
        BOT_LABEL_Y,      // bottom label
        BOT_VALUE_Y,      // bottom (timer) value
        LAYOUT_SIZE
    }

    // Pixels left between a text's baseline and the top of the text below.
    const GAP = 1;

    // True when the sub-window layout applies to a screen w x h: a
    // sub-window [x, y, width, height] of non-zero size, in the upper half
    // of a non-round screen, wholly on the left or on the right of the
    // centre (the top field goes on the other side). Not on round screens:
    // the top corners beside a sub-window are off the circle there.
    function applies(w, h, round, sub)
    {
        if (round || sub == null || sub.size() != 4)
        {
            return false;
        }
        if (sub[2] <= 0 || sub[3] <= 0 || sub[1] < 0 || (sub[1] + sub[3]) * 2 > h)
        {
            return false;
        }
        return sub[0] * 2 >= w || (sub[0] + sub[2]) * 2 <= w;
    }

    // Positions of the grid texts (indexes above), null when applies() is
    // false. sub: [x, y, width, height] of the sub-window; marginX: side
    // margin of the grid; lab, val: [height, ascent] of the label font
    // (FONT_XTINY) and of the value font (FONT_NUMBER_MILD).
    //
    // Labels and values are capitals and digits, which have no ink below
    // the baseline: each text starts GAP px below the baseline (top +
    // ascent) of the one above it. The top field (label over value, or a
    // lone value beside the heart icon) is centred vertically on the
    // sub-window rows and horizontally between the side margin and the
    // sub-window; the middle row starts below the sub-window, its two
    // columns centred on each half of the screen. The timer font is chosen
    // by the caller in the height left below BOT_VALUE_Y.
    function compute(w, h, round, sub, marginX, lab, val)
    {
        if (!applies(w, h, round, sub))
        {
            return null;
        }
        var subBottom = (sub[1] + sub[3]).toFloat();
        var labStep = lab[1] + GAP;
        var valStep = val[1] + GAP;

        var topX = (sub[0] * 2 >= w)
            ? (marginX + sub[0]) / 2.0
            : (sub[0] + sub[2] + w - marginX) / 2.0;
        var topLabelY = max0((subBottom - (labStep + val[0])) / 2.0);
        var topValueY = topLabelY + labStep;
        var topValueOnlyY = max0((subBottom - val[0]) / 2.0);

        var midLabelY = subBottom;
        if (topValueY + valStep > midLabelY) { midLabelY = topValueY + valStep; }
        if (topValueOnlyY + valStep > midLabelY) { midLabelY = topValueOnlyY + valStep; }
        var midValueY = midLabelY + labStep;
        var botLabelY = midValueY + valStep;
        var botValueY = botLabelY + labStep;

        return [topX, topLabelY, topValueY, topValueOnlyY, w / 4.0, w * 3 / 4.0,
            midLabelY, midValueY, botLabelY, botValueY];
    }

    function max0(v)
    {
        return v < 0 ? 0.0 : v;
    }

    // --- Fit of the texts on screens without a sub-window (stubs) ----------

    function inkBox(x, y, tw, th)
    {
        return [0, 0, 0, 0];
    }

    function inScreen(b, screen)
    {
        return false;
    }

    function overlap(a, b)
    {
        return false;
    }

    function placeTimer(dims, first, y, label, screen, maxW)
    {
        return [first, y];
    }

    function placeColumns(dims, xs, y, screen, minGap)
    {
        return [0, xs[0], xs[1]];
    }
}
