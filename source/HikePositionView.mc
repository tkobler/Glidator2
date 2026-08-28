using Toybox.WatchUi;
using Toybox.System;
using Toybox.Graphics;
using Toybox.Math;

// Render-only, like HikeMapView: reads app.mainView.data, which is kept
// continuously fresh every ~1Hz cycle by FlyInstrumentApp.onSensor()
// regardless of which page is on screen. Polling independently here (an
// earlier version of this file did) would let a page-local altitude-delta
// state go stale while the user is on a different page, causing a spurious
// jump the next time this page is shown -- reusing the always-on instance
// avoids that and avoids a redundant set of GPS/Activity queries every cycle.
class HikePositionView extends WatchUi.View {
    var app;
    var display;

    function initialize(appInstance) {
        View.initialize();
        app = appInstance;
    }

    function onLayout(dc) {
        display = new WatchDisplay(dc);
    }

    function onShow() {
    }

    function onHide() {
    }

    function onUpdate(dc) {
        if (display == null) {
            return;
        }

        display.dc = dc;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();

        var data = app.mainView.data;

        var altitude = data.getAltitude();
        var altStr = (altitude == null) ? "--" : Math.round(altitude).toNumber().toString(); // m

        var hasSession = $.hasActiveSession();

        var ascent = data.getTotalAscent();
        var ascentStr = (!hasSession || ascent == null) ? "--" : Math.round(ascent).toNumber().toString(); // m

        var distance = data.getDistance();
        var distStr = (!hasSession || distance == null) ? "--" : (distance / 1000.0).format("%.1f"); // km

        var timerStr = hasSession ? formatDuration(data.getTimerTime()) : "--:--";

        display.hikeGrid(
            "ALTITUDE", altStr, false,
            "ELEV. GAIN", ascentStr,
            "DISTANCE", distStr,
            "TIMER", timerStr
        );

        if ($.isRecordFlashActive()) {
            display.recordingStartIcon();
        }
    }
}
