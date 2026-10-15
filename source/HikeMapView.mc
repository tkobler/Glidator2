using Toybox.WatchUi;
using Toybox.System;
using Toybox.Graphics;

// Live breadcrumb map. Render-only: the actual trail is collected in
// FlyInstrumentApp.onSensor() into app.breadcrumbTrail regardless of which
// page is on screen, so the trail is already complete whenever this page
// is visited. Current position/heading are read straight from the app's
// always-on WatchData (mainView.data) rather than polling again here.
class HikeMapView extends WatchUi.View {
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

        var trail = app.breadcrumbTrail;
        var curData = app.mainView.data;

        // Without a fix usable for the map, there is no current position:
        // map() then draws the trail alone (or "Waiting for GPS" if empty).
        var curLat = null;
        var curLon = null;
        if (curData.hasUsableFix()) {
            curLat = curData.getLat();
            curLon = curData.getLon();
        }

        display.map(
            trail.getLats(), trail.getLons(), trail.getCount(), trail.getWriteIndex(),
            curLat, curLon, curData.getHeading()
        );

        if ($.isRecordFlashActive()) {
            display.recordingStartIcon();
        }
    }
}
