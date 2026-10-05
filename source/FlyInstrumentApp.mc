using Toybox.Application;
using Toybox.Sensor;

using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Attention;
using Toybox.System as Sys;

// --------------------------------------------------------------------------------
// Session recording
//
// SELECT is a real start -> pause -> resume toggle, like stock Garmin activity
// apps: hasActiveSession() is true for the whole time a session exists (whether
// actively recording or paused), while isRecording() is only true while it's
// actively ticking. The quit/save-discard menu (FlyInstrumentDelegate.mc) must
// gate on hasActiveSession(), not isRecording() -- otherwise pausing and then
// hitting BACK would exit without ever offering to save the paused session.
// --------------------------------------------------------------------------------

var session;

// --------------------------------------------------------------------------------
// Start-recording banner: a "start" icon shown centered on whichever page is on
// screen for a few seconds right after a session begins. recordFlashStartMs is
// the System.getTimer() timestamp of that moment, or null when no flash should
// be showing; every View's onUpdate() checks isRecordFlashActive() and draws
// the overlay via WatchDisplay.recordingStartIcon() on top of its own content.
// --------------------------------------------------------------------------------

var recordFlashStartMs = null;
const RECORD_FLASH_DURATION_MS = 3000;

function isRecordFlashActive()
{
    return $.recordFlashStartMs != null && (Sys.getTimer() - $.recordFlashStartMs) < RECORD_FLASH_DURATION_MS;
}

function hasActiveSession()
{
    return (Toybox has :ActivityRecording) && $.session != null;
}

function isRecording()
{
    return $.hasActiveSession() && $.session.isRecording();
}

function startRecording()
{
    if ($.hasActiveSession())
    {
        return;
    }

    if (Toybox has :ActivityRecording)
    {
        $.session = ActivityRecording.createSession({
            :name=>"Glide",
            :sport=>Activity.SPORT_FLYING});
        $.session.start();
        $.recordFlashStartMs = Sys.getTimer();

        if (Attention has :playTone)
        {
            Attention.playTone(Attention.TONE_START);
        }
        if (Attention has :vibrate)
        {
            var vibeData =
            [
                new Attention.VibeProfile(100, 1000)
            ];
            Attention.vibrate(vibeData);
        }
    }
}

function pauseRecording()
{
    if ($.isRecording())
    {
        $.session.stop();

        if (Attention has :vibrate)
        {
            var vibeData =
            [
                new Attention.VibeProfile(50, 300)
            ];
            Attention.vibrate(vibeData);
        }
    }
}

function resumeRecording()
{
    if ($.hasActiveSession() && !$.isRecording())
    {
        $.session.start();

        if (Attention has :vibrate)
        {
            var vibeData =
            [
                new Attention.VibeProfile(100, 300)
            ];
            Attention.vibrate(vibeData);
        }
    }
}

function stopRecording(save)
{
    if ($.hasActiveSession())
    {
        if ($.isRecording())
        {
            $.session.stop();
        }

        if (save)
        {
            $.session.save();
        }
        else
        {
            $.session.discard();
        }

        if (Attention has :playTone)
        {
            Attention.playTone(Attention.TONE_STOP);
        }

        if (Attention has :vibrate)
        {
            var vibeData =
            [
                new Attention.VibeProfile(25, 1000)
            ];
            Attention.vibrate(vibeData);
        }

        $.session = null;
    }
}

// Pure rule used by onStop(): should the current session be saved when the app
// is closed by the system without going through the Save/Discard menu? Yes
// whenever a session exists, recording or paused -- losing a whole hike & fly
// is worse than an unwanted saved activity the user can delete.
// The menu's Save/Discard paths null the session before System.exit(), so they
// reach onStop() with hasSession == false and are unaffected.
// isRecording is kept in the signature to make the paused case explicit; it
// never changes the answer on its own (no session -> nothing to save).
function shouldSaveOnStop(hasSession, isRecording)
{
    return hasSession == true;
}

// Pure rule used by onSensor(): should this tick feed the hike vertical-speed
// buffer? Not while a session is paused (hasSession && !isRecording): a frozen
// buffer would mix pre- and post-pause samples since System.getTimer() keeps
// running. On resume, HikeHistory resets itself on the > 15 s gap, so the page
// shows "--" for ~20 s rather than a wrong value. Before any session (hiking
// without recording) samples are recorded, just without a distance.
// An unknown recording state with a session is treated as paused (no sample).
function shouldRecordHikeSample(hasSession, isRecording)
{
    return !(hasSession == true && isRecording != true);
}

