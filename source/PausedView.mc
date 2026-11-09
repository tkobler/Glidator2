using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System as Sys;

// --------------------------------------------------------------------------------
// "Paused" screen, opened by the Pause item of the pause menu (it replaces the
// menu, so the view stack is: activity page, then this screen). Shows the
// current local time (12/24 h as set on the watch). The decisions live in
// FlyInstrumentApp.mc (pausedSelectAction, pausedBackAction, pausedClockText):
// - SELECT (START) resumes and pops this screen, back to the activity page;
// - BACK does nothing (no resume, no pop: popping more views would quit);
// - no automatic resume, no BACK-hold mode switch, no preferences menu here.
// Redrawn every second by the onSensor() tick (WatchUi.requestUpdate()).
// --------------------------------------------------------------------------------

class PausedView extends WatchUi.View
{
    var app;
    // Tests only: [hour, minute, is24Hour] shown instead of the system clock.
    var clockOverride;

    function initialize(appInstance)
    {
        View.initialize();
        app = appInstance;
        clockOverride = null;
    }

    function onUpdate(dc)
    {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 35) / 100, Graphics.FONT_MEDIUM, "Paused", center);

        var hour = null;
        var minute = null;
        var is24 = true;
        if (clockOverride != null)
        {
            hour = clockOverride[0];
            minute = clockOverride[1];
            is24 = clockOverride[2];
        }
        else
        {
            var now = Sys.getClockTime();
            if (now != null)
            {
                hour = now.hour;
                minute = now.min;
            }
            var settings = Sys.getDeviceSettings();
            if (settings != null && settings.is24Hour != null)
            {
                is24 = settings.is24Hour;
            }
        }
        var timeStr = $.pausedClockText(hour, minute, is24);
        // Larger digits when they fit ("12:58 PM" on the smallest screens may not).
        var font = Graphics.FONT_NUMBER_MEDIUM;
        if (dc.getTextWidthInPixels(timeStr, font) > (w * 80) / 100)
        {
            font = Graphics.FONT_NUMBER_MILD;
        }
        if (dc.getTextWidthInPixels(timeStr, font) > (w * 80) / 100)
        {
            font = Graphics.FONT_MEDIUM;
        }
        dc.drawText(w / 2, (h * 57) / 100, font, timeStr, center);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 80) / 100, Graphics.FONT_XTINY, "START: resume", center);
    }
}

class PausedDelegate extends WatchUi.BehaviorDelegate
{
    // True once this screen has been popped, so a second SELECT before it
    // is gone cannot pop the activity page too (that would quit the app).
    var closed;

    function initialize()
    {
        BehaviorDelegate.initialize();
        closed = false;
    }

    function onSelect()
    {
        var action = $.pausedSelectAction(closed, $.hasActiveSession(), $.isRecording());
        if (action == :none)
        {
            return true;
        }
        closed = true;
        if (action == :resume)
        {
            $.resumeRecording();
            Sys.println("Paused screen: SELECT, resuming");
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.requestUpdate();
        return true;
    }

    // Returning true consumes BACK: the system does not pop this screen.
    function onBack()
    {
        Sys.println("Paused screen: BACK ignored (" + $.pausedBackAction() + ")");
        return true;
    }

    // No preferences menu from the Paused screen.
    function onMenu()
    {
        return true;
    }
}
