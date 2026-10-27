
# Glidator2 - The paragliding app

A Garmin Connect IQ app for hike&fly pilots to monitor and record activity data in real-time. Built in Monkey C, it leverages Garmin's GPS, barometer, and heart rate sensors to provide essential metrics for both flying and hiking. This project extends the original Glidator app by Gaetan Marti (https://github.com/gaetanmarti/glidator).

You can find the app in the Garmin IQ store under Glidator2

## Features
- **Two Modes**: Hiking and Flying, switched by holding the BACK/LAP button for 1.5 seconds. The app starts in Hiking mode.
- **Flying Mode**:
  - **Flight Instrument View**: Altitude (m), vertical speed / vario (m/s) with color-coded feedback (green for climb >0.3 m/s, red for sink <-2.0 m/s, gray for neutral), ground speed (km/h), and heading.
  - **Compass View**: Graphical compass with cardinal directions, degree markings, and GPS coordinates (degrees, minutes, seconds).
  - **Time & Battery View**: Shows current time and battery percentage with a graphical icon.
- **Hiking Mode**:
  - **Position View**: Altitude, elevation gain, distance, and elapsed timer in a 4-field grid.
  - **Pace View**: Heart rate, vertical speed, pace (min/km), and elapsed timer. The vertical speed reads "--" beyond ±3000 m/h (altitude glitch or flight phase); the flight vario is not capped.
  - **Map View**: Live breadcrumb trail of the current track with a heading-oriented position marker.
  - **Time & Battery View**: Shared with Flying mode.
- **Activity Recording**: Start, pause/resume, and save/ignore flight or hike sessions using Garmin's ActivityRecording API, with audio/vibration feedback and a start-recording confirmation icon.
- **Preferences**: Toggle audio beeps for climbing and pick the hike vertical-speed window (1, 3 or 5 min), both stored with `Application.Storage`; values saved by older versions are carried over on the first launch after the update.
- **Adaptive Layout**: The Hiking grid views scale their fonts and spacing to the device's screen size, tuned against the fenix6pro as a reference, so the layout stays clean from the smallest Instinct to the largest AMOLED Fenix/Forerunner screens.
- **Broad Device Support**: Fenix, Forerunner, and Instinct series watches.
- **Sensor Integration**: Uses GPS, barometer, and optional heart rate sensors, with fallbacks for unavailable data.

## Usage
- **Launch**: Start the app on your Garmin device to enter Hiking mode's Position View.
- **Navigation**: Use up/down keys to cycle through the pages of the current mode.
- **Mode Switch**: Hold BACK/LAP for 1.5 seconds to switch between Hiking and Flying mode (on the activity pages only: in the Paused menu any BACK press means Resume, and on the Paused screen BACK does nothing).
- **Recording** (SELECT / START button):
  - No session: SELECT starts recording.
  - Recording: SELECT pauses (the timer stops) and opens the **Paused** menu: Resume, Pause, Save, Ignore. BACK in this menu means Resume, and the activity also resumes on its own after 30 seconds without a choice.
  - **Pause** opens the Paused screen (it shows the current time, in the 12/24 h format of the watch; the recording timer is stopped). The activity stays paused there, with no automatic resume, until you press SELECT, which resumes and returns to the activity pages. BACK does nothing on this screen.
  - **Save** / **Ignore** end the activity (saved or discarded) and close the app.
  - Feedback: pausing vibrates two short pulses, resuming one long pulse.
  - While paused, the heart rate and temperature sensors are turned off (GPS stays on) and turned back on when you resume. The hike vertical speed and pace show "--" for about 20 seconds after resuming, until enough new data is collected.
