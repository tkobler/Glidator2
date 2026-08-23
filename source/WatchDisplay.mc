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
        var unit = " m";
    
        var yOffset = dc.getHeight() / 2;
        var xOffset = dc.getWidth() / 2;
        
        var dimAlt  = dc.getTextDimensions(alt, Graphics.FONT_NUMBER_HOT) as [Lang.Number, Lang.Number];
        var dimUnit = dc.getTextDimensions(unit, Graphics.FONT_XTINY) as [Lang.Number, Lang.Number];
        
        xOffset -= (dimAlt[0] + (recording ? 1.5 : 1) * dimUnit[0]) / 2;
        
        if (recording)
        {
            if (blink)
            {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(xOffset, yOffset, dimUnit[0] / 2);
            }
            blink = !blink;
            
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(xOffset, yOffset, dimUnit[0] / 2);
            xOffset += 2 * dimUnit[0] / 3;
        }
        
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xOffset, yOffset, Graphics.FONT_NUMBER_HOT, alt, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        
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
            var y0 = 3 * dc.getHeight() / 4 - dimVario[1];
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
       heading = -heading; 


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
		// Draw cardinal directions (N, S, E, W), rotated by heading
		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
		// N at 270 degrees (rotated by heading)
		var nAngle = Math.toRadians(270) + heading;
		var nX = centerX + (radius - 18) * Math.cos(nAngle);
		var nY = centerY + (radius - 18) * Math.sin(nAngle);
		dc.drawText(nX, nY, Graphics.FONT_LARGE, "N", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

		// S at 90 degrees (rotated by heading)
		var sAngle = Math.toRadians(90) + heading;
		var sX = centerX + (radius - 18) * Math.cos(sAngle);
		var sY = centerY + (radius - 18) * Math.sin(sAngle);
		dc.drawText(sX, sY, Graphics.FONT_LARGE, "S", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

		// E at 0 degrees (rotated by heading)
		var eAngle = 0 + heading;
		var eX = centerX + (radius - 18) * Math.cos(eAngle);
		var eY = centerY + (radius - 18) * Math.sin(eAngle);
		dc.drawText(eX, eY, Graphics.FONT_LARGE, "E", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

		// W at 180 degrees (rotated by heading)
		var wAngle = Math.toRadians(180) + heading;
		var wX = centerX + (radius - 18) * Math.cos(wAngle);
		var wY = centerY + (radius - 18) * Math.sin(wAngle);
		dc.drawText(wX, wY, Graphics.FONT_LARGE, "W", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        
        // Draw red Line at 12h
		dc.setPenWidth(10);
		dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
		var innerX = centerX;
		var innerY = centerY - (radius - 20);
		var outerX = centerX;
		var outerY = centerY - radius;
		dc.drawLine(outerX, outerY, innerX, innerY);

        // Draw latitude and longitude if available
        if (lat != null && lon != null) {
            // Convert latitude and longitude to degrees, minutes, seconds format
            var latDeg = lat.toNumber();
            var latMin = ((lat - latDeg) * 60).abs();
            var latSec = ((latMin - latMin.toNumber()) * 60).abs();
            var latStr = latDeg + "°" + latMin.format("%02d") + "'" + latSec.format("%.1f") + "\"" + (lat >= 0 ? "N" : "S");

            var lonDeg = lon.toNumber();
            var lonMin = ((lon - lonDeg) * 60).abs();
            var lonSec = ((lonMin - lonMin.toNumber()) * 60).abs();
            var lonStr = lonDeg + "°" + lonMin.format("%02d") + "'" + lonSec.format("%.1f") + "\"" + (lon >= 0 ? "E" : "W");

            // Draw coordinates
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 - 15, // Position
                Graphics.FONT_SMALL, 
				latStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 + 15, // Position
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
                dc.getHeight() / 2 - 15,
                Graphics.FONT_SMALL, "Waiting for", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
			dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 + 15,
                Graphics.FONT_SMALL, "GPS", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            Sys.println("Compass drawn, waiting for GPS");
        }
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

    (:typecheck(false))
    // See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    // 4-field grid used by the Hiking Position and Pace pages: a full-width
    // top field (optionally with a heart icon instead of a label), a divider,
    // a two-column middle row split by a vertical divider, another divider,
    // and a big full-width bottom field for the timer -- modeled on a
    // standard Garmin data screen layout.
    function hikeGrid(topLabel, topValue, showHeartIcon, leftLabel, leftValue, rightLabel, rightValue, bottomLabel, bottomValue)
    {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var centerX = w / 2;
        var marginX = w * 0.1;
        var left = marginX;
        var right = w - marginX;

        var y0 = h * 0.10;
        var y1 = h * 0.35; // divider 1
        var y2 = h * 0.65; // divider 2
        var y3 = h * 0.90;

        // Top field
        var topCenterY = (y0 + y1) / 2;
        if (showHeartIcon)
        {
            var valueWidth = dc.getTextWidthInPixels(topValue, Graphics.FONT_NUMBER_MILD);
            dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            drawHeart(centerX - valueWidth / 2 - 16, topCenterY, 16);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX + 10, topCenterY, Graphics.FONT_NUMBER_MILD, topValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        else
        {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, topCenterY - 18, Graphics.FONT_XTINY, topLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, topCenterY + 12, Graphics.FONT_NUMBER_MILD, topValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(left, y1, right, y1);

        // Middle two columns
        var midCenterY = (y1 + y2) / 2;
        var colLeftX = (left + centerX) / 2 - 5;
        var colRightX = (centerX + right) / 2 + 5;

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colLeftX, midCenterY - 28, Graphics.FONT_XTINY, leftLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(colRightX, midCenterY - 28, Graphics.FONT_XTINY, rightLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colLeftX, midCenterY + 12, Graphics.FONT_NUMBER_MILD, leftValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(colRightX, midCenterY + 12, Graphics.FONT_NUMBER_MILD, rightValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(centerX, y1 + 8, centerX, y2 - 8);
        dc.drawLine(left, y2, right, y2);
        dc.setPenWidth(1);

        // Bottom field (timer) -- biggest text on the page
        var bottomCenterY = (y2 + y3) / 2;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y2 + 14, Graphics.FONT_XTINY, bottomLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, bottomCenterY + 14, Graphics.FONT_NUMBER_MEDIUM, bottomValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Live breadcrumb map: draws the recorded trail (a ring buffer, oldest-to-newest
    // starting at writeIndex once it has wrapped) plus a heading-oriented marker at
    // the current position, scaled and centered to fit whatever's been recorded so far.
    (:typecheck(false))
    // See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    function map(lats, lons, count, writeIndex, curLat, curLon, heading)
    {
        if (curLat == null || curLon == null)
        {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - 15, Graphics.FONT_SMALL, "Waiting for", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 + 15, Graphics.FONT_SMALL, "GPS", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var capacity = lats.size();
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        var screenRadius = dc.getWidth() / 2 - borderSize;

        // Bounding box (in degrees) over the trail plus the current position.
        var minLat = curLat, maxLat = curLat, minLon = curLon, maxLon = curLon;
        for (var i = 0; i < count; i++)
        {
            var idx = (writeIndex - count + i + capacity) % capacity;
            var lat = lats[idx];
            var lon = lons[idx];
            if (lat < minLat) { minLat = lat; }
            if (lat > maxLat) { maxLat = lat; }
            if (lon < minLon) { minLon = lon; }
            if (lon > maxLon) { maxLon = lon; }
        }

        var centerLat = (minLat + maxLat) / 2.0;
        var centerLon = (minLon + maxLon) / 2.0;
        var cosLat = Math.cos(Math.toRadians(centerLat));

        // Longitude-compressed local projection (equirectangular); the scale unit
        // doesn't matter since it only feeds a fit-to-screen ratio below.
        var maxRange = 0.0001; // floor avoids a divide-by-zero when stationary
        for (var i = 0; i < count; i++)
        {
            var idx = (writeIndex - count + i + capacity) % capacity;
            var dx = (lons[idx] - centerLon) * cosLat;
            var dy = lats[idx] - centerLat;
            var r = (dx.abs() > dy.abs()) ? dx.abs() : dy.abs();
            if (r > maxRange) { maxRange = r; }
        }
        var curDx = (curLon - centerLon) * cosLat;
        var curDy = curLat - centerLat;
        var curR = (curDx.abs() > curDy.abs()) ? curDx.abs() : curDy.abs();
        if (curR > maxRange) { maxRange = curR; }

        var scale = (screenRadius * 0.85) / maxRange;

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
        var batteryY = dc.getHeight() / 2 + 50; // Position below the time

        // Draw battery icon (rectangle with a tip and fill level)
        var iconX = centerX - (batteryTextWidth / 2) - 10; // Position to the left of the text
        var iconY = batteryY - 2; // Align vertically with the text
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
            centerX + 10, // Adjust to the right of the icon
            batteryY,
            Graphics.FONT_TINY,
            batteryStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}