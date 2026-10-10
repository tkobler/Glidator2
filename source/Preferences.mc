using Toybox.Application;
using Toybox.Lang;

// --------------------------------------------------------------------------------
// Hike vertical-speed window (MENU -> "VS window", each press goes to the next
// one): 1, 3 or 5 min. 5 min is the
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

// Index of the window in vsWindowChoicesMs() (0 for anything invalid).
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

// Sub-label of the "VS window" item.
function vsWindowLabel(ms)
{
	return ["1 min", "3 min", "5 min"][vsWindowFocusIndex(ms)];
}

// Decision R6 (07/10): each press on "VS window" goes to the next window,
// 1 -> 3 -> 5 -> 1 min. Anything that is not one of the three windows (null,
// another Number, a Float, a String...) restarts the cycle at 1 min.
function nextVsWindowMs(ms)
{
	if (!(ms instanceof Lang.Number))
	{
		return VS_WINDOW_DEFAULT_MS;
	}
	var choices = vsWindowChoicesMs();
	for (var i = 0; i < choices.size(); i++)
	{
		if (ms == choices[i])
		{
			return choices[(i + 1) % choices.size()];
		}
	}
	return VS_WINDOW_DEFAULT_MS;
}

// Preferences menu (MENU) item id -> :cycleVsWindow for "VS window", :none
// otherwise (the Beep toggle is saved on BACK, as before).
function preferencesMenuAction(id)
{
	if (id instanceof Lang.String && id.equals("vsWindow"))
	{
		return :cycleVsWindow;
	}
	return :none;
}

// One press on "VS window": the current window (from the store, else from the
// WatchData, else the default) goes to the next one, which is stored at once
// and pushed to the WatchData. Either may be null. Returns the new window,
// to show as the item's sub-label.
function cycleVsWindow(prefs, data)
{
	var current = VS_WINDOW_DEFAULT_MS;
	if (prefs != null)
	{
		current = prefs.getVsWindowMs();
	}
	else if (data != null)
	{
		current = data.getHikeVsWindowMs();
	}
	return applyVsWindowChoice(prefs, data, nextVsWindowMs(current));
}

// A window chosen from the menu: stored in the preferences and pushed to the
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
	return migrateLegacyPreferencesTo(legacy, new AppStorageStore());
}

// Same migration into `store` (any object with getValue / setValue:
// AppStorageStore in the app, a stand-in in tests). It runs at start-up, so
// it never throws: if any step for a key fails (reading the old store,
// reading or writing Storage -- setValue raises an exception when the store
// is full -- or erasing the old key), the rest of that key is skipped and
// the other key is still migrated. The old key is only erased after Storage
// is written; if the write failed, the old value is kept for the next
// launch; if only the erase failed, Storage already holds the value (it
// wins on the next launch) and the erase is retried. A key counts as
// migrated once its old copy is erased. A null store migrates nothing.
function migrateLegacyPreferencesTo(legacy, store)
{
	if (legacy == null || !(legacy has :getProperty) || !(legacy has :deleteProperty) || store == null)
	{
		return 0;
	}
	var keys = [PREF_BEEP_KEY, PREF_VS_WINDOW_KEY];
	var migrated = 0;
	for (var i = 0; i < keys.size(); i++)
	{
		try
		{
			var old = legacy.getProperty(keys[i]);
			if (old != null)
			{
				var kept = preferenceToKeep(store.getValue(keys[i]), old);
				store.setValue(keys[i], sanitizePreference(keys[i], kept));
				legacy.deleteProperty(keys[i]);
				migrated += 1;
			}
		}
		catch (e)
		{
			// Key left as it is: retried on the next launch.
		}
	}
	return migrated;
}

// Application.Storage behind the getValue / setValue pair used by
// migrateLegacyPreferencesTo().
class AppStorageStore
{
	function initialize() {}

	function getValue(key)
	{
		return Application.Storage.getValue(key);
	}

	function setValue(key, value)
	{
		Application.Storage.setValue(key, value);
	}
}

// --------------------------------------------------------------------------------

class Preferences
{
	// `app`: the AppBase holding the old object store. FlyInstrumentApp passes
	// self from its own constructor rather than looking the app up with
	// Application.getApp() while it is still being built. null means nothing
	// to migrate.
	function initialize(app)
    {
		$.migrateLegacyPreferences(app);
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
