# Changelog

All notable changes to Glidator2 are listed here, newest first.

## 2.1.2

### Hiking: vertical speed and pace
- The vertical speed on the Pace page is now averaged over the last minute of data by default (or 3 or 5 minutes, see "VS window" below) instead of being read second by second, so it stays steady while walking. It is rounded to 10 m/h and shows "--" for the first 20 seconds or so, and beyond ±3000 m/h (altitude glitch or flight phase). The flight vario is unchanged.
- Pace is now computed from the distance covered over the last minute, so it keeps updating when the instant speed drops to zero. Values such as "5:60" can no longer appear; a pace slower than 60:00 /km shows "--:--".

### Hiking: map
- New scale bar at the bottom of the Map page (50 m up to 5 km), hidden when no round length fits the current zoom.
- Only GPS points with a good fix are added to the trail, and the trail stays on screen when the GPS fix is lost.

### Recording: pause, save on close
- Pressing SELECT while recording pauses the activity (the timer stops) and opens the Paused menu, which now offers Resume, Pause, Save and Ignore. BACK in this menu resumes, and the activity also resumes on its own after 30 seconds without a choice.
- New Pause choice: it opens a Paused screen with the frozen timer. The activity stays paused, with no automatic resume, until you press SELECT.
- While paused, the heart rate and temperature sensors are turned off (GPS stays on) and are turned back on when you resume. Pausing vibrates two short pulses, resuming one long pulse.
- If the app is closed by the watch while an activity is recording or paused, the activity is now saved instead of being lost.

### Preferences
- New "VS window" item in the MENU preferences: the time over which the hiking vertical speed is averaged, 1, 3 or 5 minutes (default 1 minute). Each press moves to the next value; the choice applies at once and is kept when the app restarts.
- Preferences are now stored with the current Connect IQ storage; the audio setting of the previous version is carried over on the first launch.

### Display
- Layout fixes on large round screens, checked on the Forerunner 265S, epix (Gen 2), epix Pro (Gen 2) 42 mm and fenix 8 43 mm: the timer and the middle values of the Hiking Position and Pace pages now fit inside the screen, the "Waiting for" / "GPS" lines of the Map page no longer overlap, and the battery line of the Time page sits below the time.
- Instinct 2: the Hiking Position and Pace pages are laid out around the round sub-window, and the speed line of the Flight Instrument page no longer runs into it.
- Missing or out-of-range readings now show "--" instead of odd numbers: hiking altitude (outside -100 to 6000 m), elevation gain, distance, heart rate (outside 25 to 250 bpm), and flight altitude (outside -500 to 9000 m, shown as "--" alone, without the "m" unit).

### Fixes
- Compass page (Flying mode): GPS coordinates are shown without a minus sign (the N/S and E/W letter gives the hemisphere), and seconds no longer read 60.0.
- Fixed a crash on the Compass page when no heading is available.

### Devices
- Added epix (Gen 2), and epix Pro (Gen 2) in 42, 47 and 51 mm.

## 2.1

- New Hiking mode: switch between Flying and Hiking by holding the BACK/LAP button for 1.5 seconds.
- Three Hiking pages: Position (altitude, elevation gain, distance, timer), Pace (heart rate, vertical speed, pace, timer) and a live GPS breadcrumb Map.
- A confirmation icon briefly appears on screen when recording starts.
- Expanded device support across the fenix, Forerunner and Instinct series.
- Fixed a crash that could occur right after starting the app, before the GPS had a fix.
