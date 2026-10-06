using Toybox.WatchUi;
using Toybox.ActivityRecording;
using Toybox.Timer;

using Toybox.System as Sys;

// --------------------------------------------------------------------------------

// Resume / Pause / Save / Ignore menu, shown by SELECT while recording (the
// session is already paused when it opens). The rules live in
// FlyInstrumentApp.mc (menuItemAction, menuBackAction, quitMenuTickAction):
// - Resume, BACK, or MENU_AUTO_RESUME_MS without a choice -> resume + close;
// - Pause -> close and stay paused (SELECT will resume later);
// - Save / Ignore -> end the session and exit the app.
// A repeating 1 s timer checks the elapsed time; it is stopped as soon as the
// menu is closed, and `closed` makes sure only the first action ever runs.
class MyMenu2QuitDelegate extends WatchUi.Menu2InputDelegate
{
    const TICK_MS = 1000;

    var openedMs;
    var closed;
    var timer;

    function initialize()
    {
        Menu2InputDelegate.initialize();
        openedMs = Sys.getTimer();
        closed = false;
        timer = new Timer.Timer();
        timer.start(method(:onTick), TICK_MS, true);
    }

    function onSelect(item)
    {
        apply($.menuItemAction(item.getId()));
    }

    function onBack()
    {
        apply($.menuBackAction());
    }

    function onTick() as Void
    {
        apply($.quitMenuTickAction(closed, Sys.getTimer() - openedMs));
    }

    function apply(action)
    {
        if (closed || action == :none)
        {
            return;
        }
        closed = true;
        if (timer != null)
        {
            timer.stop();
            timer = null; // also breaks the delegate <-> timer callback reference cycle
        }

        if (action == :resume)
        {
            $.resumeRecording(); // no-op if not paused
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
        else if (action == :pause)
        {
            WatchUi.popView(WatchUi.SLIDE_DOWN); // stays paused
        }
        else if (action == :save)
        {
            $.stopRecording(true);
            System.exit();
        }
        else if (action == :ignore)
        {
            $.stopRecording(false);
            System.exit();
        }
        WatchUi.requestUpdate();
    }
}

// --------------------------------------------------------------------------------

class MyMenu2PreferencesDelegate extends WatchUi.Menu2InputDelegate
{
    var beepToggleMenu;

    function initialize(beepTM)
    {
        Menu2InputDelegate.initialize();
        beepToggleMenu = beepTM;
    }

    function onSelect(item)
    {
        if( item.getId().equals("audio") )
        {
            Sys.println("On MyMenu2PreferencesDelegate:audio");
        }
    }
    
