using Toybox.WatchUi;
using Toybox.Attention;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System as Sys;

class WatchDisplay
{
    var borderSize;
    var dc;

    // Retrieve these data from Store (https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Storage.html#getValue-instance_method)
    var climbingThreshold =  0.3;
    var sinkingThreshold  = -2.0;
    
    function initialize(deviceContext)
    {
        dc = deviceContext;
        borderSize = dc.getWidth() / 12;
    }
    
    enum {VarioSink, VarioZeroing, VarioClimb}
    var varioColor = VarioZeroing;  
    
    function start(vario)
    {
        if (vario <= sinkingThreshold)
        {
            varioColor = VarioSink;
        }
        else
        {
            if (vario >= climbingThreshold)
            {
                varioColor = VarioClimb;
            }
            else
            {
                varioColor = VarioZeroing;
            }
        }
   
        var color = Graphics.COLOR_TRANSPARENT;
    
        switch (varioColor)
        {
        case VarioSink:     color = Graphics.COLOR_RED; break;
        case VarioZeroing:  color = Graphics.COLOR_LT_GRAY; break;
        case VarioClimb:    color = Graphics.COLOR_GREEN; break;
        }
     
        // Set background color
        dc.setColor(Graphics.COLOR_TRANSPARENT, color);
        dc.clear();
    }
    
    function end()
    {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(dc.getWidth()/2, dc.getHeight()/2, dc.getWidth()/2-borderSize);
    }
    