- **What gets recorded**: The whole outing is recorded as a single SPORT_FLYING activity (shown as Sport="Other" in TCX exports; on watches whose firmware has no SPORT_FLYING, i.e. Connect IQ below 3.2 such as the fenix 5 and fenix 5X, it falls back to a SPORT_GENERIC activity), with the hike and the flight separated by a lap at each mode switch made while recording (a switch made while paused is not marked). If the app is closed by the system while a session is recording or paused, the session is saved rather than discarded.
- **Exit**: Press BACK while idle (no active session) to exit the app. While a session exists (recording or paused), a short BACK press on the activity pages does nothing; end the activity with SELECT, then Save or Ignore.
- **Preferences**: Press MENU to open preferences and enable/disable audio beeps, or set **Climb rate avg** (over 1, 3 or 5 min, default 1 min): the time over which the climb rate (vertical speed) shown on the hiking Pace page is averaged. 1 min follows changes of slope quickly but fluctuates more; 3 or 5 min gives a steadier value that reacts more slowly. Each press on "Climb rate avg" moves to the next value (1 → 3 → 5 → 1 min), shown under the item ("over 1 min", "over 3 min", "over 5 min"). This setting only affects the hiking climb rate display: it does not change the flight vario nor what is recorded in the activity. The choice is saved and applies at once, without losing the data already collected, and is kept when the app restarts. Until the window is filled, the value is computed over the data available (shown after about 20 seconds); pace always uses 1 minute.

## Technical Details
- **Language**: Monkey C
- **APIs**: Toybox (Application, WatchUi, Position, Activity, Sensor, ActivityRecording, Attention, Graphics, Math, System)
- **Files**:
  - `FlyInstrumentApp.mc`: Main app logic, sensor initialization, mode/view switching, and session recording.
  - `FlyInstrumentDelegate.mc`: Input handling (keys, menus, hold-to-switch-mode gesture).
  - `FlyInstrumentView.mc`: Flying mode's main view for flight metrics.
  - `PositionView.mc`: Flying mode's compass with GPS coordinates.
  - `HikePositionView.mc`: Hiking mode's altitude/elevation gain/distance/timer grid.
  - `HikePaceView.mc`: Hiking mode's heart rate/vertical speed/pace/timer grid.
  - `HikeMapView.mc`: Hiking mode's live breadcrumb map.
  - `BreadcrumbTrail.mc`: Ring buffer that records the live GPS trail for the Map view.
  - `TimeView.mc`: Time and battery display, shared by both modes.
  - `PausedView.mc`: Paused screen (current time, SELECT to resume).
  - `WatchData.mc`: Manages GPS, activity, and sensor data.
  - `WatchDisplay.mc`: Handles rendering of metrics, compass, and the adaptive hiking grid layout.
  - `Preferences.mc`: Manages user settings.
  - `Utils.mc`: Shared formatting helpers (e.g. duration formatting).
  - `Tests.mc`: Unit tests for shared helpers.
- **Notes**:
  - Type checking disabled for certain API calls to avoid Garmin SDK issues (e.g. optional `Info` fields that only exist on some devices/firmware).
  - Extensive logging with `Sys.println` for debugging.
  - Optimized for Garmin's device context (Dc) rendering; layouts are computed relative to screen width/height rather than hardcoded pixel positions so they work across the full range of supported screen sizes.

## Development

