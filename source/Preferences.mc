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
// Storage (decision D6, 07/10). Both preferences live in Application.Storage
// (CIQ 2.4+, every watch of the manifest). Versions before D6 kept them in the
// AppBase object store (getProperty / setProperty, deprecated); the same keys
// are carried over once by migrateLegacyPreferences().
// --------------------------------------------------------------------------------

const PREF_BEEP_KEY = "beep";
const PREF_VS_WINDOW_KEY = "vsWindowMs";

// Stored or requested beep -> Boolean. Anything but a Boolean (null: nothing
// stored, a Number, a String...) gives the default, off.
function sanitizeBeep(raw)
{
	return (raw instanceof Lang.Boolean) ? raw : false;
}

// Key + raw value -> the value to store for that preference, or null for a
// key that is not one of ours (nothing to write).
function sanitizePreference(key, raw)
{
	if (!(key instanceof Lang.String))
	{
		return null;
	}
	if (key.equals(PREF_BEEP_KEY))
	{
		return sanitizeBeep(raw);
	}
	if (key.equals(PREF_VS_WINDOW_KEY))
	{
		return sanitizeVsWindowMs(raw);
	}
	return null;
}

// Migration decision for one key: (value already in Storage, value in the old
// object store) -> value kept. Storage wins as soon as it holds something
// (false and 0 included): it was written by this version, so it is the
// user's latest choice; otherwise the old value is taken (null if none).
function preferenceToKeep(storageValue, legacyValue)
{
	return (storageValue != null) ? storageValue : legacyValue;
}

// ONE-TIME MIGRATION, the only place allowed to use the deprecated object
// store: for each preference key still present there (AppBase.getProperty),
// write the kept value (sanitized) to Storage, then erase the old key
// (AppBase.deleteProperty). Storage is written before the old key is erased,
// so an interruption loses nothing. Once the old keys are gone, later launches
// only read two empty keys and write nothing. `legacy` is the AppBase (any
// object with getProperty / deleteProperty in tests); null, or a firmware
// where getProperty has been removed, means nothing to migrate.
// Returns the number of keys migrated.
function migrateLegacyPreferences(legacy)
{
	if (legacy == null || !(legacy has :getProperty) || !(legacy has :deleteProperty))
	{
		return 0;
	}
	var keys = [PREF_BEEP_KEY, PREF_VS_WINDOW_KEY];
	var migrated = 0;
	for (var i = 0; i < keys.size(); i++)
	{
		var old = legacy.getProperty(keys[i]);
		if (old != null)
		{
			var kept = preferenceToKeep(Application.Storage.getValue(keys[i]), old);
			Application.Storage.setValue(keys[i], sanitizePreference(keys[i], kept));
			legacy.deleteProperty(keys[i]);
			migrated += 1;
		}
	}
	return migrated;
}

// --------------------------------------------------------------------------------

class Preferences
{
	function initialize()
    {
		$.migrateLegacyPreferences(Application.getApp());
    }

	// Read from Storage on every call (no cache).
    function getBeep()
    {
		return $.sanitizeBeep(Application.Storage.getValue($.PREF_BEEP_KEY));
    }

	// Only a Boolean is ever written (false for anything else).
    function setBeep(newVal)
    {
		Application.Storage.setValue($.PREF_BEEP_KEY, $.sanitizeBeep(newVal));
    }

	// Read from Storage on every call (no cache), like getBeep().
	function getVsWindowMs()
	{
		return $.sanitizeVsWindowMs(Application.Storage.getValue($.PREF_VS_WINDOW_KEY));
	}

	// Only one of the three windows is ever written.
	function setVsWindowMs(ms)
	{
		Application.Storage.setValue($.PREF_VS_WINDOW_KEY, $.sanitizeVsWindowMs(ms));
	}

}
