using Toybox.WatchUi;
using Toybox.System;
using Toybox.Graphics;
using Toybox.System as Sys;

class PositionView extends WatchUi.View {
    var data;
    var display;

    function initialize() {
        View.initialize();
        data = new WatchData();
    }

    function onLayout(dc) {
        display = new WatchDisplay(dc);
    }

    function onShow() {
        Sys.println("PositionView shown");
    }

    function onHide() {
        Sys.println("PositionView hidden");
    }

    function onUpdate(dc) {
        if (display == null) {
            return;
        }

        // Set the device context for WatchDisplay
        display.dc = dc;

        // Set background to WHITE
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();

        // Update GPS data
        data.startMeasure();
        var position = Position.getInfo();
        if (position != null) {
            data.updateInfo(position);
        }
        data.endMeasure();

        // Get heading, latitude, and longitude
        var heading = data.getHeading();
        var trueNorth = data.getNorth();

        var lat = data.getLat();
        var lon = data.getLon();

        // Draw the compass with coordinates using WatchDisplay
        // Show the true north, latitude, and longitude
        display.compass(heading, lat, lon);   //!!!!!

        if ($.isRecordFlashActive()) {
            display.recordingStartIcon();
        }
    }
}