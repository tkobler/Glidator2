using Toybox.WatchUi;
using Toybox.System;
using Toybox.Graphics;
using Toybox.System as Sys;

class TimeView extends WatchUi.View {
    var display;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        display = new WatchDisplay(dc);
    }

    function onShow() {
        Sys.println("TimeView shown");
    }

    function onHide() {
        Sys.println("TimeView hidden");
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

        // Get current time
        var now = System.getClockTime();
        var timeStr = now.hour.format("%02d") + ":" + now.min.format("%02d");

        // Get battery level
        var battery = (System.getSystemStats().battery instanceof Lang.Float) ? 
              System.getSystemStats().battery.toNumber() : 
              System.getSystemStats().battery;

        display.time_and_battery(timeStr, battery);

        if ($.isRecordFlashActive()) {
            display.recordingStartIcon();
        }
    }
}