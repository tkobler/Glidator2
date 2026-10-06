using Toybox.Application;
using Toybox.Sensor;

using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Attention;
using Toybox.System as Sys;

// --------------------------------------------------------------------------------
// Session recording
//
// SELECT drives recording like stock Garmin activity apps (see selectAction()
// below): hasActiveSession() is true for the whole time a session exists
// (whether actively recording or paused), while isRecording() is only true while
// it's actively ticking. Anything that must not lose a paused session (BACK
// exiting the app, onStop() saving) gates on hasActiveSession(), not isRecording().
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

// --------------------------------------------------------------------------------
// Recording sport. Activity.SPORT_* only exist from Connect IQ 3.2.0: on fenix5 /
// fenix5x (CIQ 3.1.6) reading Activity.SPORT_FLYING -- and even
// Activity.SPORT_GENERIC -- throws "Symbol Not Found" at runtime. So the sport is
// chosen at runtime with `Activity has :SPORT_FLYING`, and passed as its FIT sport
// code (the very values of Activity.SPORT_*, pinned by testRecordingSportCodesMatchApi).
// --------------------------------------------------------------------------------

const RECORDING_SPORT_GENERIC = 0; // FIT sport "generic" == Activity.SPORT_GENERIC
const RECORDING_SPORT_FLYING = 20; // FIT sport "flying"  == Activity.SPORT_FLYING

function pickRecordingSport(hasFlying)
{
    return (hasFlying == true) ? RECORDING_SPORT_FLYING : RECORDING_SPORT_GENERIC;
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
            :sport=>$.pickRecordingSport(Activity has :SPORT_FLYING)});
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
        $.applySensorsForState(true);
        $.vibrateFor(:pause);
    }
}

function resumeRecording()
{
    if ($.hasActiveSession() && !$.isRecording())
    {
        $.applySensorsForState(false);
        $.session.start();
        $.vibrateFor(:resume);
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

        // A session ended while paused must not leave the sensors off.
        if ($.sensorsOffForPause)
        {
            $.applySensorsForState(false);
        }
    }
}

// --------------------------------------------------------------------------------
// START (SELECT) button and the Resume / Pause / Save / Ignore menu, modelled on
// the stock Garmin Hike app (pure rules, used by FlyInstrumentDelegate.mc):
// - no session        -> SELECT starts recording;
// - recording         -> SELECT pauses (timer frozen) and opens the menu;
// - paused            -> SELECT resumes (picking "Pause" opens the Paused
//                        screen, whose own SELECT resumes; see below).
// In the menu, BACK means Resume, and MENU_AUTO_RESUME_MS without any choice
// resumes too, so a stray press can't leave the activity paused for hours.
// --------------------------------------------------------------------------------

const MENU_AUTO_RESUME_MS = 30000;

// A session exists but is not ticking (paused by the user).
function isPaused()
{
    return $.hasActiveSession() && !$.isRecording();
}

// Returns :start, :pauseMenu or :resume. A session in an unknown recording state
// is treated as paused: resumeRecording() is a no-op on a running session.
function selectAction(hasSession, recording)
{
    if (hasSession != true)
    {
        return :start;
    }
    return (recording == true) ? :pauseMenu : :resume;
}

// Returns :resume once the menu has been open for MENU_AUTO_RESUME_MS or more,
// :none otherwise (including an unknown or negative elapsed time).
function menuTimeoutAction(elapsedMs)
{
    if (elapsedMs == null || elapsedMs < 0)
    {
        return :none;
    }
    return (elapsedMs >= MENU_AUTO_RESUME_MS) ? :resume : :none;
}

// Periodic check run by the menu's timer: nothing once the menu has been
// closed (or if that state is unknown), so a choice like Pause, Save or
// Ignore is never followed by a late automatic resume.
function quitMenuTickAction(menuClosed, elapsedMs)
{
    if (menuClosed != false)
    {
        return :none;
    }
    return $.menuTimeoutAction(elapsedMs);
}

// Menu item id -> :resume, :pause, :save, :ignore, or :none if unknown.
function menuItemAction(id)
{
    if (!(id instanceof Toybox.Lang.String))
    {
        return :none;
    }
    if (id.equals("resume")) { return :resume; }
    if (id.equals("pause"))  { return :pause; }
    if (id.equals("save"))   { return :save; }
    if (id.equals("ignore")) { return :ignore; }
    return :none;
}

// BACK in the menu is the same as picking Resume (stock Garmin behaviour).
function menuBackAction()
{
    return :resume;
}

