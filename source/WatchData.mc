using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Position;
using Toybox.System as Sys;

class WatchData
{
	var gpsData = null;
	var activityData = null;
	var sensorData = null;

	var oldAlt = null;
	
	//var vario = [];
	//const varioMaxSize = 7;
	var vario = null;

	function startMeasure ()
	{
		gpsData = null;
		activityData = null;
		sensorData = null;
	}
	
	
	function endMeasure ()
	{
		var alt = getAltitude ();
		if (alt != null)
		{
			if (oldAlt != null)
			{
				/*
				vario.add (alt - oldAlt);
				if (vario.size () > varioMaxSize)
				{
					vario = vario.slice (1, null);
				}
				*/
				vario = alt - oldAlt;
			}
			oldAlt = alt;
		}
	}

	function getVario ()
    {
    	return vario;
    }

	// Availability of data from the GPS
	// https://developer.garmin.com/connect-iq/api-docs/Toybox/Position/Info.html
	(:typecheck(false))
	// See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
	function updateInfo (info)
	{
		var data = {};
		
		// The elevation above mean sea level in meters (m).
		// If no GPS is present, then no valid elevation will be returned.
		if (info has :altitude)
        {
        	data ["altitude"] = info.altitude;
        }
        
        // If no GPS is available or is between GPS fix intervals (typically 1 second),
        // the position is propagated (i.e. dead-reckoned) using the last known heading
        // and last known speed. After a short period of time, the position will cease
        // to be propagated to avoid excessive accumulation of position errors.
        if (info has :position && info.position != null)
        {
        	data ["lat"]  = info.position.toDegrees()[0];
        	data ["long"] = info.position.toDegrees()[1];
        }
        
        // A value of 0 indicates an accuracy value is not available, while a value of 4 indicates a good GPS 
        if (info has :accuracy)
        {
        	data ["accuracy"] = info.accuracy;
        }
        
        // Speed is derived from the most accurate source in the following order:

		// 1. GPS
		// 2. Foot pod
		// 3. Accelerometer
        
        // Speed is in mps
        // A null speed is not stored: a "speed" => null key would win in getSpeed().
        if (info has :speed && info.speed != null)
        {
        	data ["speed"] = info.speed;
        }
        
        // The true north referenced heading in radians.
        // This provides the direction of travel when moving. If supported by the device, it provides compass orientation when stopped.
        if (info has :heading)
        {
        	data ["heading"] = info.heading;
        }
        
        // The GPS time stamp of the obtained Location fix.
        // Class: Toybox::Time::Moment
        // https://developer.garmin.com/connect-iq/api-docs/Toybox/Time/Moment.html
        if (info has :when)
        {
        	data ["when"] = info.when;
        }
        
        gpsData = data;
    }
    
