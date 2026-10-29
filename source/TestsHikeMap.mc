using Toybox.Test;
using Toybox.Lang;

// Unit tests of HikeMapLayout (HikeMapLayout.mc): the "Waiting for" / "GPS"
// lines of the hike Map page. Screen heights and FONT_SMALL heights are the
// real ones logged by the bench (testBenchSelfTextBoxes, 2026-10-09):
//   fenix6pro 260/32  fenix5 240/29  fenix7x 280/34  fr255s 218/26
//   fr55 208/27  instinct2 176/24  instincte40mm 166/23  instinct2s 156/20
//   instinct3amoled45mm 390/39  epix2pro42mm 390/44
//   instinct3amoled50mm 416/42  fr265s 360/43  epix2 416/47
//   fenix843mm 416/50  fr965 454/53  fenix9pro51mm 466/53
// Bench ink model: a line of height th loses floor(0.16 th) at the top and
// at the bottom; the two lines overlap when th - 2 floor(0.16 th) exceeds
// their spacing (30 px when they stay at h/2 +- 15).
// In a module: the 'globals' module of the device is limited to 253 members.
(:test)
module HikeMapLayoutTests
{

(:test)
class HikeMapCheck
{
    // Adds a line to errs unless the lines are exactly [y1, y2] (|d| <= 0.01).
    static function lines(errs, label, l, y1, y2)
    {
        if (l == null || l.size() != 2 || l[0] == null || l[1] == null)
        {
            errs.add(label + ": expected [" + y1 + ", " + y2 + "], got " + l);
            return;
        }
        if ((l[0].toFloat() - y1).abs() > 0.01 || (l[1].toFloat() - y2).abs() > 0.01)
        {
            errs.add(label + ": expected [" + y1 + ", " + y2 + "], got " + l);
        }
    }

    // Same, and both values are Numbers: the drawText() arguments of the
    // original map() (dc.getHeight() / 2 -+ 15), not Floats that only look
    // the same.
    static function sameAsBefore(errs, label, h, th)
    {
        var l = HikeMapLayout.waitingLinesY(h, th);
        lines(errs, label, l, h / 2 - 15, h / 2 + 15);
        if (l != null && l.size() == 2 && !(l[0] instanceof Lang.Number && l[1] instanceof Lang.Number))
        {
            errs.add(label + ": the kept lines must be Numbers, got " + l);
        }
    }

