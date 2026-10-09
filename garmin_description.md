WARNING: The app is intended only as an in-flight aid and should not be used as a primary information source. If the app contains a barometric altimeter, it will not function in a pressurized aircraft and should not be used in a pressurized aircraft.

============================
What's new in 2.1.2
- Steadier hiking vertical speed: averaged over the last minute by default instead of second by second, rounded to 10 m/h, and shown as "--" beyond ±3000 m/h. The flight vario is unchanged.
- More reliable hiking pace, computed from the distance covered over the last minute (no more "5:60").
- New "VS window" preference: average the hiking vertical speed over 1, 3 or 5 minutes.
- Map: new scale bar, only good GPS fixes are added to the trail, and the trail stays visible when the GPS fix is lost.
- Real pause: the Paused menu now offers Resume, Pause, Save and Ignore. Pause keeps the activity paused, with the frozen timer on screen, until you press the select key. Without a choice, the menu resumes the activity after 30 seconds.
- Heart rate and temperature sensors are turned off while paused (GPS stays on).
- If the watch closes the app during an activity (recording or paused), the activity is now saved instead of being lost.
- Display fixes on large round screens and on Instinct watches: values and timer stay inside the screen and clear of the Instinct sub-window, and the Time page battery no longer overlaps the time.
- Missing or out-of-range readings (altitude, elevation gain, distance, heart rate) now show "--" instead of odd numbers.
- Compass page: coordinates without a minus sign, and a crash fixed when no heading is available.
- New devices: epix (Gen 2) and epix Pro (Gen 2).

============================
Overview
Glidator2 is a hike & fly companion with two modes: Flying and Hiking. In Flying mode it shows altitude, GPS heading, as well as vertical and horizontal speeds. In Hiking mode it shows altitude, elevation gain, distance, vertical speed, pace, heart rate, and a live GPS breadcrumb map. The app also supports activity recording in both modes, allowing pilots and hikers to save their sessions for later analysis.

============================
Credits 
This app is inspired by and based on the original Glidator app by Gaetan Marti (https://github.com/gaetanmarti/glidator)
The source code of Glidator2 is accessible via github : https://github.com/tkobler/Glidator2.git

============================
Navigation:
- The app starts in Hiking mode. Hold the back/lap button for 1.5 seconds to switch between Hiking and Flying mode.
- Press the up or down key to cycle between the pages of the current mode (Hiking: Position, Pace, Time, Map. Flying: Flight Instrument, Time, Position).
- Press the select key to start recording. Press select again to pause recording and open the Paused menu.
- Press the menu key to access the preferences menu: toggle audio feedback and set the VS window.
- Press the back key to exit the app when no session is being recorded.

Recording:
- Start recording by pressing the select key, indicated by a tone and vibration (if supported), and a start icon shown briefly on screen.
- Press the select key again to pause recording (the timer stops), then choose "Resume," "Pause," "Save," or "Ignore" from the Paused menu. Back in this menu resumes, and so does waiting 30 seconds without a choice.
- "Pause" shows the Paused screen with the frozen timer; the activity stays paused until you press select.
- If the watch closes the app while an activity is recording or paused, the activity is saved.

Monitoring:
Flying mode:
- FlyInstrumentView provides real-time altitude, vario, speed, and heading.
- PositionView shows a compass with GPS coordinates.
Hiking mode:
- HikePositionView shows altitude, elevation gain, distance, and elapsed timer.
- HikePaceView shows heart rate, vertical speed, pace, and elapsed timer.
- HikeMapView shows a live breadcrumb trail of your track with your current position and heading, and a scale bar.
Shared:
- TimeView displays the current time and battery status.
- Preferences: Enable or disable audio beeps for climbing, and set the VS window (1, 3 or 5 minutes) over which the hiking vertical speed is averaged. Each press on "VS window" moves to the next value.