	// https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity/Info.html
	function updateActivityInfo (info)
	{
		var data = {};
		
		// The current altitude in meters (m)
		if (info has :altitude)
        {
        	data ["altitude"] = info.altitude;
        }
        
        // The current heart rate in beats per minute (bpm). Not stored when null:
        // a "heartRate" => null key would hide the sensor heart rate in getHeartRate().
		if (info has :currentHeartRate && info.currentHeartRate != null)
        {
        	data ["heartRate"] = info.currentHeartRate;
        }

        // The true north referenced heading in radians.
        // WARNING: only provides compass information
		if (info has :currentHeading)
        {
        	data ["heading"] = info.currentHeading;
        }

        // The current speed in meters per second (mps). Not stored when null.
        if (info has :currentSpeed && info.currentSpeed != null)
        {
        	data ["speed"] = info.currentSpeed;
        }

        // The total ascent during the current activity in meters (m).
        if (info has :totalAscent)
        {
        	data ["totalAscent"] = info.totalAscent;
        }

        // The elapsed distance of the current activity in meters (m).
        if (info has :elapsedDistance)
        {
        	data ["distance"] = info.elapsedDistance;
        }

        // The current Timer value in milliseconds (ms).
        if (info has :timerTime)
        {
        	data ["timerTime"] = info.timerTime;
        }

    	activityData = data;
    }
    
    
    // https://developer.garmin.com/connect-iq/api-docs/Toybox/Sensor/Info.html
	(:typecheck(false))
	// See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    function updateSensorInfo (info)
	{
		var data = {};
		
		// Elevation is derived from the most accurate source: 
		// Barometer or GPS in order of descending accuracy.
		// If no GPS is present, then barometer readings will be used.
		if (info has :altitude)
        {
        	data ["altitude"] = info.altitude;
        }
        
        // The true north referenced heading in radians.
        // WARNING: only provides compass information
        // if (info has :heading) 
        // {
        // 	data ["heading"] = info.heading;
        // }
        
        
       	// The heart rate in beats per minute (bpm). Not stored when null.
		if (info has :heartRate && info.heartRate != null)
        {
        	data ["heartRate"] = info.heartRate;
        }
        
        // The speed in meters per second (m/s). Not stored when null, so that
        // getSpeed() falls back to the GPS speed.
        if (info has :speed && info.speed != null)
        {
        	data ["speed"] = info.speed;
        }
		// magnetometer data
        if (info has :magnetometer)
        {
            data["magnetometer"] = info.magnetometer;
        }

        
    	sensorData = data;
    }
      
    (:typecheck(false))
	// See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    function getAltitude ()
    {
    	if (activityData != null && activityData.hasKey("altitude"))
    	{
    		return activityData	["altitude"];
    	}
    
    	// Fitlered altitude data (seems to require GPS)
    	if (sensorData != null && sensorData.hasKey("altitude"))
    	{
    		return sensorData ["altitude"];
    	}
    
    	if (gpsData != null && gpsData.hasKey("altitude"))
    	{
    		return gpsData ["altitude"];
    	}
    	
    	return null;
    }
    
    (:typecheck(false))
	// See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    function getSpeed ()
    {
    	if (sensorData != null && sensorData.hasKey("speed"))
    	{
    		return sensorData ["speed"];
    	}

    	if (gpsData != null && gpsData.hasKey("speed"))
    	{
    		return gpsData ["speed"];
    	}

    	if (activityData != null && activityData.hasKey("speed"))
    	{
    		return activityData ["speed"];
    	}

    	return null;
    }
    
	(:typecheck(false))
	// See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    function getHeartRate ()
    {
    	if (activityData != null && activityData.hasKey("heartRate"))
    	{
    		return activityData	["heartRate"];
    	}

    	if (sensorData != null && sensorData.hasKey("heartRate"))
    	{
    		return sensorData ["heartRate"];
    	}

    	return null;
    }

    (:typecheck(false))
	// See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    function getTotalAscent ()
    {
    	if (activityData != null && activityData.hasKey("totalAscent"))
    	{
    		return activityData ["totalAscent"];
    	}

    	return null;
    }

    (:typecheck(false))
	// See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    function getDistance ()
    {
    	if (activityData != null && activityData.hasKey("distance"))
    	{
    		return activityData ["distance"];
    	}

    	return null;
    }

    (:typecheck(false))
	// See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    function getTimerTime ()
    {
    	if (activityData != null && activityData.hasKey("timerTime"))
    	{
    		return activityData ["timerTime"];
    	}

    	return null;
    }

    (:typecheck(false))
	// See https://forums.garmin.com/developer/connect-iq/i/bug-reports/the-type-checker-warns-about-info-field-even-after-checking-field-is-present
    function getHeading ()
    {
    	/*
    	// WARNING: only provides compass information
    	if (activityData != null && activityData.hasKey("heading"))
    	{
    		return activityData	["heading"];
    	}
    	// WARNING: only provides compass information
    	if (sensorData != null && sensorData.hasKey("heading"))
    	{
    		return sensorData ["heading"];
    	}
		*/
    	if (gpsData != null && gpsData.hasKey("heading"))
    	{
    		return gpsData ["heading"];
    	}
    	    	
    	return null;
    }

