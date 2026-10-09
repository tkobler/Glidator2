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

// ---------------------------------------------------------------------------
// Fit of the hikeGrid() texts on screens without a sub-window (round Fenix,
// Forerunner, epix...): the timer (placeTimer) and the two middle values
// (placeColumns). Real metrics, from the bench logs of 2026-10-08 (text
// width = ink width + 2, FONT_* heights of testBenchSelfTextBoxes):
//   fenix6pro 260 x 260: NUMBER_MEDIUM 74, NUMBER_MILD 60, XTINY 19;
//     "32:45" MEDIUM 118, "99:59:59" MEDIUM 184, "20000" MILD 116,
//     "999.9" MILD 100, "TIMER" XTINY 42; timer at (130, 215.5), middle
//     values at (73, 142) and (187, 142).
//   fr265s 360 x 360: NUMBER_MEDIUM 98, NUMBER_MILD 85, LARGE 58, XTINY 29;
//     "32:45" MEDIUM 208, "99:59:59" MILD 282, "+940" MILD 164, "26:48"
//     MILD 182, "TIMER" XTINY 74; timer at (180, 298.38), middle values at
//     (101.08, 196.62) and (258.92, 196.62).
//   After the fix: fenix6pro "99:59:59" MILD 156; fr265s LARGE 58 high,
//     "99:59:59" 192, "+940" 112, "26:48" 124.
// Widths not logged by the bench are estimates, flagged "est.".
// ---------------------------------------------------------------------------

// inkBox(), inScreen(), overlap(): the ink model and the rules of the
// display bench (TestsLayout.mc), so that the app fixes exactly what the
// bench finds.
(:test)
function testHikeGridInkAndScreenRules(logger)
{
    var errs = [];
    // fenix6pro "32:45" in NUMBER_MEDIUM: 74 px high, floor(0.16 x 74) = 11.
    var b = HikeGridLayout.inkBox(130, 215.5, 118, 74);
    HikeGridCheck.near(errs, "ink x0", b[0], 72.0);
    HikeGridCheck.near(errs, "ink y0", b[1], 189.5);
    HikeGridCheck.near(errs, "ink x1", b[2], 188.0);
    HikeGridCheck.near(errs, "ink y1", b[3], 241.5);
    // Zero-sized text: a box with no width, no crash.
    b = HikeGridLayout.inkBox(10, 10, 0, 0);
    HikeGridCheck.near(errs, "empty ink x0", b[0], 11.0);
    HikeGridCheck.near(errs, "empty ink y0", b[1], 10.0);

    var round = [260, 260, true];
    if (!HikeGridLayout.inScreen([72, 189.5, 188, 241.5], round)) { errs.add("fenix6pro 32:45 MEDIUM: must be on screen"); }
    if (HikeGridLayout.inScreen([39, 189.5, 221, 241.5], round)) { errs.add("fenix6pro 99:59:59 MEDIUM: must be off screen (bench OFFSCREEN)"); }
    // Circle of radius w/2 + 1, as the bench: (130, -1) is in, (130, -2) out.
    if (!HikeGridLayout.inScreen([130, -1, 130, -1], round)) { errs.add("(w/2, -1): on the w/2 + 1 circle, must be in"); }
    if (HikeGridLayout.inScreen([130, -2, 130, -2], round)) { errs.add("(w/2, -2): must be out"); }
    var rect = [176, 176, false];
    if (!HikeGridLayout.inScreen([0, 0, 176, 176], rect)) { errs.add("rectangle: the whole screen is in"); }
    if (HikeGridLayout.inScreen([-1, 0, 10, 10], rect)) { errs.add("rectangle: x0 = -1 is out"); }
    if (HikeGridLayout.inScreen([0, 0, 10, 177], rect)) { errs.add("rectangle: y1 = h + 1 is out"); }

    if (!HikeGridLayout.overlap([0, 0, 10, 10], [9, 9, 20, 20])) { errs.add("overlap: 1 x 1 px shared must be true"); }
    if (HikeGridLayout.overlap([0, 0, 10, 10], [10, 0, 20, 10])) { errs.add("overlap: touching in x must be false"); }
    if (HikeGridLayout.overlap([0, 0, 10, 10], [0, 10, 10, 20])) { errs.add("overlap: touching in y must be false"); }
    return HikeGridCheck.finish(errs, logger);
}