    function waitForAltitude()
    {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_LARGE, "starting ...", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    
    // Heading in radians
    function heading(heading)
    {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var offset  = 0.5;
        
        var points  = [[-borderSize/2,-h/2+borderSize+offset],[0,-h/2],[borderSize/2,-h/2+borderSize+offset]];
            
        var pts = points.size();
        var cos = Math.cos(heading);
        var sin = Math.sin(heading);
            
        for (var i = 0; i < pts; i++)
        {
            var x0 = -points[i][0];
            var y0 = -points[i][1];
        
            var x1 = x0 * cos - y0 * sin;
            var y1 = x0 * sin + y0 * cos;
        
            points[i][0] =  w / 2 - x1;
            points[i][1] =  h / 2 - y1;
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w/2, h/2, w/2-borderSize);
        
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(points);
        
        dc.setPenWidth(2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i + 1 < pts; i++) // Do not display last line
        {
            dc.drawLine(points[i][0], points[i][1], points[(i+1)%pts][0], points[(i+1)%pts][1]);
        }
        dc.setPenWidth(1);    
    }
    
    var blink = false;
        
    function altitude(alt, recording)
    {
        var unit = $.flightAltitudeUnit(alt); // " m", none after "--" (decision of 09/10)

        var yOffset = dc.getHeight() / 2;
        var xOffset = dc.getWidth() / 2;

        var dimAlt  = dc.getTextDimensions(alt, Graphics.FONT_NUMBER_HOT) as [Lang.Number, Lang.Number];
        var dimUnit = [0, 0];
        if (unit.length() > 0)
        {
            dimUnit = dc.getTextDimensions(unit, Graphics.FONT_XTINY) as [Lang.Number, Lang.Number];
        }

        xOffset -= (dimAlt[0] + (recording ? 1.5 : 1) * dimUnit[0]) / 2;
        

        /*
        var circleX = xOffset - 10;
        if (recording)
        {
            if (blink)
            {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(circleX, yOffset, dimUnit[0] / 2);
            }
            blink = !blink;
            
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(circleX, yOffset, dimUnit[0] / 2);
            xOffset += 2 * dimUnit[0] / 3;
        } */
        
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xOffset, yOffset, Graphics.FONT_NUMBER_HOT, alt, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (unit.length() == 0)
        {
            return;
        }
        xOffset += dimAlt[0];
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xOffset, yOffset, Graphics.FONT_XTINY, unit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    
    function speed(speed)
    {
        var unit = " km/h";
    
        var yOffset = dc.getHeight() / 4;
        var xOffset = dc.getWidth() / 2;
        
        var dimSpeed  = dc.getTextDimensions(speed, Graphics.FONT_NUMBER_MILD) as [Lang.Number, Lang.Number];
        var dimUnit = dc.getTextDimensions(unit, Graphics.FONT_XTINY) as [Lang.Number, Lang.Number];
        
        xOffset -= (dimSpeed[0] + dimUnit[0]) / 2;
        // Instinct: moved left, clear of the sub-window (V1a); elsewhere unchanged.
        xOffset = $.flySpeedLineX(xOffset, dimSpeed[0] + dimUnit[0], yOffset - dimSpeed[1] / 2.0, yOffset + dimSpeed[1] / 2.0, subscreenBox());
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xOffset, yOffset, Graphics.FONT_NUMBER_MILD, speed, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        
        xOffset += dimSpeed[0];
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xOffset, yOffset, Graphics.FONT_XTINY, unit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    
    function beep(vSpeedMS)
    {
        if (Attention has :playTone && $.preferences.getBeep())
        {
            var freq = 600 + 75 * (vSpeedMS - climbingThreshold);
            freq = (freq < 600 ? 600 : (freq > 2200 ? 2200 : freq)); // clamp
        
            // http://blueflyvario.blogspot.com/2013/07/hardware-settings.html beep cadence
            // https://www.rpmsport.net/wordpress/wp-content/uploads/2015/01/Flymaster-VARIO-SD-manual-EN-v2.pdf  4.5.2
            // See also the matlab script beepDuration.m
            var dur = (vSpeedMS <= 0.0f ? 0.0f :  50.0f / ((vSpeedMS / 12.0f) + 0.1f));            
            dur = (dur < 75 ? 75 : dur);    
            
            var toneProfile =
            [
                new Attention.ToneProfile(freq, dur)
            ];
            
            Attention.playTone({:toneProfile=>toneProfile});    
        }
    }
    
    // https://www.w3schools.com/colors/colors_picker.asp
    const COLOR_LT_RED = 0xff8080; // 0xffb3b3;
    const COLOR_LT_GREEN = 0x33ff77; // 0xb3ffcc;
    
    function vario(vario)
    {
        var unit = " m/s";
    
        var yOffset = 3 * dc.getHeight() / 4;
        var xOffset = dc.getWidth() / 2;

        var color = Graphics.COLOR_TRANSPARENT;
        
        switch (varioColor)
        {
            case VarioSink:     color = COLOR_LT_RED; break;
            case VarioZeroing:  color = Graphics.COLOR_TRANSPARENT; break;
            case VarioClimb:    color = COLOR_LT_GREEN; beep(vario); break;
        }

        var text = vario < 0 ? vario.format("%.1f") : "+" + vario.format("%.1f");
        
        var dimVario = dc.getTextDimensions(text, Graphics.FONT_NUMBER_MILD) as [Lang.Number, Lang.Number];
        var dimUnit  = dc.getTextDimensions(unit, Graphics.FONT_XTINY) as [Lang.Number, Lang.Number];
        
        if (color != Graphics.COLOR_TRANSPARENT)
        {    
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            var y0 = dc.getHeight() - 1.5 * dimVario[1];
            dc.setClip(0, y0, dc.getWidth(), dc.getHeight());
            dc.fillCircle(dc.getWidth() / 2, dc.getHeight() / 2, dc.getWidth() / 2 - borderSize);
            dc.clearClip();
        }
        
        xOffset -= (dimVario[0] + dimUnit[0]) / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xOffset, yOffset, Graphics.FONT_NUMBER_MILD, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        
        xOffset += dimVario[0];
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xOffset, yOffset, Graphics.FONT_XTINY, unit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

	// Method to draw a compass with coordinates (heading will be added later)
    function compass(heading, lat, lon)
    {

        // Flip heading to match watch orientation. 
        // This is necessary because We want the cadrant to turn CCW if we turn the watch CW
        // A null heading (no GPS course yet) draws the dial without rotation.
        heading = $.compassRotation(heading);


        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2 ; // Shift compass up to make space for coordinates
        var radius = width / 2; // Compass radius

        // if (heading == 0) {
		// 	heading = 0.122173;
		// } 

		// Rotate cardinal directions and graduations based on watch orientation
		// Draw graduations around the perimeter, rotated by northAngle
		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var skipAngles = [265, 270, 275, 355, 0, 5, 85, 90, 95, 175, 180, 185];
		for (var i = 0; i < 360; i += 5) { // Draw a mark every 5 degrees
            if (skipAngles.indexOf(i) >= 0) {
                continue; // Skip marks at cardinal directions and ±5°
            }
			var angle = Math.toRadians(i) + heading; // Rotate by heading
			var innerX = centerX + (radius - 10) * Math.cos(angle);
			var innerY = centerY + (radius - 10) * Math.sin(angle);
			var outerX = centerX + radius * Math.cos(angle);
			var outerY = centerY + radius * Math.sin(angle);
			if (i % 30 == 0) {
				// Longer mark every 30 degrees
				dc.setPenWidth(5);
				innerX = centerX + (radius - 20) * Math.cos(angle);
				innerY = centerY + (radius - 20) * Math.sin(angle);
			} else {
				// Shorter mark every 5 degrees
				dc.setPenWidth(2);
			}
			dc.drawLine(outerX, outerY, innerX, innerY);
		}

		dc.setPenWidth(3); // Reset pen width
		// Draw cardinal directions (N, S, E, W), rotated by heading.
		// 18 px from the rim as before, further in where a letter would leave
		// the circle (V3a, CompassLayout.letterInset()).
		var inset = compassLetterInset();
		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
		// N at 270 degrees (rotated by heading)
		var nAngle = Math.toRadians(270) + heading;
		var nX = centerX + (radius - inset) * Math.cos(nAngle);
		var nY = centerY + (radius - inset) * Math.sin(nAngle);
		dc.drawText(nX, nY, Graphics.FONT_LARGE, "N", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

		// S at 90 degrees (rotated by heading)
		var sAngle = Math.toRadians(90) + heading;
		var sX = centerX + (radius - inset) * Math.cos(sAngle);
		var sY = centerY + (radius - inset) * Math.sin(sAngle);
		dc.drawText(sX, sY, Graphics.FONT_LARGE, "S", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

		// E at 0 degrees (rotated by heading)
		var eAngle = 0 + heading;
		var eX = centerX + (radius - inset) * Math.cos(eAngle);
		var eY = centerY + (radius - inset) * Math.sin(eAngle);
		dc.drawText(eX, eY, Graphics.FONT_LARGE, "E", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

		// W at 180 degrees (rotated by heading)
		var wAngle = Math.toRadians(180) + heading;
		var wX = centerX + (radius - inset) * Math.cos(wAngle);
		var wY = centerY + (radius - inset) * Math.sin(wAngle);
		dc.drawText(wX, wY, Graphics.FONT_LARGE, "W", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        
        // Draw red Line at 12h
		dc.setPenWidth(10);
		dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
		var innerX = centerX;
		var innerY = centerY - (radius - 20);
		var outerX = centerX;
		var outerY = centerY - radius;
		dc.drawLine(outerX, outerY, innerX, innerY);

        // Two centre lines: h/2 -+ 15 where they fit, one FONT_SMALL height
        // apart where they would overlap (V3b, HikeMapLayout.waitingLinesY(),
        // as on the hike Map page).
        var lines = compassLinesY();

        // Draw latitude and longitude if available
        if (lat != null && lon != null) {
            // Degrees, minutes, seconds with the hemisphere letter (Utils.mc)
            var latStr = $.formatLatLon(lat, true);
            var lonStr = $.formatLatLon(lon, false);

            // Draw coordinates
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                dc.getWidth() / 2,
                lines[0], // Position
                Graphics.FONT_SMALL,
				latStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.drawText(
                dc.getWidth() / 2,
                lines[1], // Position
                Graphics.FONT_SMALL,
                lonStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            Sys.println("Compass drawn, lat: " + latStr + ", lon: " + lonStr);
        } else {
            // Fallback if GPS data is unavailable
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                dc.getWidth() / 2,
                lines[0],
                Graphics.FONT_SMALL, "Waiting for", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
			dc.drawText(
                dc.getWidth() / 2,
                lines[1],
                Graphics.FONT_SMALL, "GPS", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            Sys.println("Compass drawn, waiting for GPS");
        }
    }

    // CompassLayout.letterInset() for this screen's FONT_LARGE, computed once
    // (the fonts do not change), for compass() (V3a).
    var compassInset = null;

    function compassLetterInset()
    {
        if (compassInset == null)
        {
            var letters = ["N", "S", "E", "W"];
            var dims = new [4];
            for (var i = 0; i < 4; i++)
            {
                dims[i] = dc.getTextDimensions(letters[i], Graphics.FONT_LARGE);
            }
            compassInset = CompassLayout.letterInset(dc.getFontHeight(Graphics.FONT_LARGE), dims);
        }
        return compassInset;
    }

    // HikeMapLayout.waitingLinesY() for this screen's FONT_SMALL, computed
    // once, for compass() (V3b).
    var compassLines = null;

    function compassLinesY()
    {
        if (compassLines == null)
        {
            compassLines = HikeMapLayout.waitingLinesY(dc.getHeight(), dc.getFontHeight(Graphics.FONT_SMALL));
        }
        return compassLines;
    }

    // "Recording started" banner: a green circle with a white play triangle,
    // centered on screen. Shown by every View's onUpdate() for a few seconds
    // right after SELECT starts a session -- see FlyInstrumentApp.mc's
    // recordFlashStartMs/isRecordFlashActive().
    function recordingStartIcon()
    {
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        var radius = dc.getWidth() / 5;

        var triSize = radius * 0.7;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [centerX - triSize * 0.7 - triSize * 0.05, centerY - triSize - triSize * 0.1],
            [centerX - triSize * 0.7 - triSize * 0.05, centerY + triSize + triSize * 0.1],
            [centerX + triSize + triSize * 0.1, centerY]
        ]);
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [centerX - triSize * 0.7, centerY - triSize],
            [centerX - triSize * 0.7, centerY + triSize],
            [centerX + triSize, centerY]
        ]);
    }

    // Small hand-drawn heart icon (two circles + a triangle), same technique
    // as the battery icon in time_and_battery() below -- Connect IQ has no
    // built-in icon font glyph guaranteed available across every device.
    function drawHeart(centerX, centerY, size)
    {
        var r = size / 2.0;
        dc.fillCircle(centerX - r * 0.6, centerY - r * 0.3, r * 0.7);
        dc.fillCircle(centerX + r * 0.6, centerY - r * 0.3, r * 0.7);
        dc.fillPolygon([
            [centerX - r * 1.25, centerY - r * 0.1],
            [centerX + r * 1.25, centerY - r * 0.1],
            [centerX, centerY + r * 1.3]
        ]);
    }

    // pickFont() ladder for the bottom (hero/timer) value, smallest first:
    // FONT_NUMBER_MEDIUM (the size fenix6pro uses) if it fits, else
    // FONT_NUMBER_MILD -- protects against per-device font quirks like fr55,
    // where FONT_NUMBER_MEDIUM renders wider than its whole 208px screen.
    // hikeGridSubscreen() draws the timer in pickFont()'s choice. hikeGrid()
    // only uses it as the starting index in HIKE_GRID_TIMER_FONTS, which
    // HikeGridLayout.placeTimer() may shrink further; the middle values have
    // their own ladder there (HIKE_GRID_MID_FONTS, placeColumns()). Labels
    // (FONT_XTINY) and the top value (FONT_NUMBER_MILD) have no ladder.
    const HIKE_GRID_HERO_VALUE_FONTS = [Graphics.FONT_NUMBER_MILD, Graphics.FONT_NUMBER_MEDIUM];

    (:typecheck(false))
    // See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    // Returns the largest font in `fonts` (ordered smallest to largest) for
    // which every string in `strings` fits within maxWidth x maxHeight.
    // Falls back to the smallest font if none of them fit.
    function pickFont(fonts, strings, maxWidth, maxHeight)
    {
        for (var i = fonts.size() - 1; i >= 0; i -= 1)
        {
            var fits = true;
            for (var j = 0; j < strings.size(); j += 1)
            {
                var dim = dc.getTextDimensions(strings[j], fonts[i]);
                if (dim[0] > maxWidth || dim[1] > maxHeight)
                {
                    fits = false;
                    break;
                }
            }
            if (fits)
            {
                return fonts[i];
            }
        }
        return fonts[0];
    }

    (:typecheck(false))
    // See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    // 4-field grid used by the Hiking Position and Pace pages: a full-width
    // top field (optionally with a heart icon instead of a label), a divider,
    // a two-column middle row split by a vertical divider, another divider,
    // and a big full-width bottom field for the timer -- modeled on a
    // standard Garmin data screen layout.
    //
    // Every offset below was tuned by eye against fenix6pro (260x260,
    // "REF_SIZE"), which is why they're plain pixel numbers. `scale` re-bases
    // them to whatever screen this actually is, so the same proportions --
    // gap between a label and its value, icon size, divider inset -- hold up
    // on a 163px Instinct2s and a 466px fenix9pro51mm alike, instead of
    // staying frozen in fenix6pro pixels while the fonts around them grow or
    // shrink with the device.
    //
    // Watches with a sub-window (Instinct) use hikeGridSubscreen() instead:
    // the layout below put texts in the sub-window and over each other there.
    function hikeGrid(topLabel, topValue, showHeartIcon, leftLabel, leftValue, rightLabel, rightValue, bottomLabel, bottomValue)
    {
        if (!hikeSubLayoutDone)
        {
            hikeSubLayout = subscreenHikeLayout();
            hikeSubLayoutDone = true;
        }
        if (hikeSubLayout != null)
        {
            hikeGridSubscreen(topLabel, topValue, showHeartIcon, leftLabel, leftValue, rightLabel, rightValue, bottomLabel, bottomValue);
            return;
        }

        var w = dc.getWidth();
        var h = dc.getHeight();
        if (hikeScreen == null)
        {
            hikeScreen = [w, h, Sys.getDeviceSettings().screenShape == Sys.SCREEN_SHAPE_ROUND];
        }
        var refSize = 260.0;
        var scale = (w < h ? w : h) / refSize;

        var centerX = w / 2;
        var marginX = w * 0.1;
        var left = marginX;
        var right = w - marginX;
        var fullWidth = right - left;

        var y0 = h * 0.10;
        var y1 = h * 0.35; // divider 1
        var y2 = h * 0.65; // divider 2
        var y3 = h * 0.90;

        var dividerPenWidth = (2 * scale).toNumber();
        if (dividerPenWidth < 1)
        {
            dividerPenWidth = 1;
        }

        // Top field
        var topCenterY = (y0 + y1) / 2;
        if (showHeartIcon)
        {
            var valueWidth = dc.getTextWidthInPixels(topValue, Graphics.FONT_NUMBER_MILD);
            var heartSize = 16 * scale;
            dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            drawHeart(centerX - valueWidth / 2 - heartSize, topCenterY, heartSize);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX + 10 * scale, topCenterY, Graphics.FONT_NUMBER_MILD, topValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        else
        {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, topCenterY - 18 * scale, Graphics.FONT_XTINY, topLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, topCenterY + 12 * scale, Graphics.FONT_NUMBER_MILD, topValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(dividerPenWidth);
        dc.drawLine(left, y1, right, y1);

        // Middle two columns: NUMBER_MILD at the tuned centres when both
        // values fit; else spread about the divider, or a smaller font
        // (HikeGridLayout.placeColumns()). Each label follows its value: a
        // spread is only taken if the labels fit too.
        var midCenterY = (y1 + y2) / 2;
        var colOffset = 5 * scale;
        var midValueY = midCenterY + 12 * scale;
        var midLabelY = midCenterY - 28 * scale;
        var labelDims = textDims([Graphics.FONT_XTINY], leftLabel, rightLabel)[0];
        var cols = HikeGridLayout.placeColumns(textDims(HIKE_GRID_MID_FONTS, leftValue, rightValue),
            [(left + centerX) / 2 - colOffset, (centerX + right) / 2 + colOffset],
            midValueY, hikeScreen, w * HikeGridLayout.MIN_GAP_SHARE,
            [labelDims[0], labelDims[1], labelDims[2], midLabelY]);
        var midValueFont = HIKE_GRID_MID_FONTS[cols[0]];
        var colLeftX = cols[1];
        var colRightX = cols[2];

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colLeftX, midLabelY, Graphics.FONT_XTINY, leftLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(colRightX, midLabelY, Graphics.FONT_XTINY, rightLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colLeftX, midValueY, midValueFont, leftValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(colRightX, midValueY, midValueFont, rightValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(centerX, y1 + 8 * scale, centerX, y2 - 8 * scale);
        dc.drawLine(left, y2, right, y2);
        dc.setPenWidth(1);

        // Bottom field (timer) -- biggest text on the page. pickFont()'s
        // font at the tuned position when it fits in the screen and clear
        // of its label; else a smaller font, or just below the label
        // (HikeGridLayout.placeTimer()).
        var bottomCenterY = (y2 + y3) / 2;
        var bottomLabelY = y2 + 14 * scale;
        var bottomValueFont = pickFont(HIKE_GRID_HERO_VALUE_FONTS, [bottomValue], fullWidth, 74 * scale);
        var labelDim = dc.getTextDimensions(bottomLabel, Graphics.FONT_XTINY);
        var timer = HikeGridLayout.placeTimer(textDims(HIKE_GRID_TIMER_FONTS, bottomValue, null),
            bottomValueFont == Graphics.FONT_NUMBER_MEDIUM ? 0 : 1, bottomCenterY + 14 * scale,
            HikeGridLayout.inkBox(centerX, bottomLabelY, labelDim[0], labelDim[1]), hikeScreen, fullWidth);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, bottomLabelY, Graphics.FONT_XTINY, bottomLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, timer[1], HIKE_GRID_TIMER_FONTS[timer[0]], bottomValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // [w, h, round] of this screen, for HikeGridLayout (set once).
    var hikeScreen = null;

    // Font ladders of hikeGrid(), largest first: the timer starts at
    // pickFont()'s choice (index 0 or 1), the middle values at NUMBER_MILD.
    // The smaller ones are only used where the tuned layout does not fit.
    const HIKE_GRID_TIMER_FONTS = [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD,
        Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL];
    const HIKE_GRID_MID_FONTS = [Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE,
        Graphics.FONT_MEDIUM, Graphics.FONT_SMALL];

    // getTextDimensions() of `a` in each font: [width, height]; with `b`
    // too: [width of a, width of b, larger height].
    function textDims(fonts, a, b)
    {
        var out = new [fonts.size()];
        for (var i = 0; i < fonts.size(); i += 1)
        {
            var da = dc.getTextDimensions(a, fonts[i]);
            if (b == null)
            {
                out[i] = da;
            }
            else
            {
                var db = dc.getTextDimensions(b, fonts[i]);
                out[i] = [da[0], db[0], da[1] > db[1] ? da[1] : db[1]];
            }
        }
        return out;
    }

    // HikeGridLayout.compute() result for this screen, computed once (the
    // sub-window and the fonts do not change): null on watches without a
    // sub-window, which keep the hikeGrid() layout above.
    var hikeSubLayout = null;
    var hikeSubLayoutDone = false;

    (:typecheck(false))
    // See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    // WatchUi.getSubscreen() (API 3.2.7, null without a sub-window) turned
    // into a HikeGridLayout, or null.
    function subscreenHikeLayout()
    {
        if (!(WatchUi has :getSubscreen))
        {
            return null;
        }
        var b = WatchUi.getSubscreen();
        if (b == null || b.width == null || b.height == null)
        {
            return null;
        }
        var w = dc.getWidth();
        var h = dc.getHeight();
        var sub = [b.x == null ? 0 : b.x, b.y == null ? 0 : b.y, b.width, b.height];
        var round = Sys.getDeviceSettings().screenShape == Sys.SCREEN_SHAPE_ROUND;
        return HikeGridLayout.compute(w, h, round, sub, w * 0.1,
            [dc.getFontHeight(Graphics.FONT_XTINY), Graphics.getFontAscent(Graphics.FONT_XTINY)],
            [dc.getFontHeight(Graphics.FONT_NUMBER_MILD), Graphics.getFontAscent(Graphics.FONT_NUMBER_MILD)]);
    }

    // WatchUi.getSubscreen() as [x, y, width, height], read once (it does not
    // change), for the flight page speed line (V1a). null without the API
    // (CIQ < 3.2.7: fenix5...) or without a sub-window.
    var subBox = null;
    var subBoxDone = false;

    (:typecheck(false))
    // See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    function subscreenBox()
    {
        if (!subBoxDone)
        {
            subBoxDone = true;
            if (WatchUi has :getSubscreen)
            {
                var b = WatchUi.getSubscreen();
                if (b != null && b.width != null && b.height != null)
                {
                    subBox = [b.x == null ? 0 : b.x, b.y == null ? 0 : b.y, b.width, b.height];
                }
            }
        }
        return subBox;
    }

    (:typecheck(false))
    // See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    // hikeGrid() on a watch with a sub-window, positions from hikeSubLayout
    // (HikeGridLayout.compute(); a field, not an argument: some targets
    // allow 9 arguments at most): same fields, fonts and colours, the top
    // field beside the sub-window, the rest below it. Texts are drawn from
    // their top (no TEXT_JUSTIFY_VCENTER).
    function hikeGridSubscreen(topLabel, topValue, showHeartIcon, leftLabel, leftValue, rightLabel, rightValue, bottomLabel, bottomValue)
    {
        var l = hikeSubLayout;
        var w = dc.getWidth();
        var h = dc.getHeight();
        var scale = (w < h ? w : h) / 260.0;
        var centerX = w / 2;
        var marginX = w * 0.1;
        var left = marginX;
        var right = w - marginX;
        var C = Graphics.TEXT_JUSTIFY_CENTER;
        var topX = l[HikeGridLayout.TOP_X];

        var dividerPenWidth = (2 * scale).toNumber();
        if (dividerPenWidth < 1)
        {
            dividerPenWidth = 1;
        }

        // Top field, beside the sub-window
        if (showHeartIcon)
        {
            var valueWidth = dc.getTextWidthInPixels(topValue, Graphics.FONT_NUMBER_MILD);
            var heartSize = 16 * scale;
            var y = l[HikeGridLayout.TOP_VALUE_ONLY_Y];
            dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            drawHeart(topX - valueWidth / 2 - heartSize, y + dc.getFontHeight(Graphics.FONT_NUMBER_MILD) / 2, heartSize);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(topX + 10 * scale, y, Graphics.FONT_NUMBER_MILD, topValue, C);
        }
        else
        {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(topX, l[HikeGridLayout.TOP_LABEL_Y], Graphics.FONT_XTINY, topLabel, C);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(topX, l[HikeGridLayout.TOP_VALUE_Y], Graphics.FONT_NUMBER_MILD, topValue, C);
        }

        // Dividers in the empty leading above the middle and bottom labels
        var y1 = l[HikeGridLayout.MID_LABEL_Y];
        var y2 = l[HikeGridLayout.BOT_LABEL_Y];
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(dividerPenWidth);
        dc.drawLine(left, y1, right, y1);

        // Middle two columns, below the sub-window
        var colLeftX = l[HikeGridLayout.COL_LEFT_X];
        var colRightX = l[HikeGridLayout.COL_RIGHT_X];
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colLeftX, y1, Graphics.FONT_XTINY, leftLabel, C);
        dc.drawText(colRightX, y1, Graphics.FONT_XTINY, rightLabel, C);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colLeftX, l[HikeGridLayout.MID_VALUE_Y], Graphics.FONT_NUMBER_MILD, leftValue, C);
        dc.drawText(colRightX, l[HikeGridLayout.MID_VALUE_Y], Graphics.FONT_NUMBER_MILD, rightValue, C);

        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(centerX, y1 + 8 * scale, centerX, y2 - 8 * scale);
        dc.drawLine(left, y2, right, y2);
        dc.setPenWidth(1);

        // Bottom field (timer): FONT_NUMBER_MEDIUM if it fits in the width
        // and in the height left below its label, else FONT_NUMBER_MILD.
        var botValueY = l[HikeGridLayout.BOT_VALUE_Y];
        var bottomValueFont = pickFont(HIKE_GRID_HERO_VALUE_FONTS, [bottomValue], right - left, h - botValueY);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y2, Graphics.FONT_XTINY, bottomLabel, C);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, botValueY, bottomValueFont, bottomValue, C);
    }

    // Live breadcrumb map: draws the recorded trail (a ring buffer, oldest-to-newest
    // starting at writeIndex once it has wrapped) plus a heading-oriented marker at
    // the current position, scaled and centered to fit whatever's been recorded so far.
    // curLat / curLon are null without a usable fix: the trail is then drawn alone,
    // and "Waiting for GPS" only shows when there is no trail either (mapDrawMode()).
    (:typecheck(false))
    // See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    function map(lats, lons, count, writeIndex, curLat, curLon, heading)
    {
        var mode = $.mapDrawMode(count, curLat != null && curLon != null);
        if (mode == :waiting)
        {
            // h/2 -+ 15 where the two lines fit, one font height apart where
            // they would overlap (big FONT_SMALL: fr265s, fr965, epix2,
            // fenix 8 / 9...; HikeMapLayout.waitingLinesY()).
            var lines = HikeMapLayout.waitingLinesY(dc.getHeight(), dc.getFontHeight(Graphics.FONT_SMALL));
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth() / 2, lines[0], Graphics.FONT_SMALL, "Waiting for", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(dc.getWidth() / 2, lines[1], Graphics.FONT_SMALL, "GPS", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var hasCurrent = (mode == :trailAndMarker);

        var capacity = lats.size();
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        var screenRadius = dc.getWidth() / 2 - borderSize;

        // Longitude-compressed local projection (equirectangular), in degrees of
        // latitude on both axes, centered on the bounding box of the trail plus
        // the current position (mapProjectionCenter()): `scale` below is in
        // pixels per degree of latitude (mapPixelsPerDegree(); the scale bar
        // converts it to m/px with metersPerPixelFromScale()).
        var center = $.mapProjectionCenter(lats, lons, count, writeIndex, curLat, curLon);
        var centerLat = center[0];
        var centerLon = center[1];
        var cosLat = center[2];
        var curDx = 0.0, curDy = 0.0;
        if (hasCurrent)
        {
            curDx = (curLon - centerLon) * cosLat;
            curDy = curLat - centerLat;
        }

        var scale = $.mapPixelsPerDegree(lats, lons, count, writeIndex, curLat, curLon, center, screenRadius);

        // Trail line, oldest to newest, connected through to the current position.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        var prevX = null, prevY = null;
        for (var i = 0; i < count; i++)
        {
            var idx = (writeIndex - count + i + capacity) % capacity;
            var dx = (lons[idx] - centerLon) * cosLat;
            var dy = lats[idx] - centerLat;
            var x = centerX + dx * scale;
            var y = centerY - dy * scale;
            if (prevX != null)
            {
                dc.drawLine(prevX, prevY, x, y);
            }
            prevX = x;
            prevY = y;
        }

        // Scale bar at the bottom, in the border ring below the fitted trail:
        // a round length (pickScaleBar) at most a third of the screen wide,
        // none when no round length suits the current zoom.
        var bar = $.pickScaleBar($.metersPerPixelFromScale(scale), dc.getWidth() / 3);
        if (bar != null)
        {
            var barY = centerY + screenRadius + borderSize / 2;
            var barLeft = centerX - bar[1] / 2;
            var barRight = barLeft + bar[1];
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(barLeft, barY, barRight, barY);
            dc.drawLine(barLeft, barY, barLeft, barY - 5);
            dc.drawLine(barRight, barY, barRight, barY - 5);
            dc.drawText(centerX, barY - 3 - dc.getFontHeight(Graphics.FONT_XTINY) / 2, Graphics.FONT_XTINY, $.formatScaleBarLabel(bar[0]), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
        }

        if (!hasCurrent)
        {
            // Trail alone, no marker. A single point draws no line: show it
            // as a small dot so the page isn't blank.
            if (count == 1 && prevX != null)
            {
                dc.fillCircle(prevX, prevY, 3);
            }
            dc.setPenWidth(1);
            return;
        }

        var curX = centerX + curDx * scale;
        var curY = centerY - curDy * scale;
        if (prevX != null)
        {
            dc.drawLine(prevX, prevY, curX, curY);
        }
        dc.setPenWidth(1);

        // Current position marker: a small heading-oriented arrow, or a plain dot
        // if heading isn't available yet.
        if (heading != null)
        {
            var size = 8;
            var points = [[-size / 2, size], [0, -size], [size / 2, size]];
            var cos = Math.cos(heading);
            var sin = Math.sin(heading);

            var poly = new [3];
            for (var i = 0; i < 3; i++)
            {
                var x0 = points[i][0];
                var y0 = points[i][1];
                var rx = x0 * cos - y0 * sin;
                var ry = x0 * sin + y0 * cos;
                poly[i] = [curX + rx, curY + ry];
            }

            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(poly);
        }
        else
        {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(curX, curY, 5);
        }
    }

    function time_and_battery(timeStr, battery){
        // Draw time in BLACK with a large font, centered in the middle of the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
   
        // Draw the main text on top
        dc.drawText(
            centerX,
            centerY,
            Graphics.FONT_NUMBER_HOT,
            timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

    
        var batteryStr = battery.toString() + "%";
        var batteryTextWidth = dc.getTextWidthInPixels(batteryStr, Graphics.FONT_TINY);
        // Below the time: h/2 + 50 as before, lower where the time's font is
        // too tall for it (V2, AMOLED 360-466 px). Icon left of the text.
        var place = $.timeBatteryLayout(dc.getWidth(), dc.getHeight(),
            dc.getFontHeight(Graphics.FONT_NUMBER_HOT), dc.getFontHeight(Graphics.FONT_TINY), batteryTextWidth);
        var batteryX = place[0];
        var batteryY = place[1];

        // Draw battery icon (rectangle with a tip and fill level)
        var iconX = place[2];
        var iconY = place[3];
        var iconWidth = 12;
        var iconHeight = 6;
        var tipWidth = 2;
        var fillLevel = (battery / 100.0) * (iconWidth - 2); // Proportional fill based on battery percentage

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        // Draw battery outline (rectangle + tip)
        dc.drawRectangle(iconX, iconY, iconWidth, iconHeight);
        dc.fillRectangle(iconX + iconWidth, iconY + 1, tipWidth, iconHeight - 2);
        // Draw battery fill level
        if (fillLevel > 0) {
            dc.fillRectangle(iconX + 1, iconY + 1, fillLevel.toNumber(), iconHeight - 2);
        }

        // Draw battery percentage text to the right of the icon
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            batteryX, // right of the icon
            batteryY,
            Graphics.FONT_TINY,
            batteryStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}