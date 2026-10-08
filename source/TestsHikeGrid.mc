using Toybox.Test;

// Unit tests of HikeGridLayout (HikeGridLayout.mc): layout of the hike
// Position and Pace pages on watches with a round sub-window. The font
// metrics [height, ascent] are the real ones logged by the bench
// (testBenchSelfTextBoxes, 2026-10-08) for FONT_XTINY (labels) and
// FONT_NUMBER_MILD (values):
//   instinct2      176 x 176, sub [113, 0, 62, 62], XTINY 23/18, MILD 35/30
//   instincte40mm  166 x 166, sub [113, 0, 52, 52], XTINY 20/16, MILD 32/27
//   instinct2s     163 x 156, sub [108, 0, 54, 54], XTINY 19/16, MILD 32/27
// In a module: the 'globals' module of the device is limited to 253 members.
(:test)
module HikeGridLayoutTests
{

(:test)
class HikeGridCheck
{
    // Adds a line to errs unless |actual - want| <= 0.01.
    static function near(errs, label, actual, want)
    {
        if (actual == null || (actual.toFloat() - want).abs() > 0.01)
        {
            errs.add(label + ": expected " + want + ", got " + actual);
        }
    }

    // The invariants every layout must keep: each text starts at least
    // 1 px below the baseline of the text above it (labels and values are
    // capitals and digits: no ink below the baseline), the middle row
    // starts below the sub-window, the top field stays at its side.
    static function invariants(errs, name, l, sub, lab, val)
    {
        if (l == null)
        {
            errs.add(name + ": no layout");
            return;
        }
        if (l.size() != HikeGridLayout.LAYOUT_SIZE)
        {
            errs.add(name + ": " + l.size() + " values, expected " + HikeGridLayout.LAYOUT_SIZE);
            return;
        }
        var subBottom = sub[1] + sub[3];
        if (l[HikeGridLayout.TOP_LABEL_Y] < 0) { errs.add(name + ": top label above the screen"); }
        if (l[HikeGridLayout.TOP_VALUE_ONLY_Y] < 0) { errs.add(name + ": top value above the screen"); }
        if (l[HikeGridLayout.TOP_VALUE_Y] < l[HikeGridLayout.TOP_LABEL_Y] + lab[1] + 1) { errs.add(name + ": top value over its label"); }
        if (l[HikeGridLayout.MID_LABEL_Y] < subBottom) { errs.add(name + ": middle labels in the sub-window rows"); }
        if (l[HikeGridLayout.MID_LABEL_Y] < l[HikeGridLayout.TOP_VALUE_Y] + val[1] + 1) { errs.add(name + ": middle labels over the top value"); }
        if (l[HikeGridLayout.MID_LABEL_Y] < l[HikeGridLayout.TOP_VALUE_ONLY_Y] + val[1] + 1) { errs.add(name + ": middle labels over the lone top value"); }
        if (l[HikeGridLayout.MID_VALUE_Y] < l[HikeGridLayout.MID_LABEL_Y] + lab[1] + 1) { errs.add(name + ": middle values over their labels"); }
        if (l[HikeGridLayout.BOT_LABEL_Y] < l[HikeGridLayout.MID_VALUE_Y] + val[1] + 1) { errs.add(name + ": bottom label over the middle values"); }
        if (l[HikeGridLayout.BOT_VALUE_Y] < l[HikeGridLayout.BOT_LABEL_Y] + lab[1] + 1) { errs.add(name + ": timer over its label"); }
        if (l[HikeGridLayout.COL_LEFT_X] >= l[HikeGridLayout.COL_RIGHT_X]) { errs.add(name + ": columns swapped"); }
    }