// placeTimer(): the default font and position are kept whenever they fit,
// so that "32:45" never moves on fenix6pro; otherwise the largest font of
// the ladder, not larger than the default, at the default position or just
// below the "TIMER" label.
(:test)
function testHikeGridPlaceTimerKeepsWhatFits(logger)
{
    var errs = [];
    var round = [260, 260, true];
    // "TIMER" XTINY 42 x 19 at (130, 183): ink (110, 176.5, 150, 189.5).
    var label = HikeGridLayout.inkBox(130, 183, 42, 19);
    HikeGridCheck.near(errs, "TIMER ink y1", label[3], 189.5);

    // fenix6pro Normal: "32:45" MEDIUM fits (its ink touches the label).
    // Ladder MEDIUM, MILD (est. 100), LARGE (est. 70 x 40).
    var p = HikeGridLayout.placeTimer([[118, 74], [100, 60], [70, 40]], 0, 215.5, label, round, 208);
    HikeGridCheck.near(errs, "32:45 font", p[0], 0);
    HikeGridCheck.near(errs, "32:45 y", p[1], 215.5);

    // fenix6pro Extreme: "99:59:59" MEDIUM is off the circle; MILD (est.
    // 154 = 6 digits of 23 + 2 colons of 8, from "2149" and "26:48") fits
    // at the same position: only the font changes.
    p = HikeGridLayout.placeTimer([[184, 74], [154, 60], [110, 40]], 0, 215.5, label, round, 208);
    HikeGridCheck.near(errs, "99:59:59 font", p[0], 1);
    HikeGridCheck.near(errs, "99:59:59 y", p[1], 215.5);

    // The real MILD width is 156 (bench log after the fix: ink 53..207):
    // 2 px more and its bottom corners leave the circle at 215.5; just
    // below the label (ink top 189.5 + 1) it fits: y = 190.5 + 30 - 9.
    p = HikeGridLayout.placeTimer([[184, 74], [156, 60], [110, 40]], 0, 215.5, label, round, 208);
    HikeGridCheck.near(errs, "real 99:59:59 font", p[0], 1);
    HikeGridCheck.near(errs, "real 99:59:59 y", p[1], 211.5);

    // Default MILD (pickFont() chose it): MEDIUM is never tried again, even
    // if it would fit.
    p = HikeGridLayout.placeTimer([[118, 74], [100, 60], [70, 40]], 1, 215.5, label, round, 208);
    HikeGridCheck.near(errs, "default MILD font", p[0], 1);
    HikeGridCheck.near(errs, "default MILD y", p[1], 215.5);

    // No metrics: the default, unchanged.
    p = HikeGridLayout.placeTimer(null, 0, 215.5, label, round, 208);
    HikeGridCheck.near(errs, "null dims font", p[0], 0);
    HikeGridCheck.near(errs, "null dims y", p[1], 215.5);
    p = HikeGridLayout.placeTimer([], 0, 215.5, label, round, 208);
    HikeGridCheck.near(errs, "empty dims y", p[1], 215.5);
    return HikeGridCheck.finish(errs, logger);
}

// placeTimer() on fr265s (real widths) and in the limits: moved below the
// label when it overlaps it, smallest font just below the label when
// nothing fits, width limit maxW, rectangle screen.
(:test)
function testHikeGridPlaceTimerFixes(logger)
{
    var errs = [];
    var round = [360, 360, true];
    // "TIMER" XTINY 74 x 29 at (180, 253.38): floor(0.16 x 29) = 4.
    var label = HikeGridLayout.inkBox(180, 253.38, 74, 29);
    HikeGridCheck.near(errs, "fr265s TIMER ink y1", label[3], 263.88);

    // Normal "32:45": MEDIUM 208 x 98 off the circle (bench OFFSCREEN
    // (77,264,283,332)); MILD 182 x 85 fits at the same position.
    var p = HikeGridLayout.placeTimer([[208, 98], [182, 85], [124, 58]], 0, 298.38, label, round, 288);
    HikeGridCheck.near(errs, "fr265s 32:45 font", p[0], 1);
    HikeGridCheck.near(errs, "fr265s 32:45 y", p[1], 298.38);

    // Extreme "99:59:59": default MILD 282 x 85 off the circle, also just
    // below the label; LARGE (192 x 58, confirmed by the bench log after
    // the fix) fits at the same position. MEDIUM 300 is a placeholder:
    // never tried, the ladder starts at the default MILD.
    p = HikeGridLayout.placeTimer([[300, 98], [282, 85], [192, 58]], 1, 298.38, label, round, 288);
    HikeGridCheck.near(errs, "fr265s 99:59:59 font", p[0], 2);
    HikeGridCheck.near(errs, "fr265s 99:59:59 y", p[1], 298.38);

    // A value whose ink overlaps the label, in the circle once moved down
    // (fr965 "--:--" case): same font, ink top 1 px (GAP) below the label's
    // ink bottom. "--:--" 110 x 98: ink top 264.38 at the default position,
    // under a label whose ink ends at 266.
    var low = [144, 240.0, 216, 266.0];
    p = HikeGridLayout.placeTimer([[110, 98], [96, 85]], 0, 298.38, low, round, 288);
    HikeGridCheck.near(errs, "moved down font", p[0], 0);
    // Ink top = 266 + 1 -> y = 267 + 49 - 15 = 301.
    HikeGridCheck.near(errs, "moved down y", p[1], 301.0);

    // Nothing fits (all too wide for the circle): smallest font, just
    // below the label.
    p = HikeGridLayout.placeTimer([[400, 98], [380, 85]], 0, 298.38, label, round, 1000);
    HikeGridCheck.near(errs, "nothing fits font", p[0], 1);
    // 263.88 + 1 + 42.5 - 13 = 294.38.
    HikeGridCheck.near(errs, "nothing fits y", p[1], 294.38);

    // maxW: a font of the ladder wider than maxW is skipped even if it is
    // in the circle.
    p = HikeGridLayout.placeTimer([[208, 98], [182, 85], [124, 58]], 0, 298.38, label, round, 150);
    HikeGridCheck.near(errs, "maxW font", p[0], 2);

    // Rectangle 176 x 176: a timer whose ink goes below the screen bottom
    // moves up to the label, else shrinks.
    var rect = [176, 176, false];
    var rl = [70, 120, 106, 130];
    p = HikeGridLayout.placeTimer([[100, 60], [80, 40]], 0, 160, rl, rect, 140);
    // MILD default: ink 160 - 30 + 9 = 139 .. 181 > 176 -> out; just below
    // the label: ink 131 .. 173 -> in: same font, y = 131 + 30 - 9 = 152.
    HikeGridCheck.near(errs, "rectangle font", p[0], 0);
    HikeGridCheck.near(errs, "rectangle y", p[1], 152.0);
    return HikeGridCheck.finish(errs, logger);
}

