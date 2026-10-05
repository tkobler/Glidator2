using Toybox.WatchUi;
using Toybox.System;
using Toybox.Graphics;
using Toybox.Math;

// Render-only, like HikeMapView: reads app.mainView.data (see HikePositionView.mc
// for why -- a page-local WatchData would let its vario/altitude-delta state go
// stale while the user is on a different page).
class HikePaceView extends WatchUi.View {
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

        var heartRate = data.getHeartRate();
        var hrStr = (heartRate == null) ? "--" : heartRate.toString(); // bpm

        // Vertical speed (m/h): regression over the last 60 s of hike samples
        // (WatchData.getHikeVerticalSpeed), not the 1 s flight vario, whose
        // 0.2 m altitude steps read as +/-720 m/h jumps when walking.
        var vPaceStr = $.formatVerticalSpeed(data.getHikeVerticalSpeed()); // m/h

        var speed = data.getSpeed();
        var hPaceStr = "--:--";
        if (speed != null && speed > 0.0) {
            var paceMinPerKm = 1000.0 / (speed * 60.0);
            var paceMinutes = paceMinPerKm.toNumber();
            var paceSeconds = Math.round((paceMinPerKm - paceMinutes) * 60).toNumber();
            hPaceStr = paceMinutes.toString() + ":" + paceSeconds.format("%02d"); // min/km 
        }

        var timerStr = $.hasActiveSession() ? formatDuration(data.getTimerTime()) : "--:--";

        display.hikeGrid(
            "Heart Rate", hrStr, true,
            "VERT. SPD.", vPaceStr,
            "PACE", hPaceStr,
            "TIMER", timerStr
        );

        if ($.isRecordFlashActive()) {
            display.recordingStartIcon();
        }
    }
}
