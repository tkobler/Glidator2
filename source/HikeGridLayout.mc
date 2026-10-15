using Toybox.Math;

// --------------------------------------------------------------------------------
// Layout of WatchDisplay.hikeGrid() (hike Position and Pace pages), pure
// functions of the screen size, the sub-window rectangle and the font
// metrics, so that they are unit tested (TestsHikeGrid.mc) without a Dc:
// - applies() / compute(): watches with a round sub-window
//   (WatchUi.getSubscreen(): Instinct 2, 2S, E...);
// - placeTimer() / placeColumns(): every other watch, which keeps the
//   original hikeGrid() layout except for the timer or the middle values
//   that would not fit (see below).
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

    // --- Fit of the texts on screens without a sub-window ------------------
    // hikeGrid() keeps its tuned positions and fonts wherever its texts fit;
    // placeTimer() and placeColumns() only change the timer and the two
    // middle values when they would leave the screen (circle) or overlap.
    // "Fit" uses the ink model and the rules of the display bench
    // (TestsLayout.mc: LAYOUT_INK_K, onScreen(), overlaps()), so that a
    // layout is changed exactly where the bench finds a defect. Texts are
    // drawn TEXT_JUSTIFY_CENTER | TEXT_JUSTIFY_VCENTER. screen: [w, h,
    // round]; dims: getTextDimensions() per font of a ladder.

    // Empty leading of a text box, as a share of its height, removed at the
    // top and at the bottom (digits and capitals do not fill the box).
    const INK_K = 0.16;

    // Smallest gap between two spread middle values, and between them and
    // the edge, as a share of the screen width.
    const MIN_GAP_SHARE = 0.02;

    // Ink box [x0, y0, x1, y1] of a tw x th text centred on (x, y): the
    // text box less floor(INK_K x th) at the top and at the bottom and
    // 1 px on each side.
    function inkBox(x, y, tw, th)
    {
        var m = (INK_K * th).toNumber();
        return [x - tw / 2.0 + 1, y - th / 2.0 + m, x + tw / 2.0 - 1, y + th / 2.0 - m];
    }

    // True if the 4 corners of box b are on the screen: within the circle
    // of radius w/2 + 1 about the centre on a round screen, within
    // [0, w] x [0, h] otherwise.
    function inScreen(b, screen)
    {
        var w = screen[0];
        var h = screen[1];
        if (!screen[2])
        {
            return b[0] >= 0 && b[1] >= 0 && b[2] <= w && b[3] <= h;
        }
        // The farthest corner takes the farthest x and the farthest y.
        var dx = farthest(b[0], b[2], w / 2.0);
        var dy = farthest(b[1], b[3], h / 2.0);
        var r = w / 2.0 + 1;
        return dx * dx + dy * dy <= r * r;
    }

    function farthest(a, b, c)
    {
        var da = (a - c).abs();
        var db = (b - c).abs();
        return da > db ? da : db;
    }

    // True if boxes a and b share an area (touching is not overlapping).
    function overlap(a, b)
    {
        var ow = (a[2] < b[2] ? a[2] : b[2]) - (a[0] > b[0] ? a[0] : b[0]);
        var oh = (a[3] < b[3] ? a[3] : b[3]) - (a[1] > b[1] ? a[1] : b[1]);
        return ow > 0 && oh > 0;
    }

    // Timer (bottom value), centred on x = w / 2: [font index, y].
    // dims[i] = [width, height] of the timer in font i of the ladder
    // (largest first), first = the font hikeGrid() chose (pickFont()), y its
    // tuned position, label = ink box of the "TIMER" label above it, maxW
    // the widest a smaller font may be. The default (first, y) is kept if
    // it is on the screen and clear of the label. Otherwise, from font
    // `first` down (never a larger one): the first font that fits at y, or
    // just below the label (ink top GAP px under the label's ink); if none
    // does, the smallest font just below the label.
    function placeTimer(dims, first, y, label, screen, maxW)
    {
        if (dims == null || first == null || first < 0 || first >= dims.size())
        {
            return [first, y];
        }
        if (timerFits(dims[first], y, label, screen))
        {
            return [first, y];
        }
        var n = dims.size();
        for (var i = first; i < n; i++)
        {
            var d = dims[i];
            if (d[0] > maxW)
            {
                continue;
            }
            if (timerFits(d, y, label, screen))
            {
                return [i, y];
            }
            var below = belowLabel(d, y, label);
            if (timerFits(d, below, label, screen))
            {
                return [i, below];
            }
        }
        return [n - 1, belowLabel(dims[n - 1], y, label)];
    }

    // y of a text of dims d whose ink starts GAP px below the label's ink
    // (y itself without a label).
    function belowLabel(d, y, label)
    {
        if (label == null)
        {
            return y;
        }
        return label[3] + GAP + d[1] / 2.0 - (INK_K * d[1]).toNumber();
    }

    function timerFits(d, y, label, screen)
    {
        var b = inkBox(screen[0] / 2, y, d[0], d[1]);
        return inScreen(b, screen) && (label == null || !overlap(b, label));
    }

    // Two middle values on the row y: [font index, left x, right x].
    // dims[i] = [left width, right width, height] in font i of the ladder
    // (largest first, font 0 the default), xs = [left x, right x] their
    // tuned centres. For each font in turn: the tuned centres if both values
    // are on the screen and clear of each other; else the two values
    // spread symmetrically about the screen centre (the divider), the gap
    // between them equal to the room left beside the wider one, at least
    // minGap. If no font fits, the smallest at the tuned centres.
    // labels = [left width, right width, height, y] of the two labels
    // (FONT_XTINY), drawn above and centred on their values: a spread is
    // only taken if both labels, moved with their values, are on the
    // screen, clear of each other and of both values; else the next font
    // is tried. null (or not 4 items): labels not checked. The tuned
    // centres never check the labels, so the original layout is kept.
    function placeColumns(dims, xs, y, screen, minGap, labels)
    {
        var lab = (labels != null && labels.size() == 4) ? labels : null;
        if (dims == null || dims.size() == 0)
        {
            return [0, xs[0], xs[1]];
        }
        var cx = screen[0] / 2.0;
        for (var i = 0; i < dims.size(); i++)
        {
            var d = dims[i];
            if (columnsFit(d, xs[0], xs[1], y, screen))
            {
                return [i, xs[0], xs[1]];
            }
            // Half width of the screen on the rows of the ink, at its row
            // farthest from the centre.
            var dy = (y - screen[1] / 2.0).abs() + d[2] / 2.0 - (INK_K * d[2]).toNumber();
            var half = chordHalf(dy, screen);
            var inkL = d[0] - 2;
            var inkR = d[1] - 2;
            var g = 2 * (half - (inkL > inkR ? inkL : inkR)) / 3.0;
            if (g >= minGap)
            {
                var xl = cx - g / 2.0 - inkL / 2.0;
                var xr = cx + g / 2.0 + inkR / 2.0;
                if (columnsFit(d, xl, xr, y, screen) && labelsFit(lab, d, xl, xr, y, screen))
                {
                    return [i, xl, xr];
                }
            }
        }
        return [dims.size() - 1, xs[0], xs[1]];
    }

    function columnsFit(d, xl, xr, y, screen)
    {
        var a = inkBox(xl, y, d[0], d[2]);
        var b = inkBox(xr, y, d[1], d[2]);
        return !overlap(a, b) && inScreen(a, screen) && inScreen(b, screen);
    }

    // True if the labels centred on xl and xr (labels: see placeColumns(),
    // null: not checked) are on the screen, clear of each other and of the
    // two values of dims d on the row y.
    function labelsFit(labels, d, xl, xr, y, screen)
    {
        if (labels == null)
        {
            return true;
        }
        var la = inkBox(xl, labels[3], labels[0], labels[2]);
        var lb = inkBox(xr, labels[3], labels[1], labels[2]);
        if (overlap(la, lb) || !inScreen(la, screen) || !inScreen(lb, screen))
        {
            return false;
        }
        var va = inkBox(xl, y, d[0], d[2]);
        var vb = inkBox(xr, y, d[1], d[2]);
        return !overlap(la, va) && !overlap(la, vb) && !overlap(lb, va) && !overlap(lb, vb);
    }

    // Half width of the screen at dy px from its centre row: w / 2 on a
    // non-round screen, the half chord of the circle of radius w/2 + 1
    // otherwise (0 beyond it).
    function chordHalf(dy, screen)
    {
        if (!screen[2])
        {
            return screen[0] / 2.0;
        }
        var r = screen[0] / 2.0 + 1;
        if (dy >= r)
        {
            return 0.0;
        }
        return Math.sqrt(r * r - dy * dy);
    }
}