// placeColumns(): the two middle values. Kept where they fit (fenix6pro,
// even "20000" x "999.9"); otherwise spread symmetrically about the centre
// (the divider), with equal gaps between them and to the circle of at
// least minGap; otherwise the next smaller font of the ladder.
(:test)
function testHikeGridPlaceColumns(logger)
{
    var errs = [];
    // fenix6pro Extreme: "20000" 116, "999.9" 100, MILD 60: unchanged.
    var c = HikeGridLayout.placeColumns([[116, 100, 60], [80, 70, 40]], [73, 187], 142, [260, 260, true], 5.2);
    HikeGridCheck.near(errs, "fenix6pro font", c[0], 0);
    HikeGridCheck.near(errs, "fenix6pro left x", c[1], 73.0);
    HikeGridCheck.near(errs, "fenix6pro right x", c[2], 187.0);

    // fr265s Normal: "+940" 164 x "26:48" 182 in MILD 85 overlap by 13 px
    // (bench); spread, the wider ink 180 leaves no room in the half chord
    // 175: LARGE (112, 124, 58, confirmed by the bench log after the fix)
    // at the default centres.
    var xs = [101.08, 258.92];
    c = HikeGridLayout.placeColumns([[164, 182, 85], [112, 124, 58]], xs, 196.62, [360, 360, true], 7.2);
    HikeGridCheck.near(errs, "fr265s font", c[0], 1);
    HikeGridCheck.near(errs, "fr265s left x", c[1], 101.08);
    HikeGridCheck.near(errs, "fr265s right x", c[2], 258.92);

    // Spread, by hand, on a 400 x 400 rectangle (half width 200): inks 150
    // and 120 wide at the default centres 150 and 250 overlap (75..225 x
    // 190..310). Spread: g = 2 (200 - 150) / 3 = 33.33 (the gap, and the
    // margin left beside the wider value); left centre 200 - 16.67 - 75 =
    // 108.33, right centre 200 + 16.67 + 60 = 276.67.
    c = HikeGridLayout.placeColumns([[152, 122, 40], [100, 80, 30]], [150, 250], 200, [400, 400, false], 10);
    HikeGridCheck.near(errs, "spread font", c[0], 0);
    HikeGridCheck.near(errs, "spread left x", c[1], 108.333);
    HikeGridCheck.near(errs, "spread right x", c[2], 276.667);

    // Same, but minGap 40 > 33.33: the next font, at the default centres
    // (left ink 101..199, right 211..289: they fit).
    c = HikeGridLayout.placeColumns([[152, 122, 40], [100, 80, 30]], [150, 250], 200, [400, 400, false], 40);
    HikeGridCheck.near(errs, "minGap font", c[0], 1);
    HikeGridCheck.near(errs, "minGap left x", c[1], 150.0);

    // Nothing fits: the smallest font at the default centres.
    c = HikeGridLayout.placeColumns([[300, 300, 40], [250, 250, 30]], [150, 250], 200, [400, 400, false], 10);
    HikeGridCheck.near(errs, "nothing fits font", c[0], 1);
    HikeGridCheck.near(errs, "nothing fits left x", c[1], 150.0);
    HikeGridCheck.near(errs, "nothing fits right x", c[2], 250.0);

    // No metrics: the defaults.
    c = HikeGridLayout.placeColumns(null, [150, 250], 200, [400, 400, false], 10);
    HikeGridCheck.near(errs, "null dims font", c[0], 0);
    HikeGridCheck.near(errs, "null dims right x", c[2], 250.0);
    return HikeGridCheck.finish(errs, logger);
}

} // module HikeGridLayoutTests