### Requirements
To develop and build Glidator2, you need the following tools:
- **Garmin Connect IQ SDK**: Download from [Garmin's Connect IQ SDK page](https://developer.garmin.com/connect-iq/sdk/). This includes the `monkeyc` compiler and `monkeydo` simulator.
- **Java Runtime Environment (JRE)**: Install JAVA 17 as required by the Connect IQ SDK.
- **VS Code with Connect IQ Extension**: Install Visual Studio Code and the [Connect IQ extension](https://marketplace.visualstudio.com/items?itemName=Garmin.connectiq). Configure the SDK path in VS Code settings (>MonkeyC: Verify installation).
- **Optional**: A compatible Garmin device for testing (e.g., Fenix, Forerunner, or Instinct series supporting Connect IQ).

### Setup
1. Install the Connect IQ SDK:
   - Download and extract the SDK to a directory (e.g., `~/connectiq-sdk`).
   - Set the `CONNECTIQ_HOME` environment variable to point to this directory.
2. Configure your IDE:
   - For Eclipse, import the project and set up the Connect IQ SDK path in Preferences > Connect IQ.
   - For VS Code, configure the SDK path in the Connect IQ extension settings.
3. Clone the repository: `git clone https://github.com/yourusername/glidator2.git`.

### Building and Running
- **Command Line**: Use `monkeyc` to compile the project:
  ```bash
  monkeyc -f monkey.jungle -o bin/Glidator2.prg -d <device_id> -y developer_key
  ```
  Replace `<device_id>` with your target device (e.g., `fenix7`, `fr965`, `instinct2`). Find supported devices in the SDK's `devices` folder. `-y` gives the private key used to sign the build (here `developer_key` at the repository root): `monkeyc` refuses to build without it.
- **IDE**:
  - In VS Code, use the Connect IQ extension's build task (Ctrl+Shift+B or Cmd+Shift+B).
  - In VS Code, open a .mc file of the source folder and use the "run and debug" button to build and run the app in the simulator.
- **Debugging**: Enable `Sys.println` logs in the code for debugging. View logs in the simulator's console or IDE output. Simulate GPS data via the simulator's "Location" settings.

### Trying it in the simulator
Playing a GPX track in the simulator moves the position along the track, but it does not pass the track's altitude and heart rate on as recorded (observed with SDK 9.2.0 on fenix6pro):
- **Altitude**: the app receives a transformed value (about 0.2 × the GPX elevation − 622 m, e.g. −257 m for 1826 m). Below about 2610 m of GPX elevation it is outside the −100..6000 m range of the hike pages, so ALTITUDE reads "--"; above, it shows a wrong negative value (about −100 to −86 m on the Salvan track). The vertical speed and the elevation gain are about 5 times too small, and the flight page shows a negative altitude.
- **Heart rate**: not sent at all, so Heart Rate reads "--".
- **GPS accuracy**: always 2 (2D fix). The map accepts it, so the trail is drawn.

These "--" come from the simulator, not from the app. To check altitude and heart rate, try the original FIT file of the activity (as recorded by the watch) in the simulator rather than a GPX export (not verified yet), or try the app on a watch.

### Installing on the watch
This installs a build of the current code on your own watch through a USB cable ("sideloading"), for example for a field test. It does not use the Connect IQ store.

**1. Create your developer key (once).** `monkeyc` signs every build with a private RSA key. Generate a 4096-bit key, then convert it to the unencrypted DER (PKCS#8) format that `monkeyc` expects. Keep the PEM file outside the repository (only `developer_key` is listed in `.gitignore`).

**Warning: if a `developer_key` already exists (in particular the key that signed the store version of Glidator2), do not create a new key. The commands below overwrite existing files without asking: `openssl genrsa` overwrites `~/garmin-keys/glidator_key.pem` and `openssl pkcs8` overwrites `developer_key`. A new key cannot update the published app.**

Run these commands from the repository root. First check whether a key already exists:
```bash
ls developer_key ~/garmin-keys/glidator_key.pem
```
- `developer_key` is listed: stop here and keep that key.
- Only `~/garmin-keys/glidator_key.pem` is listed: do not run `openssl genrsa`. Run only the `openssl pkcs8` and `chmod` commands below, which recreate `developer_key` from that existing PEM file.
- Both names print `No such file or directory`: run all the commands below. A key used for the store may also be kept elsewhere (for example one generated by the VS Code extension): look for it first.

The `pkcs8` command writes the key as `developer_key` at the root, the path used by every command in this README.
```bash
mkdir -p ~/garmin-keys
openssl genrsa -out ~/garmin-keys/glidator_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in ~/garmin-keys/glidator_key.pem -out developer_key -nocrypt
chmod 600 ~/garmin-keys/glidator_key.pem developer_key
```
`chmod 600` makes both files readable and writable only by your user. With OpenSSL 3 the commands print nothing when they succeed; other versions (OpenSSL 1.1, the LibreSSL `openssl` shipped with macOS) print progress dots and `e is 65537 (0x10001)`, which is normal. The commands were checked with OpenSSL 3.6 (Homebrew), where `genrsa` already writes a PKCS#8 PEM file; the LibreSSL `openssl` shipped with macOS writes a PKCS#1 PEM file instead, which `pkcs8 -topk8` also accepts (not tested with LibreSSL). Either way, `monkeyc` needs the DER file written by the `pkcs8` command, not the PEM file. The VS Code extension can also generate a key (>Monkey C: Generate a Developer Key).
- The key is **private**: never commit it (it is in `.gitignore`), never share it, and keep a backup copy somewhere safe. An app published on the store can only be updated with the key it was first signed with.
- **AI agents and scripts working on this repository must never open, read, print, copy or overwrite `developer_key`.** They may only pass its path to `monkeyc -y`.

**2. Find your watch id.** Pick the id of your exact model in the `<iq:products>` list of `manifest.xml`, e.g. `fenix6pro`, `fenix7`, `fenix847mm`, `fr265`, `instinct2`. The build is specific to that model: a build for another model may not start or may display badly.

**3. Build the `.prg` for that watch.** Make a normal build (without `-t`, which adds the unit tests):
```bash
mkdir -p /tmp/glidator-build
monkeyc -f monkey.jungle -o /tmp/glidator-build/Glidator2.prg -d fenix6pro -y developer_key
```
Replace `fenix6pro` with your watch id. The command prints `BUILD SUCCESSFUL` and writes `Glidator2.prg`. Any output folder works (`/tmp/glidator-build/` here keeps builds out of the repository).

**4. Copy the `.prg` to the watch.** Copy the `.prg` file, not a `.iq` file (the `.iq` package is for the Connect IQ store, the watch does not install it from a USB copy):
1. Plug the watch into the computer with its USB cable.
2. Open the watch storage and copy `Glidator2.prg` into the `GARMIN/Apps` folder (the folder name may be shown as `GARMIN/APPS`).
   - Older models (e.g. fenix 5) usually show up as a USB drive in Finder or File Explorer (not verified for each model).
   - Many recent models use MTP instead. On Windows they appear in File Explorer; on a Mac, Finder does not show them, so use a tool such as [OpenMTP](https://openmtp.ganeshrvel.com/) or the legacy Android File Transfer. Quit Garmin Express first if the tool cannot see the watch, as it may hold the connection.
3. Eject the watch (or close the MTP tool), then unplug it. The watch may take a few seconds to install the app.

If the store version of Glidator2 is already installed on the watch, removing it first (with the Connect IQ app on the phone or Garmin Express) avoids having two versions of the same app side by side (not verified).

**5. Start it on the watch.** The app is named **Glidator2** (from `resources/strings/strings.xml`). As a watch app, it is usually listed with the activities (press START on Fenix, Forerunner and Instinct watches) or in the Connect IQ apps list; on some models you may need to add it to the activity list first (Settings > Activities & Apps > Add). The exact menu depends on the model and firmware.

**Uninstalling.** Plug the watch in again and delete `Glidator2.prg` from `GARMIN/Apps`.

### Python tools tests
The activity analysis script `tools/analyze_activity.py` (Python 3, standard library only) has its own unit tests in `tools/test_analyze_activity.py`. Run them from the repository root with:
```bash
python3 -m unittest discover -s tools -p 'test_*.py'
```
The `-s tools -p 'test_*.py'` arguments are needed: a bare `python3 -m unittest` finds no test (`Ran 0 tests`).

### Exporting .iq File
- Package the app with the `-e` flag and sign it with your developer key (`-y`) to generate the `.iq` file for distribution (it builds every device of `manifest.xml`, which takes a few minutes):
  ```bash
  monkeyc -e -f monkey.jungle -o bin/Glidator2.iq -y developer_key
  ```
- Alternatively, in VS Code, select the >Monkey C: Export Project option, which packages the app with your developer key (that you can generate also with a Monkey C command ).
- The resulting `.iq` file is ready for sideloading or publishing.

### Publishing to Connect IQ Store
1. **Create a Developer Account**: Sign up at [Garmin's Developer Portal](https://developer.garmin.com/connect-iq/).
2. **Prepare App Metadata**:
   - Update the `manifest.xml` with your app's UUID, name, description, and supported devices.
   - Add icons, screenshots, and descriptions for the store listing.
3. **Upload to Connect IQ Store**:
   - Log in to the Garmin Developer Portal.
   - Create a new app listing, upload the `.iq` file, and fill in details (description, changelog, supported languages).
   - Submit for review. Garmin typically reviews apps within a few days.
4. **Sideloading for Testing**: Build a `.prg` for your watch and copy it to the `GARMIN/Apps` folder via USB, as described in [Installing on the watch](#installing-on-the-watch) (a `.iq` file is not installed by a USB copy).


## Credits
This app was adapted by Tim Kobler (with the help of Claude code) from the original Glidator app by Gaetan Marti (https://github.com/gaetanmarti/glidator). Thanks to Gaetan for open-sourcing the foundation, enabling further development for the gliding community.