	function getNorth() {  //!!!!!!!
		if (activityData != null && activityData.hasKey("heading"))
    	{
    		return activityData	["heading"];
    	}
    	return null;

		// if (sensorData != null && sensorData.hasKey("magnetometer")) {
		// 	var mag = sensorData["magnetometer"];
		// 	if (mag != null && mag.size() == 3) {
		// 		var headingRad = Math.atan2(mag[1], mag[0]);
		// 		return headingRad >= 0 ? headingRad : headingRad + 2 * Math.PI;
		// 	}
		// }
		// return 0.0;
	}

	 // Get the latitude and longitude from the GPS data
	function getLat() {
		if (gpsData != null && gpsData.hasKey("lat")){
			return gpsData ["lat"];
		}
		return null;
	}

	// Get the longitude from the GPS data
	function getLon(){
		if (gpsData != null && gpsData.hasKey("long")){
			return gpsData ["long"];
		}
		return null;
	}

	// ---------------------------------------------------------------------
	// Map: GPS fix quality. Without a fix, Position.Info.position can be
	// (180, 180); such points must neither feed the breadcrumb trail nor be
	// shown as the current position.
	// ---------------------------------------------------------------------

	// Minimum Position.Info.accuracy for the map. QUALITY_USABLE is a 3D fix;
	// QUALITY_POOR (2D) would fill the trail better under trees or cliffs, at
	// the cost of less precise points. Single place to change that choice.
	const MIN_MAP_QUALITY = Position.QUALITY_USABLE;

	// Position.Info.accuracy (Position.QUALITY_*) from the last updateInfo(),
	// or null when unknown.
	(:typecheck(false))
	function getAccuracy()
	{
		if (gpsData != null && gpsData.hasKey("accuracy"))
		{
			return gpsData ["accuracy"];
		}
		return null;
	}

	// True when the last GPS data is good enough for the map: accuracy at
	// least MIN_MAP_QUALITY and a valid position (see isValidLatLon()).
	(:typecheck(false))
	function hasUsableFix()
	{
		var acc = getAccuracy();
		if (acc == null || acc < MIN_MAP_QUALITY)
		{
			return false;
		}
		return $.isValidLatLon(getLat(), getLon());
	}

	// ---------------------------------------------------------------------
	// Hike mode: windowed vertical speed and speed (HikeHistory.mc).
	// Fed once per tick from FlyInstrumentApp.onSensor(), after updateData().
	// Only reads getAltitude() / getDistance(): the flight vario (endMeasure,
	// getVario, oldAlt) is left alone.
	// The *At(ms) variants take the timestamp as a parameter for unit tests;
	// the app uses the System.getTimer() wrappers.
	// ---------------------------------------------------------------------

	const HIKE_WINDOW_MS = 60000;

	var hikeHistory = new HikeHistory();

	function recordHikeSample()
	{
		recordHikeSampleAt(Sys.getTimer());
	}

	function recordHikeSampleAt(tMs)
	{
		// HikeHistory ignores a null altitude; a null distance is kept as such.
		hikeHistory.add(tMs, getAltitude(), getDistance());
	}

	// m/h over the last 60 s, or null if not enough data.
	function getHikeVerticalSpeed()
	{
		return getHikeVerticalSpeedAt(Sys.getTimer());
	}

	function getHikeVerticalSpeedAt(nowMs)
	{
		return hikeHistory.verticalSpeedMh(nowMs, HIKE_WINDOW_MS);
	}

	// m/s over the last 60 s, or null if not enough data / no distance.
	function getHikeSpeed()
	{
		return getHikeSpeedAt(Sys.getTimer());
	}

	function getHikeSpeedAt(nowMs)
	{
		return hikeHistory.speedMps(nowMs, HIKE_WINDOW_MS);
	}
}