    static function finish(errs, logger)
    {
        for (var i = 0; i < errs.size(); i++)
        {
            logger.error(errs[i]);
        }
        return errs.size() == 0;
    }
}

// applies(): only a non-round screen with a sub-window in the upper half,
// against the left or the right side.
(:test)
function testHikeGridLayoutApplies(logger)
{
    var errs = [];
    if (!HikeGridLayout.applies(176, 176, false, [113, 0, 62, 62])) { errs.add("instinct2 sub-window: must apply"); }
    if (!HikeGridLayout.applies(163, 156, false, [108, 0, 54, 54])) { errs.add("instinct2s sub-window: must apply"); }
    if (!HikeGridLayout.applies(176, 176, false, [0, 0, 62, 62])) { errs.add("sub-window on the left: must apply"); }
    if (!HikeGridLayout.applies(176, 176, false, [113, 4, 62, 62])) { errs.add("sub-window 4 px down: must apply"); }
    if (!HikeGridLayout.applies(176, 176, false, [113, 0, 62, 88])) { errs.add("sub-window down to h/2 (bound): must apply"); }
    if (HikeGridLayout.applies(176, 176, false, null)) { errs.add("no sub-window (fenix, forerunner): must not apply"); }
    if (HikeGridLayout.applies(260, 260, true, null)) { errs.add("round, no sub-window (fenix6pro): must not apply"); }
    if (HikeGridLayout.applies(390, 390, true, [280, 0, 98, 98])) { errs.add("round screen with a sub-window: must not apply (top corners off the circle)"); }
    if (HikeGridLayout.applies(176, 176, false, [113, 0, 0, 62])) { errs.add("zero-width sub-window: must not apply"); }
    if (HikeGridLayout.applies(176, 176, false, [113, 0, 62, 0])) { errs.add("zero-height sub-window: must not apply"); }
    if (HikeGridLayout.applies(176, 176, false, [113, 0, 62, 89])) { errs.add("sub-window past h/2: must not apply"); }
    if (HikeGridLayout.applies(176, 176, false, [113, 100, 62, 62])) { errs.add("sub-window at the bottom: must not apply"); }
    if (HikeGridLayout.applies(176, 176, false, [60, 0, 56, 56])) { errs.add("sub-window in the middle (no side left): must not apply"); }
    if (HikeGridLayout.applies(176, 176, false, [113, 0, 62])) { errs.add("malformed sub-window (3 values): must not apply"); }
    return HikeGridCheck.finish(errs, logger);
}

// compute() with the real instinct2 metrics: every value, by hand.
// Sub-window bottom 62. Top stack: label ascent 18 + 1 + value height 35 =
// 54, centred in 0..62: label at 4, value at 4 + 19 = 23; the lone value
// (Pace page) at (62 - 35) / 2 = 13.5. Top field centred between the margin
// 17.6 and the sub-window x 113: 65.3. Columns at w/4 and 3w/4. Middle row
// from the sub-window bottom 62; then label ascent + 1 = 19, value ascent
// + 1 = 31: 62, 81, 112, 131.
(:test)
function testHikeGridLayoutInstinct2(logger)
{
    var errs = [];
    var sub = [113, 0, 62, 62];
    var lab = [23, 18];
    var val = [35, 30];
    var l = HikeGridLayout.compute(176, 176, false, sub, 17.6, lab, val);
    HikeGridCheck.invariants(errs, "instinct2", l, sub, lab, val);
    if (errs.size() == 0)
    {
        HikeGridCheck.near(errs, "TOP_X", l[HikeGridLayout.TOP_X], 65.3);
        HikeGridCheck.near(errs, "TOP_LABEL_Y", l[HikeGridLayout.TOP_LABEL_Y], 4.0);
        HikeGridCheck.near(errs, "TOP_VALUE_Y", l[HikeGridLayout.TOP_VALUE_Y], 23.0);
        HikeGridCheck.near(errs, "TOP_VALUE_ONLY_Y", l[HikeGridLayout.TOP_VALUE_ONLY_Y], 13.5);
        HikeGridCheck.near(errs, "COL_LEFT_X", l[HikeGridLayout.COL_LEFT_X], 44.0);
        HikeGridCheck.near(errs, "COL_RIGHT_X", l[HikeGridLayout.COL_RIGHT_X], 132.0);
        HikeGridCheck.near(errs, "MID_LABEL_Y", l[HikeGridLayout.MID_LABEL_Y], 62.0);
        HikeGridCheck.near(errs, "MID_VALUE_Y", l[HikeGridLayout.MID_VALUE_Y], 81.0);
        HikeGridCheck.near(errs, "BOT_LABEL_Y", l[HikeGridLayout.BOT_LABEL_Y], 112.0);
        HikeGridCheck.near(errs, "BOT_VALUE_Y", l[HikeGridLayout.BOT_VALUE_Y], 131.0);
    }
    return HikeGridCheck.finish(errs, logger);
}

// compute() with the real instincte40mm and instinct2s metrics.
(:test)
function testHikeGridLayoutSmallInstincts(logger)
{
    var errs = [];
    var sub = [113, 0, 52, 52];
    var lab = [20, 16];
    var val = [32, 27];
    var l = HikeGridLayout.compute(166, 166, false, sub, 16.6, lab, val);
    HikeGridCheck.invariants(errs, "instincte40mm", l, sub, lab, val);
    if (l != null && l.size() == HikeGridLayout.LAYOUT_SIZE)
    {
        HikeGridCheck.near(errs, "e40 TOP_X", l[HikeGridLayout.TOP_X], 64.8);
        HikeGridCheck.near(errs, "e40 TOP_LABEL_Y", l[HikeGridLayout.TOP_LABEL_Y], 1.5);
        HikeGridCheck.near(errs, "e40 TOP_VALUE_Y", l[HikeGridLayout.TOP_VALUE_Y], 18.5);
        HikeGridCheck.near(errs, "e40 TOP_VALUE_ONLY_Y", l[HikeGridLayout.TOP_VALUE_ONLY_Y], 10.0);
        HikeGridCheck.near(errs, "e40 COL_LEFT_X", l[HikeGridLayout.COL_LEFT_X], 41.5);
        HikeGridCheck.near(errs, "e40 COL_RIGHT_X", l[HikeGridLayout.COL_RIGHT_X], 124.5);
        HikeGridCheck.near(errs, "e40 MID_LABEL_Y", l[HikeGridLayout.MID_LABEL_Y], 52.0);
        HikeGridCheck.near(errs, "e40 MID_VALUE_Y", l[HikeGridLayout.MID_VALUE_Y], 69.0);
        HikeGridCheck.near(errs, "e40 BOT_LABEL_Y", l[HikeGridLayout.BOT_LABEL_Y], 97.0);
        HikeGridCheck.near(errs, "e40 BOT_VALUE_Y", l[HikeGridLayout.BOT_VALUE_Y], 114.0);
    }

    sub = [108, 0, 54, 54];
    lab = [19, 16];
    l = HikeGridLayout.compute(163, 156, false, sub, 16.3, lab, val);
    HikeGridCheck.invariants(errs, "instinct2s", l, sub, lab, val);
    if (l != null && l.size() == HikeGridLayout.LAYOUT_SIZE)
    {
        HikeGridCheck.near(errs,"2s TOP_X", l[HikeGridLayout.TOP_X], 62.15);
        HikeGridCheck.near(errs,"2s TOP_LABEL_Y", l[HikeGridLayout.TOP_LABEL_Y], 2.5);
        HikeGridCheck.near(errs,"2s TOP_VALUE_Y", l[HikeGridLayout.TOP_VALUE_Y], 19.5);
        HikeGridCheck.near(errs,"2s TOP_VALUE_ONLY_Y", l[HikeGridLayout.TOP_VALUE_ONLY_Y], 11.0);
        HikeGridCheck.near(errs,"2s COL_LEFT_X", l[HikeGridLayout.COL_LEFT_X], 40.75);
        HikeGridCheck.near(errs,"2s COL_RIGHT_X", l[HikeGridLayout.COL_RIGHT_X], 122.25);
        HikeGridCheck.near(errs,"2s MID_LABEL_Y", l[HikeGridLayout.MID_LABEL_Y], 54.0);
        HikeGridCheck.near(errs,"2s MID_VALUE_Y", l[HikeGridLayout.MID_VALUE_Y], 71.0);
        HikeGridCheck.near(errs,"2s BOT_LABEL_Y", l[HikeGridLayout.BOT_LABEL_Y], 99.0);
        HikeGridCheck.near(errs,"2s BOT_VALUE_Y", l[HikeGridLayout.BOT_VALUE_Y], 116.0);
    }
    return HikeGridCheck.finish(errs, logger);
}

// Limits: a sub-window on the left puts the top field on the right; a
// sub-window too short for the top stack clamps it to y = 0 and pushes the
// middle row below the top value; zero font metrics give no negative or
// swapped position; no layout (null) where applies() is false.
(:test)
function testHikeGridLayoutLimits(logger)
{
    var errs = [];
    var lab = [23, 18];
    var val = [35, 30];

    var sub = [0, 0, 62, 62];
    var l = HikeGridLayout.compute(176, 176, false, sub, 17.6, lab, val);
    HikeGridCheck.invariants(errs, "left sub-window", l, sub, lab, val);
    if (l != null && l.size() == HikeGridLayout.LAYOUT_SIZE)
    {
        // Between the sub-window right side 62 and w - margin 158.4.
        HikeGridCheck.near(errs, "left sub-window TOP_X", l[HikeGridLayout.TOP_X], 110.2);
    }

    sub = [113, 0, 30, 30];
    l = HikeGridLayout.compute(176, 176, false, sub, 17.6, lab, val);
    HikeGridCheck.invariants(errs, "short sub-window", l, sub, lab, val);
    if (l != null && l.size() == HikeGridLayout.LAYOUT_SIZE)
    {
        // Stack 54 > 30: label at 0, value at 19, lone value at 0; middle
        // row at 19 + 30 + 1 = 50, not at the sub-window bottom 30.
        HikeGridCheck.near(errs, "short TOP_LABEL_Y", l[HikeGridLayout.TOP_LABEL_Y], 0.0);
        HikeGridCheck.near(errs, "short TOP_VALUE_Y", l[HikeGridLayout.TOP_VALUE_Y], 19.0);
        HikeGridCheck.near(errs, "short TOP_VALUE_ONLY_Y", l[HikeGridLayout.TOP_VALUE_ONLY_Y], 0.0);
        HikeGridCheck.near(errs, "short MID_LABEL_Y", l[HikeGridLayout.MID_LABEL_Y], 50.0);
    }

    sub = [113, 4, 62, 62];
    l = HikeGridLayout.compute(176, 176, false, sub, 17.6, lab, val);
    HikeGridCheck.invariants(errs, "sub-window 4 px down", l, sub, lab, val);
    if (l != null && l.size() == HikeGridLayout.LAYOUT_SIZE)
    {
        HikeGridCheck.near(errs, "4 px down MID_LABEL_Y", l[HikeGridLayout.MID_LABEL_Y], 66.0);
    }

    sub = [113, 0, 62, 62];
    l = HikeGridLayout.compute(176, 176, false, sub, 17.6, [0, 0], [0, 0]);
    HikeGridCheck.invariants(errs, "zero metrics", l, sub, [0, 0], [0, 0]);

    if (HikeGridLayout.compute(176, 176, false, null, 17.6, lab, val) != null) { errs.add("no sub-window: layout must be null"); }
    if (HikeGridLayout.compute(390, 390, true, [280, 0, 98, 98], 39.0, lab, val) != null) { errs.add("round screen: layout must be null"); }
    return HikeGridCheck.finish(errs, logger);
}

} // module HikeGridLayoutTests
