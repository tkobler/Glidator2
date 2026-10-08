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

    // True when the sub-window layout applies to a screen w x h.
    function applies(w, h, round, sub)
    {
        return false;
    }

    // Positions of the grid texts. sub: [x, y, width, height] of the
    // sub-window; marginX: side margin of the grid; lab, val: [height,
    // ascent] of the label font and of the value font. null when
    // applies() is false.
    function compute(w, h, round, sub, marginX, lab, val)
    {
        return null;
    }
}
