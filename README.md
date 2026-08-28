
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
  - **Pace View**: Heart rate, vertical speed, pace (min/km), and elapsed timer.
  - **Map View**: Live breadcrumb trail of the current track with a heading-oriented position marker.
  - **Time & Battery View**: Shared with Flying mode.
- **Activity Recording**: Start, pause/resume, and save-or-discard flight or hike sessions using Garmin's ActivityRecording API, with audio/vibration feedback and a start-recording confirmation icon.
- **Preferences**: Toggle audio beeps for climbing, stored via Application Storage.
- **Adaptive Layout**: The Hiking grid views scale their fonts and spacing to the device's screen size, tuned against the fenix6pro as a reference, so the layout stays clean from the smallest Instinct to the largest AMOLED Fenix/Forerunner screens.
- **Broad Device Support**: Fenix, Forerunner, and Instinct series watches.
- **Sensor Integration**: Uses GPS, barometer, and optional heart rate sensors, with fallbacks for unavailable data.

## Usage
- **Launch**: Start the app on your Garmin device to enter Hiking mode's Position View.
- **Navigation**: Use up/down keys to cycle through the pages of the current mode.
- **Mode Switch**: Hold BACK/LAP for 1.5 seconds to switch between Hiking and Flying mode.
- **Recording**: Press SELECT to start recording. Pressing SELECT again pauses recording and opens a Resume/Save/Discard menu.
- **Exit**: Press BACK while idle (no active session) to exit the app.
- **Preferences**: Press MENU to open preferences and enable/disable audio beeps.

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
To develop and build Glidator, you need the following tools:
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
  monkeyc -f monkey.jungle -o bin/Glidator.prg -d <device_id>
  ```
  Replace `<device_id>` with your target device (e.g., `fenix7`, `fr965`, `instinct2`). Find supported devices in the SDK's `devices` folder.
- **IDE**:
  - In VS Code, use the Connect IQ extension's build task (Ctrl+Shift+B or Cmd+Shift+B).
  - In VS Code, open a .mc file of the source folder and use the "run and debug" button to build and run the app in the simulator.
- **Debugging**: Enable `Sys.println` logs in the code for debugging. View logs in the simulator's console or IDE output. Simulate GPS data via the simulator's "Location" settings.

### Exporting .iq File
- Compile the app with the `-r` flag to generate a signed `.iq` file for distribution:
  ```bash
  monkeyc -f monkey.jungle -o bin/Glidator.iq -r
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
4. **Sideloading for Testing**: Transfer the `.iq` file to a compatible Garmin device via USB (place in the `GARMIN/Apps` folder) or use the Connect IQ mobile app.


## Credits
This app was adapted by Tim Kobler (with the help of Claude code) from the original Glidator app by Gaetan Marti (https://github.com/gaetanmarti/glidator). Thanks to Gaetan for open-sourcing the foundation, enabling further development for the gliding community.