// --------------------------------------------------------------------------------
// Globals
// --------------------------------------------------------------------------------

var preferences;
  
// --------------------------------------------------------------------------------
// Main app
// --------------------------------------------------------------------------------

class FlyInstrumentApp extends Application.AppBase
{
    enum { MODE_HIKE, MODE_FLY }

    var mainView; // FlyInstrumentView -- drives the app's only 1Hz redraw heartbeat, see onSensor()
    var mode;
    var flyingViews;
    var hikingViews;
    var delegate;
    var breadcrumbTrail;
    var currentViewIndex;

    function initialize()
    {
        AppBase.initialize();
        preferences = new Preferences();
        mode = MODE_HIKE;
        currentViewIndex = 0;
        Sys.println("App initialized");
    }

    // onStart() is called on application start up
    function onStart(state)
    {
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE, Sensor.SENSOR_TEMPERATURE]);
        Sensor.enableSensorEvents(method(:onSensor));
        Sys.println("App started, sensors enabled");
    }

    // onStop() is called when your application is exiting
    function onStop(state)
    {
        if ($.shouldSaveOnStop($.hasActiveSession(), $.isRecording()))
        {
            $.stopRecording(true);
        }
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        Sensor.enableSensorEvents(null);
        Sensor.unregisterSensorDataListener();
        Sys.println("App stopped, sensors disabled");
    }

    function onPosition(info as $.Toybox.Position.Info) as Void
    {
        // Do nothing to avoid both call of onPosition and onSensor called in the same cycle
        // mainView.updateData();
    }

    // Should be called every 1Hz. Must keep running regardless of mode: it's what
    // drives redraws for every page, and it's what feeds the breadcrumb trail, so
    // the Map page still has a full trail whenever the user switches to it.
    function onSensor(info as $.Toybox.Sensor.Info) as Void
    {
        mainView.updateData();
        // Hike vertical speed / speed buffer, fed here rather than from the
        // flight vario's endMeasure() so the vario stays untouched.
        if ($.shouldRecordHikeSample($.hasActiveSession(), $.isRecording()))
        {
            mainView.data.recordHikeSample();
        }
        breadcrumbTrail.update(mainView.data.getLat(), mainView.data.getLon());
    }

    (:typecheck(false))
    // See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    // Return the initial view of your application here
    function getInitialView()
    {
        mainView = new FlyInstrumentView();
        var timeView = new TimeView();
        var positionView = new PositionView();
        flyingViews = [mainView, timeView, positionView];

        breadcrumbTrail = new BreadcrumbTrail();
        hikingViews = [new HikePositionView(self), new HikePaceView(self), timeView, new HikeMapView(self)];

        delegate = new BaseInputDelegate(self);
        mode = MODE_HIKE;
        currentViewIndex = 0;

        Sys.println("Initial view setup, starting in Hiking mode");
        return [activeViewList()[currentViewIndex], delegate];
    }

    // The page list for whichever mode is currently active
    function activeViewList()
    {
        return (mode == MODE_HIKE) ? hikingViews : flyingViews;
    }

    (:typecheck(false))
    // See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    // Switch to a specific view (by index into the active mode's page list)
    function switchToView(index)
    {
        var list = activeViewList();
        if (index >= 0 && index < list.size()) {
            currentViewIndex = index;
            Sys.println("Switching to view index: " + index);
            WatchUi.switchToView(list[currentViewIndex], delegate, WatchUi.SLIDE_IMMEDIATE);
        } else {
            Sys.println("Invalid view index: " + index);
        }
    }

    (:typecheck(false))
    // See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    // Toggle Hiking <-> Flying, triggered by a 3s hold of LAP (FlyInstrumentDelegate.mc).
    // Marks the transition with a lap if a session is actively recording -- a paused
    // session can't accept a lap, so the transition just goes unmarked in that case.
    function switchMode()
    {
        if ($.isRecording())
        {
            $.session.addLap();
        }

        mode = (mode == MODE_HIKE) ? MODE_FLY : MODE_HIKE;
        currentViewIndex = 0;
        Sys.println("switchMode: now " + (mode == MODE_HIKE ? "MODE_HIKE" : "MODE_FLY"));
        WatchUi.switchToView(activeViewList()[currentViewIndex], delegate, WatchUi.SLIDE_IMMEDIATE);
    }
}