    function onBack()
    {
        $.preferences.setBeep(beepToggleMenu.isEnabled());
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

// --------------------------------------------------------------------------------

class BaseInputDelegate extends WatchUi.BehaviorDelegate
{
    var app;

    // Timestamp (System.getTimer(), ms) of the last BACK/LAP press, used to
    // detect a 1.5s hold in onKeyReleased(). null when the button isn't currently held.
    var lapPressStartMs;
    const LAP_HOLD_MS = 1500;

    // Timestamp of the last hold-triggered mode switch, used by onBack() to
    // avoid also exiting the app on the same physical gesture. null until
    // the first hold is detected.
    var lastModeSwitchMs;

    function initialize(appInstance)
    {
        BehaviorDelegate.initialize();
        app = appInstance;
        lapPressStartMs = null;
        lastModeSwitchMs = null;
        Sys.println("BaseInputDelegate initialized, app: " + (app != null ? app.toString() : "null"));

        // One-time diagnostic: does this device's button bitmask report a LAP
        // button distinct from ESC/BACK, or are they the same physical button?
        var settings = System.getDeviceSettings();
        if (settings has :inputButtons)
        {
            var mask = settings.inputButtons;
            var hasLap = (System has :BUTTON_INPUT_LAP) && (mask & System.BUTTON_INPUT_LAP) != 0;
            var hasEsc = (System has :BUTTON_INPUT_ESC) && (mask & System.BUTTON_INPUT_ESC) != 0;
            Sys.println("Device inputButtons mask=" + mask + " hasLapBit=" + hasLap + " hasEscBit=" + hasEsc);
        }
    }

    // SELECT (START) is the only button that drives recording (see
    // selectAction() in FlyInstrumentApp.mc), like the stock Garmin Hike app:
    // no session -> start; recording -> pause (timer frozen) AND show the
    // Resume/Pause/Save/Ignore menu; paused (after picking Pause) -> resume.
    // BACK/LAP is reserved for the 1.5s-hold Hiking/Flying mode switch -- see
    // onKeyPressed/onKeyReleased below.
    function onSelect()
    {
        var action = $.selectAction($.hasActiveSession(), $.isRecording());
        if (action == :start)
        {
            $.startRecording();
            Sys.println("Select pressed, starting recording");
        }
        else if (action == :pauseMenu)
        {
            $.pauseRecording();
            Sys.println("Select pressed, pausing recording, showing pause menu");
            showQuitMenu();
        }
        else if (action == :resume)
        {
            $.resumeRecording();
            Sys.println("Select pressed, resuming recording");
        }
        WatchUi.requestUpdate();
        return true;
    }

    function showQuitMenu()
    {
        var menu = new WatchUi.Menu2({:title=>"Paused"});
        menu.addItem(new WatchUi.MenuItem("Resume", null, "resume", null));
        menu.addItem(new WatchUi.MenuItem("Pause", null, "pause", null));
        menu.addItem(new WatchUi.MenuItem("Save", null, "save", null));
        menu.addItem(new WatchUi.MenuItem("Ignore", null, "ignore", null));
        var delegate = new MyMenu2QuitDelegate();

        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_IMMEDIATE);
    }

    // Only used to exit the app when nothing is being recorded -- while a
    // session is active, BACK is reserved for the LAP mode-switch hold and
    // does nothing on a short press (pausing/quitting now goes through START).
    //
    // Guarded against firing right after onKeyReleased() has just handled a
    // hold-triggered mode switch on this same physical button: a completed
    // press+release still reaches onBack() regardless of how long it was
    // held, so without this guard, holding the button for 3s while idle
    // would switch mode AND immediately exit the app on the same gesture.
    function onBack()
    {
        if (lastModeSwitchMs != null && (Sys.getTimer() - lastModeSwitchMs) < 500)
        {
            Sys.println("onBack suppressed: just handled a hold-triggered mode switch");
            return true;
        }

        if (!$.hasActiveSession())
        {
            System.exit();
            Sys.println("Back pressed, exiting app");
        }
        return true;
    }

    // Raw press/release timestamps (unlike onKey(), which only fires once the
    // full press+release cycle completes) so a hold can be measured. This runs
    // alongside, not instead of, the semantic onSelect/onBack/onMenu/onKey
    // callbacks above -- Connect IQ dispatches behavior and raw-key handlers
    // independently, so no chain-to-super is needed here.
    //
    // Watches both KEY_LAP and KEY_ESC: on Fenix-style watches, BACK and LAP
    // are the same physical button whose bezel label changes with recording
    // state, and it's not confirmed which key code Connect IQ actually
    // reports for it in every state -- KEY_LAP may be reserved for devices
    // with a genuinely separate LAP button (Edge/Forerunner). Watching both
    // makes the hold gesture work regardless of which one this button turns
    // out to send.
    function onKeyPressed(keyEvent)
    {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_LAP || key == WatchUi.KEY_ESC)
        {
            Sys.println("onKeyPressed: key=" + key + " at t=" + Sys.getTimer());
            // Guard against key-repeat: if the device re-fires onKeyPressed
            // while the button is still held down (typematic-style repeat),
            // don't let that reset the start time back to "now" every tick.
            if (lapPressStartMs == null)
            {
                lapPressStartMs = Sys.getTimer();
            }
        }
        return false;
    }

    function onKeyReleased(keyEvent)
    {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_LAP || key == WatchUi.KEY_ESC)
        {
            var startMs = lapPressStartMs;
            lapPressStartMs = null;
            var heldMs = (startMs == null) ? -1 : (Sys.getTimer() - startMs);
            Sys.println("onKeyReleased: key=" + key + " heldMs=" + heldMs);

            if (startMs != null && heldMs >= LAP_HOLD_MS)
            {
                Sys.println("Hold >= " + LAP_HOLD_MS + "ms detected, switching mode");
                lastModeSwitchMs = Sys.getTimer();
                app.switchMode();
                return true;
            }
        }
        return false;
    }

    function onMenu()
    {
        var menu = new WatchUi.Menu2({:title=>"Preferences"});
            
        var beep = $.preferences.getBeep();
        var beepTM = new WatchUi.ToggleMenuItem("Beep", "Set audio on/off", "beep", beep, null);
        menu.addItem(beepTM);
          
        var delegate = new MyMenu2PreferencesDelegate(beepTM);
            
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_IMMEDIATE);
        Sys.println("Menu pressed, showing preferences");
        
        return true;
    }
    
    function onKey(keyEvent)
    {
        var key = keyEvent.getKey();
        Sys.println("onKey called, key: " + key);
        if (app == null) {
            Sys.println("Error: app reference is null");
            return true;
        }
        var listSize = app.activeViewList().size();
        if (key == WatchUi.KEY_UP) {
            var nextIndex = (app.currentViewIndex - 1 + listSize) % listSize;
            Sys.println("UP pressed, switching to previous view, index: " + nextIndex);
            app.switchToView(nextIndex);
            return true;
        }
        else if (key == WatchUi.KEY_DOWN) {
            var nextIndex = (app.currentViewIndex + 1) % listSize;
            Sys.println("DOWN pressed, switching to next view, index: " + nextIndex);
            app.switchToView(nextIndex);
            return true;
        }
        Sys.println("Unhandled key: " + key);
        return true;
    }
}