// --------------------------------------------------------------------------------
// "Paused" screen (PausedView.mc), opened by the menu's Pause item: shows the
// frozen timer; SELECT resumes and goes back to the activity page. No automatic
// resume there, and BACK does nothing (popping the last view would quit the app).
// --------------------------------------------------------------------------------

// SELECT on the Paused screen. `closed` is true once the screen has already
// been handled (popped): a second press must not pop another view.
// Returns :none, :resume (resume + close) or :close (close only, e.g. the
// session is already recording or gone). A session in an unknown recording
// state is treated as paused, as in selectAction().
function pausedSelectAction(closed, hasSession, recording)
{
    if (closed != false)
    {
        return :none;
    }
    if (hasSession == true && recording != true)
    {
        return :resume;
    }
    return :close;
}

// BACK on the Paused screen: nothing (unlike the menu, where BACK = Resume).
function pausedBackAction()
{
    return :none;
}

// Timer text of the Paused screen; "--:--" without a session or timer value.
function pausedScreenTimerText(hasSession, timerMs)
{
    return (hasSession == true) ? $.formatDuration(timerMs) : "--:--";
}

// --------------------------------------------------------------------------------
// Sensors while paused. onStart() enables activeSensorList() through
// Sensor.setEnabledSensors(); while a session is paused they are all turned off
// (setEnabledSensors([])) and the same list is enabled again on resume. The GPS
// is not a Sensor: Position.enableLocationEvents() is left alone, and so is
// Sensor.enableSensorEvents(), which drives the 1 Hz onSensor() tick.
// --------------------------------------------------------------------------------

// The list enabled by onStart(), or null before onStart().
var activeSensors = null;
// True while the sensors have been turned off for a pause.
var sensorsOffForPause = false;

function activeSensorList()
{
    return [Sensor.SENSOR_HEARTRATE, Sensor.SENSOR_TEMPERATURE];
}

// Sensors wanted for a state: none while paused, otherwise exactly
// `active` ([] if unknown). An unknown pause state keeps them on.
function sensorsForState(paused, active)
{
    if (paused == true || active == null)
    {
        return [];
    }
    return active;
}

function applySensorsForState(paused)
{
    Sensor.setEnabledSensors($.sensorsForState(paused, $.activeSensors));
    $.sensorsOffForPause = (paused == true);
}

// --------------------------------------------------------------------------------
// Pause / resume vibrations, told apart by their shape rather than intensity:
// pause = two short pulses, resume = one long pulse. Each segment is
// [duty cycle %, duration ms]; a 0 % segment is a gap.
// --------------------------------------------------------------------------------

function vibePattern(kind)
{
    if (kind == :pause)
    {
        return [[100, 150], [0, 150], [100, 150]];
    }
    if (kind == :resume)
    {
        return [[100, 600]];
    }
    return [];
}

function vibeProfiles(pattern)
{
    var profiles = [];
    if (pattern == null)
    {
        return profiles;
    }
    for (var i = 0; i < pattern.size(); i++)
    {
        profiles.add(new Attention.VibeProfile(pattern[i][0], pattern[i][1]));
    }
    return profiles;
}

function vibrateFor(kind)
{
    if (Attention has :vibrate)
    {
        var profiles = $.vibeProfiles($.vibePattern(kind));
        if (profiles.size() > 0)
        {
            Attention.vibrate(profiles);
        }
    }
}

// Pure rule used by onStop(): should the current session be saved when the app
// is closed by the system without going through the Save/Ignore menu? Yes
// whenever a session exists, recording or paused -- losing a whole hike & fly
// is worse than an unwanted saved activity the user can delete.
// The menu's Save/Ignore paths null the session before System.exit(), so they
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

// Called by onSensor() every tick: feeds the breadcrumb trail only when the
// GPS has a fix usable for the map (WatchData.hasUsableFix()), so the no-fix
// position (180, 180) seen before the first fix never lands in the trail.
// BreadcrumbTrail.update() also checks the bounds on its own.
function feedBreadcrumbTrail(trail, data)
{
    if (data.hasUsableFix())
    {
        trail.update(data.getLat(), data.getLon());
    }
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
        $.activeSensors = $.activeSensorList();
        $.sensorsOffForPause = false;
        Sensor.setEnabledSensors($.activeSensors);
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
        $.feedBreadcrumbTrail(breadcrumbTrail, mainView.data);
    }

    (:typecheck(false))
    // See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    // Return the initial view of your application here
    function getInitialView()
    {
        mainView = new FlyInstrumentView();
        // Hike vertical-speed window chosen in MENU -> "VS window" (default 60 s).
        mainView.data.setHikeVsWindowMs($.preferences.getVsWindowMs());
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