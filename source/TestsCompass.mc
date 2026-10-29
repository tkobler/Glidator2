using Toybox.Test;
using Toybox.Lang;
using Toybox.Math;

// Unit tests of CompassLayout (CompassLayout.mc): inset of the N / S / E / W
// letters of the compass dial (V3a, plan of 08/10). FONT_LARGE heights are
// the real ones logged by the bench (testBenchSelfTextBoxes, 2026-10-09);
// the letter widths are the bench's ink widths (Compass/Empty) plus 2 px:
// exact on fenix6pro, within 1 px elsewhere (the logged boxes are rounded).
// Bench ink model: a w x h text loses 1 px on each side and floor(0.16 h)
// at the top and at the bottom. A letter whose centre is d px from the
// centre stays inside the circle of radius r + 1 (the bench's tolerance)
// whatever the heading when d + its ink half-diagonal <= r + 1, that is,
// with d = r - inset, when its ink half-diagonal <= inset + 1.
// The 'globals' module of the device is limited to 253 members, and a new
// test module was one too many (fenix6pro test build: 254): these tests
// reopen HikeMapLayoutTests (TestsHikeMap.mc), the tests of the map page
// layout, whose waitingLinesY() the compass also uses since V3b.
(:test)
module HikeMapLayoutTests
{

(:test)
class CompassCheck
{
    // [name, FONT_LARGE height, [[w, h] of N, S, E, W]]
    static function keptWatches()
    {
        return [
            ["fenix6pro", 40, [[20, 40], [18, 40], [16, 40], [26, 40]]],
            ["fenix7", 40, [[20, 40], [18, 40], [16, 40], [26, 40]]],
            ["fenix5", 37, [[18, 37], [18, 37], [14, 37], [22, 37]]],
            ["fr55", 34, [[18, 34], [14, 34], [14, 34], [22, 34]]],
            ["fr255s", 32, [[16, 32], [14, 32], [14, 32], [20, 32]]],
            ["instinct2", 31, [[12, 31], [14, 31], [10, 31], [18, 31]]],
            ["instincte40mm", 27, [[12, 27], [12, 27], [10, 27], [18, 27]]],
            ["instinct2s", 27, [[12, 27], [12, 27], [10, 27], [18, 27]]]
        ];
    }

    // [name, FONT_LARGE height, letter dims, expected inset]
    static function movedWatches()
    {
        return [
            ["fenix7x", 43, [[22, 43], [18, 43], [18, 43], [26, 43]], 31.5],
            ["fr265s", 58, [[34, 58], [30, 58], [28, 58], [42, 58]], 39.0],
            ["epix2pro42mm", 56, [[28, 56], [25, 56], [22, 56], [34, 56]], 38.0],
            ["instinct3amoled45mm", 55, [[32, 55], [27, 55], [26, 55], [42, 55]], 37.5],
            ["instinct3amoled50mm", 59, [[34, 59], [29, 59], [28, 59], [42, 59]], 39.5],
            ["epix2", 59, [[30, 59], [26, 59], [24, 59], [36, 59]], 39.5],
            ["fenix843mm", 67, [[42, 67], [34, 67], [32, 67], [50, 67]], 43.5],
            ["fr965", 71, [[44, 71], [36, 71], [34, 71], [54, 71]], 45.5],
            ["fenix9pro51mm", 71, [[44, 71], [36, 71], [34, 71], [54, 71]], 45.5]
        ];
    }

    // Largest ink half-diagonal of the letters, bench ink model.
    static function halfDiagonal(dims)
    {
        var worst = 0.0;
        for (var i = 0; i < dims.size(); i++)
        {
            var a = dims[i][0] / 2.0 - 1;
            var b = dims[i][1] / 2.0 - (0.16 * dims[i][1]).toNumber();
            var d = Math.sqrt(a * a + b * b);
            if (d > worst) { worst = d; }
        }
        return worst;
    }

    // Adds a line to errs unless `got` is the Number 18, the old inset (same
    // drawText() arguments as before, not a Float that only looks the same).
    static function old(errs, label, got)
    {
        if (!(got instanceof Lang.Number) || got != 18)
        {
            errs.add(label + ": expected the old inset 18 (Number), got " + got);
        }
    }

