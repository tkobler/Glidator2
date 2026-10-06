using Toybox.Application;
using Toybox.Lang;

// --------------------------------------------------------------------------------
// Hike vertical-speed window (MENU -> "VS window"): 1, 3 or 5 min. 5 min is the
// whole HikeHistory buffer (60 samples at most 5 s apart). Pace keeps its own
// 60 s window; the flight vario does not use any of this.
// --------------------------------------------------------------------------------

const VS_WINDOW_DEFAULT_MS = 60000;

function vsWindowChoicesMs()
{
	return [60000, 180000, 300000];
}

// Stored or requested value -> one of the three windows. Anything else (null:
// nothing stored, another Number, a Float, a String...) gives the 60 s default.
function sanitizeVsWindowMs(raw)
{
	if (!(raw instanceof Lang.Number))
	{
		return VS_WINDOW_DEFAULT_MS;
	}
	var choices = vsWindowChoicesMs();
	for (var i = 0; i < choices.size(); i++)
	{
		if (raw == choices[i])
		{
			return raw;
		}
	}
	return VS_WINDOW_DEFAULT_MS;
}

// Index of the window in vsWindowChoicesMs() (0 for anything invalid): also
// the item to focus in the 3-choice menu.
function vsWindowFocusIndex(ms)
{
	var w = sanitizeVsWindowMs(ms);
	var choices = vsWindowChoicesMs();
	for (var i = 0; i < choices.size(); i++)
	{
		if (w == choices[i])
		{
			return i;
		}
	}
	return 0;
}

// Menu item ids of the 3-choice menu, in vsWindowChoicesMs() order.
function vsWindowMenuIds()
{
	return ["vs1", "vs3", "vs5"];
}

function vsWindowMenuId(ms)
{
	return vsWindowMenuIds()[vsWindowFocusIndex(ms)];
}

// Menu item id -> window in ms, or null for an unknown id (nothing changes).
function vsWindowFromMenuId(id)
{
	if (!(id instanceof Lang.String))
	{
		return null;
	}
	var ids = vsWindowMenuIds();
	for (var i = 0; i < ids.size(); i++)
	{
		if (id.equals(ids[i]))
		{
			return vsWindowChoicesMs()[i];
		}
	}
	return null;
}

function vsWindowLabel(ms)
{
	return ["1 min", "3 min", "5 min"][vsWindowFocusIndex(ms)];
}

// Preferences menu (MENU) item id -> :openVsWindow for "VS window", :none
// otherwise (the Beep toggle is saved on BACK, as before).
function preferencesMenuAction(id)
{
	if (id instanceof Lang.String && id.equals("vsWindow"))
	{
		return :openVsWindow;
	}
	return :none;
}

// A choice from the menu: stored in the preferences and pushed to the
// WatchData that HikePaceView reads. Either may be null. Returns the window
// actually applied (the default for an invalid choice).
function applyVsWindowChoice(prefs, data, ms)
{
	var w = sanitizeVsWindowMs(ms);
	if (prefs != null)
	{
		prefs.setVsWindowMs(w);
	}
	if (data != null)
	{
		data.setHikeVsWindowMs(w);
	}
	return w;
}

// --------------------------------------------------------------------------------

class Preferences
{
	const VS_WINDOW_KEY = "vsWindowMs";

	var app;

	function initialize()
    {
    	app = Application.getApp();
    }

    function getBeep ()
    {
    	var beep = app.getProperty("beep");
		return (beep == null ? false: beep);
    }

    function setBeep (newVal)
    {
    	app.setProperty("beep", newVal);
    }

	// Read from the store on every call (no cache), like getBeep().
	function getVsWindowMs()
	{
		return $.sanitizeVsWindowMs(app.getProperty(VS_WINDOW_KEY));
	}

	// Only one of the three windows is ever written.
	function setVsWindowMs(ms)
	{
		app.setProperty(VS_WINDOW_KEY, $.sanitizeVsWindowMs(ms));
	}

}