    // The lines of waitingLinesY(h, th) must not overlap in the bench ink
    // model, checked with HikeGridLayout's ink box (the bench's rules), and
    // must stay centred on h / 2.
    static function clear(errs, label, h, th)
    {
        var l = HikeMapLayout.waitingLinesY(h, th);
        if (l == null || l.size() != 2)
        {
            errs.add(label + ": no lines");
            return;
        }
        var a = HikeGridLayout.inkBox(100, l[0], 120, th);
        var b = HikeGridLayout.inkBox(100, l[1], 60, th);
        if (HikeGridLayout.overlap(a, b))
        {
            errs.add(label + ": lines " + l + " overlap with font height " + th);
        }
        if (((l[0] + l[1]) / 2.0 - h / 2).abs() > 0.01)
        {
            errs.add(label + ": lines " + l + " not centred on " + (h / 2));
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

// inksOverlap(): the bench rule, touching is not overlapping.
(:test)
function testHikeMapInksOverlap(logger)
{
    var errs = [];
    // fr265s: 43 - 2 x 6 = 31 > 30: 1 px of overlap (the bench defect).
    if (!HikeMapLayout.inksOverlap(165, 195, 43)) { errs.add("fr265s 165/195, 43 px: must overlap"); }
    // fr965 / fenix9pro51mm: 53 - 2 x 8 = 37 > 30.
    if (!HikeMapLayout.inksOverlap(212, 242, 53)) { errs.add("fr965 212/242, 53 px: must overlap"); }
    // epix2pro42mm: 44 - 2 x 7 = 30: inks touch, no overlap (bench passes).
    if (HikeMapLayout.inksOverlap(180, 210, 44)) { errs.add("epix2pro42mm 180/210, 44 px: touching, must not overlap"); }
    // fenix6pro: 32 - 2 x 5 = 22 < 30.
    if (HikeMapLayout.inksOverlap(115, 145, 32)) { errs.add("fenix6pro 115/145, 32 px: must not overlap"); }
    // Lines one font height apart never overlap.
    if (HikeMapLayout.inksOverlap(158.5, 201.5, 43)) { errs.add("fr265s 158.5/201.5, 43 px: must not overlap"); }
    // Float height, same rule.
    if (!HikeMapLayout.inksOverlap(165, 195, 43.0)) { errs.add("43.0 px (Float): must overlap"); }
    return HikeMapCheck.finish(errs, logger);
}

// Every watch where the bench found no defect keeps h/2 -+ 15 exactly
// (Numbers), including epix2pro42mm and instinct3amoled50mm where the inks
// only touch.
(:test)
function testHikeMapWaitingKeepsTheTunedLines(logger)
{
    var errs = [];
    HikeMapCheck.sameAsBefore(errs, "fenix6pro", 260, 32);
    HikeMapCheck.sameAsBefore(errs, "fenix5", 240, 29);
    HikeMapCheck.sameAsBefore(errs, "fenix7x", 280, 34);
    HikeMapCheck.sameAsBefore(errs, "fr255s", 218, 26);
    HikeMapCheck.sameAsBefore(errs, "fr55", 208, 27);
    HikeMapCheck.sameAsBefore(errs, "instinct2", 176, 24);
    HikeMapCheck.sameAsBefore(errs, "instincte40mm", 166, 23);
    HikeMapCheck.sameAsBefore(errs, "instinct2s", 156, 20);
    HikeMapCheck.sameAsBefore(errs, "instinct3amoled45mm", 390, 39);
    HikeMapCheck.sameAsBefore(errs, "epix2pro42mm (touching)", 390, 44);
    HikeMapCheck.sameAsBefore(errs, "instinct3amoled50mm (touching)", 416, 42);
    // By hand, the two reference watches.
    HikeMapCheck.lines(errs, "fenix6pro by hand", HikeMapLayout.waitingLinesY(260, 32), 115, 145);
    HikeMapCheck.lines(errs, "fenix5 by hand", HikeMapLayout.waitingLinesY(240, 29), 105, 135);
    return HikeMapCheck.finish(errs, logger);
}

// Where the lines overlapped: one font height apart about h / 2.
(:test)
function testHikeMapWaitingSpreadsByFontHeight(logger)
{
    var errs = [];
    HikeMapCheck.lines(errs, "fr265s", HikeMapLayout.waitingLinesY(360, 43), 158.5, 201.5);
    HikeMapCheck.lines(errs, "epix2", HikeMapLayout.waitingLinesY(416, 47), 184.5, 231.5);
    HikeMapCheck.lines(errs, "fenix843mm", HikeMapLayout.waitingLinesY(416, 50), 183.0, 233.0);
    HikeMapCheck.lines(errs, "fr965", HikeMapLayout.waitingLinesY(454, 53), 200.5, 253.5);
    HikeMapCheck.lines(errs, "fenix9pro51mm", HikeMapLayout.waitingLinesY(466, 53), 206.5, 259.5);
    // First height past the bound: 45 - 2 x 7 = 31 > 30.
    HikeMapCheck.lines(errs, "45 px on 390", HikeMapLayout.waitingLinesY(390, 45), 172.5, 217.5);
    var watches = [[360, 43], [416, 47], [416, 50], [454, 53], [466, 53], [390, 45],
        [260, 32], [240, 29], [390, 44], [416, 42], [156, 20]];
    for (var i = 0; i < watches.size(); i++)
    {
        HikeMapCheck.clear(errs, "clear " + watches[i], watches[i][0], watches[i][1]);
    }
    return HikeMapCheck.finish(errs, logger);
}

// Limits: no font height, zero or negative, odd screen height, a font
// taller than half the screen, a Float height.
(:test)
function testHikeMapWaitingLimits(logger)
{
    var errs = [];
    HikeMapCheck.sameAsBefore(errs, "null font height", 260, null);
    HikeMapCheck.sameAsBefore(errs, "zero font height", 260, 0);
    HikeMapCheck.sameAsBefore(errs, "negative font height", 260, -40);
    HikeMapCheck.sameAsBefore(errs, "tiny font (6 px, no ink margin)", 260, 6);
    // 30 px font, margin 4: 22 px of ink, well apart.
    HikeMapCheck.sameAsBefore(errs, "30 px font", 260, 30);
    // Odd heights: integer centre, as dc.getHeight() / 2 was.
    HikeMapCheck.sameAsBefore(errs, "odd height 241", 241, 32);
    HikeMapCheck.lines(errs, "odd height 361, 43 px", HikeMapLayout.waitingLinesY(361, 43), 158.5, 201.5);
    // Huge font: still symmetric and clear.
    HikeMapCheck.lines(errs, "200 px font on 260", HikeMapLayout.waitingLinesY(260, 200), 30.0, 230.0);
    HikeMapCheck.clear(errs, "200 px font on 260", 260, 200);
    // Float font height gives the same lines.
    HikeMapCheck.lines(errs, "43.0 px (Float)", HikeMapLayout.waitingLinesY(360, 43.0), 158.5, 201.5);
    return HikeMapCheck.finish(errs, logger);
}

} // module HikeMapLayoutTests