    static function near(errs, label, got, want)
    {
        if (got == null || (got.toFloat() - want).abs() > 0.01)
        {
            errs.add(label + ": expected " + want + ", got " + got);
        }
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

// Where the old 18 px keep every letter inside the circle at any heading
// (no bench defect): the inset stays 18, so fenix6pro and fenix5 draw the
// letters exactly where they did.
(:test)
function testCompassLetterInsetKeepsTheTunedInset(logger)
{
    var errs = [];
    var w = CompassCheck.keptWatches();
    for (var i = 0; i < w.size(); i++)
    {
        CompassCheck.old(errs, w[i][0], CompassLayout.letterInset(w[i][1], w[i][2]));
    }
    // fenix6pro by hand: "W" 26 x 40, ink 24 x 28, half-diagonal 18.44 <= 19.
    CompassCheck.old(errs, "fenix6pro W alone", CompassLayout.letterInset(40, [[26, 40]]));
    return CompassCheck.finish(errs, logger);
}

// Where a letter leaves the circle with 18 px (the bench's OFFSCREEN "N",
// "S", "E", "W", fenix7x's "W" at 45 degrees): half the FONT_LARGE height
// plus a short graduation, and every letter then inside at any heading.
(:test)
function testCompassLetterInsetMovesWhereALetterLeaves(logger)
{
    var errs = [];
    var w = CompassCheck.movedWatches();
    for (var i = 0; i < w.size(); i++)
    {
        var got = CompassLayout.letterInset(w[i][1], w[i][2]);
        CompassCheck.near(errs, w[i][0], got, w[i][3]);
        var hd = CompassCheck.halfDiagonal(w[i][2]);
        if (got == null || hd > got + 1)
        {
            errs.add(w[i][0] + ": half-diagonal " + hd + " > inset " + got + " + 1, a letter can leave the circle");
        }
    }
    // Every kept watch: inside too.
    var k = CompassCheck.keptWatches();
    for (var i = 0; i < k.size(); i++)
    {
        var hd = CompassCheck.halfDiagonal(k[i][2]);
        if (hd > 19)
        {
            errs.add(k[i][0] + ": half-diagonal " + hd + " > 19 with the old inset");
        }
    }
    return CompassCheck.finish(errs, logger);
}

// Bounds of the rule, missing values, and the guard.
(:test)
function testCompassLetterInsetLimits(logger)
{
    var errs = [];
    // Half-diagonal exactly 19 (ink 0 x 38): touching the r + 1 circle, kept.
    CompassCheck.old(errs, "half-diagonal 19 (bound)", CompassLayout.letterInset(54, [[2, 54]]));
    // 20: out, moved to 56 / 2 + 10.
    CompassCheck.near(errs, "half-diagonal 20", CompassLayout.letterInset(56, [[2, 56]]), 38.0);
    // fenix6pro's "W" 2 px wider: 19.1 > 19, moved to 40 / 2 + 10.
    CompassCheck.near(errs, "fenix6pro W + 2 px", CompassLayout.letterInset(40, [[28, 40]]), 30.0);
    // Odd font height: half a pixel kept.
    CompassCheck.near(errs, "odd FONT_LARGE height 43", CompassLayout.letterInset(43, [[26, 43]]), 31.5);
    // Guard: a letter far wider than its font's half height + 10 (10 px font,
    // 100 x 100 letter, ink 98 x 68): the inset grows to half-diagonal - 1.
    var hd = Math.sqrt(49.0 * 49.0 + 34.0 * 34.0);
    CompassCheck.near(errs, "guard", CompassLayout.letterInset(10, [[100, 100]]), hd - 1);
    // Unknown values: the old inset.
    CompassCheck.old(errs, "null font height", CompassLayout.letterInset(null, [[26, 40]]));
    CompassCheck.old(errs, "zero font height", CompassLayout.letterInset(0, [[26, 40]]));
    CompassCheck.old(errs, "negative font height", CompassLayout.letterInset(-40, [[26, 40]]));
    CompassCheck.old(errs, "null letters", CompassLayout.letterInset(40, null));
    CompassCheck.old(errs, "no letter", CompassLayout.letterInset(40, []));
    CompassCheck.old(errs, "null letter", CompassLayout.letterInset(58, [null]));
    CompassCheck.old(errs, "null width", CompassLayout.letterInset(58, [[null, 58]]));
    CompassCheck.old(errs, "null height", CompassLayout.letterInset(58, [[42, null]]));
    // A null entry is skipped, the others still count.
    CompassCheck.near(errs, "null entry then fr265s W", CompassLayout.letterInset(58, [null, [42, 58]]), 39.0);
    CompassCheck.old(errs, "null entry then fenix6pro W", CompassLayout.letterInset(40, [null, [26, 40]]));
    // Float dimensions: same rule.
    CompassCheck.old(errs, "fenix6pro W in Floats", CompassLayout.letterInset(40.0, [[26.0, 40.0]]));
    CompassCheck.near(errs, "fr265s W in Floats", CompassLayout.letterInset(58.0, [[42.0, 58.0]]), 39.0);
    // Zero-size letter (empty glyph): kept.
    CompassCheck.old(errs, "0 x 0 letter", CompassLayout.letterInset(40, [[0, 0]]));
    return CompassCheck.finish(errs, logger);
}

} // module HikeMapLayoutTests
