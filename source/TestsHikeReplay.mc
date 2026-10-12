using Toybox.Test;
using Toybox.Position;
using Toybox.System as Sys;

// ---------------------------------------------------------------------------
// End-to-end replay of the hike pages on the Salvan reference of 13/10
// (docs/verifications/2026-10-13-etalon-marche.md, data in
// docs/verifications/data/2026-10-13-etalon-marche-extrait-*.csv).
//
// Each row of an extract becomes one onSensor() tick: Position.Info,
// Activity.Info and Sensor.Info stand-ins -> WatchData (feedTick, endMeasure)
// -> recordHikeSampleAt() -> feedBreadcrumbTrail(). After each tick the
// fields are read the way the hike pages read them (formatter of the
// WatchData getter); after the last tick the real Position, Pace and Map
// pages are drawn on a fake Dc (ChainHelper, TestsChain.mc).
//
// Two worlds:
//   watch     : what a real fenix sends (all sources, GPX altitude and heart
//               rate, accuracy QUALITY_GOOD);
//   simulator : what the Connect IQ simulator sends while playing the GPX
//               (diagnostic of 12/10): altitude = 0.2 x GPX ele - 622 m in all
//               three sources (-254.9 m at 1835.6 m, out of the -100..6000 m
//               hike range), no heart rate (null), accuracy 2 (QUALITY_POOR)
//               on every tick. Since decision D6 (12/10) the map accepts it.
//
// Tolerances (written here, from the reference note): vertical speed
// +/-0.5 m/h (CSV rounded to 0.1 m/h, Float 32 bits on the watch), in the
// simulator world 0.2 x that (the slope scales with the altitude, the offset
// cancels); speed +/-0.001 m/s. Texts must match exactly.
//
// In a module: the 'globals' module of the device is limited to 253 members;
// a module is one member, and its data is compiled out of release builds.
// ---------------------------------------------------------------------------
(:test, :chaintest)
module HikeReplayTests
{

// Columns of a row: one GPX point of an extract.
const C_T = 0;        // s since the first point of the extract
const C_LAT = 1;      // deg
const C_LON = 2;      // deg
const C_ELE = 3;      // m, GPX ele
const C_HR = 4;       // bpm
const C_DIST = 5;     // m, TCX distance since the first point
const C_KEPT = 6;     // 1 when HikeHistory.add() keeps the sample
const C_DPLUS = 7;    // m, D+ (hysteresis 1 m) since the first point
const C_VS = 8;       // m/h, verticalSpeedMh(t, 60000); null = not enough data
const C_SPEED = 9;    // m/s, speedMps(t, 60000); null = not enough data
const C_ALT_TXT = 10; // ALTITUDE expected on a watch
const C_VS_TXT = 11;  // VERT. SPD. expected on a watch
const C_PACE_TXT = 12; // PACE expected

const VS_TOL_MH = 0.5;
const SIM_VS_TOL_MH = 0.1;   // 0.2 x VS_TOL_MH
const SPEED_TOL_MPS = 0.001;

// Simulator altitude transform measured on 12/10 (R^2 = 1.0000, 226 points).
const SIM_SCALE = 0.2;
const SIM_OFFSET_M = -622.0;

// The three extracts of the reference note, copied from the CSV files
// (columns t_s, lat, lon, ele, hr, dist_m, hh_garde, dplus_h1_m, hh_vs_mh,
// hh_vitesse_mps, aff_altitude, aff_vs, aff_pace; aff_fc is hr itself).
(:test, :chaintest)
class ReplayData
{
	// Montee reguliere: GPX 79..118 (lines 807..1197), 10:22:30 -> 10:24:02 UTC,
	// +661 m/h, 1.03 m/s, 16 samples kept. Holds the 4:13 check point (t = 26).
	static function regularClimb()
	{
		return [
			[0, 46.119512, 6.993112, 1835.6, 107, 0.00, 1, 0.0, null, null, "1836", "--", "--:--"],
			[1, 46.119524, 6.993109, 1835.8, 107, 1.31, 0, 0.0, null, null, "1836", "--", "--:--"],
			[2, 46.119531, 6.993105, 1836.0, 107, 2.06, 0, 0.0, null, null, "1836", "--", "--:--"],
			[4, 46.119545, 6.993089, 1836.4, 107, 4.03, 0, 0.0, null, null, "1836", "--", "--:--"],
			[6, 46.119562, 6.993064, 1836.8, 108, 6.71, 1, 1.2, null, null, "1837", "--", "--:--"],
			[7, 46.119576, 6.993051, 1836.8, 108, 8.59, 0, 1.2, null, null, "1837", "--", "--:--"],
			[8, 46.119590, 6.993043, 1837.2, 109, 10.14, 0, 1.6, null, null, "1837", "--", "--:--"],
			[9, 46.119602, 6.993042, 1837.2, 108, 11.45, 0, 1.6, null, null, "1837", "--", "--:--"],
			[10, 46.119604, 6.993034, 1837.2, 108, 12.07, 0, 1.6, null, null, "1837", "--", "--:--"],
			[12, 46.119613, 6.993013, 1837.6, 108, 13.94, 1, 2.0, null, null, "1838", "--", "--:--"],
			[13, 46.119616, 6.993001, 1838.0, 107, 15.00, 0, 2.4, null, null, "1838", "--", "--:--"],
			[16, 46.119640, 6.992970, 1838.6, 108, 18.47, 0, 3.0, null, null, "1839", "--", "--:--"],
			[18, 46.119656, 6.992941, 1839.0, 108, 21.24, 1, 3.4, null, null, "1839", "--", "--:--"],
			[19, 46.119669, 6.992935, 1839.0, 108, 22.82, 0, 3.4, null, null, "1839", "--", "--:--"],
			[24, 46.119716, 6.992906, 1839.8, 105, 28.42, 1, 4.2, 636.0, 1.1842, "1840", "+640", "14:04"],
			[26, 46.119735, 6.992898, 1840.2, 104, 30.56, 0, 4.6, 636.0, 1.1842, "1840", "+640", "14:04"],
			[33, 46.119802, 6.992869, 1841.4, 102, 38.44, 1, 5.8, 629.9, 1.1648, "1841", "+630", "14:18"],
			[36, 46.119827, 6.992853, 1842.0, 102, 41.44, 0, 6.4, 629.9, 1.1648, "1842", "+630", "14:18"],
			[38, 46.119849, 6.992849, 1842.4, 102, 43.93, 1, 6.8, 635.7, 1.1561, "1842", "+640", "14:25"],
			[42, 46.119882, 6.992838, 1843.0, 101, 47.66, 0, 7.4, 635.7, 1.1561, "1843", "+640", "14:25"],
			[44, 46.119900, 6.992835, 1843.4, 101, 49.68, 1, 7.8, 635.3, 1.1291, "1843", "+640", "14:46"],
			[49, 46.119943, 6.992814, 1844.6, 101, 54.87, 1, 9.0, 646.8, 1.1198, "1845", "+650", "14:53"],
			[50, 46.119954, 6.992815, 1844.8, 101, 56.09, 0, 9.2, 646.8, 1.1198, "1845", "+650", "14:53"],
			[52, 46.119972, 6.992809, 1845.2, 101, 58.11, 0, 9.6, 646.8, 1.1198, "1845", "+650", "14:53"],
			[54, 46.119993, 6.992807, 1845.6, 102, 60.51, 1, 10.0, 655.9, 1.1206, "1846", "+660", "14:52"],
			[58, 46.120034, 6.992801, 1846.4, 99, 65.04, 0, 10.8, 655.9, 1.1206, "1846", "+660", "14:52"],
			[59, 46.120040, 6.992796, 1846.6, 103, 65.83, 1, 11.0, 663.4, 1.1158, "1847", "+660", "14:56"],
			[60, 46.120044, 6.992793, 1846.8, 103, 66.26, 0, 11.2, 663.4, 1.1158, "1847", "+660", "14:56"],
			[63, 46.120052, 6.992797, 1847.0, 104, 66.96, 0, 11.4, 666.7, 1.1155, "1847", "+670", "14:56"],
			[66, 46.120078, 6.992798, 1847.2, 107, 69.86, 1, 11.6, 653.2, 1.0525, "1847", "+650", "15:50"],
			[69, 46.120103, 6.992791, 1848.0, 108, 72.74, 0, 12.4, 659.1, 1.0356, "1848", "+660", "16:06"],
			[70, 46.120112, 6.992790, 1848.2, 109, 73.69, 0, 12.6, 659.1, 1.0356, "1848", "+660", "16:06"],
			[74, 46.120153, 6.992795, 1849.2, 109, 78.34, 1, 13.6, 661.0, 1.0196, "1849", "+660", "16:21"],
			[78, 46.120196, 6.992806, 1850.0, 112, 83.09, 0, 14.4, 661.0, 1.0196, "1850", "+660", "16:21"],
			[79, 46.120201, 6.992806, 1850.2, 113, 83.66, 1, 14.6, 676.4, 1.0044, "1850", "+680", "16:36"],
			[82, 46.120224, 6.992813, 1850.8, 118, 86.38, 0, 15.2, 676.4, 1.0044, "1851", "+680", "16:36"],
			[86, 46.120257, 6.992812, 1851.4, 120, 89.98, 1, 15.8, 676.3, 0.9725, "1851", "+680", "17:08"],
			[88, 46.120276, 6.992817, 1852.0, 124, 92.06, 0, 16.4, 676.3, 0.9725, "1852", "+680", "17:08"],
			[91, 46.120292, 6.992813, 1852.2, 129, 93.85, 1, 16.6, 671.8, 0.9553, "1852", "+670", "17:27"],
			[92, 46.120299, 6.992808, 1852.2, 132, 94.73, 0, 16.6, 671.8, 0.9553, "1852", "+670", "17:27"]
		];
	}

	// Replat: GPX 934..973 (lines 9357..9747), 11:02:33 -> 11:05:10 UTC, slow
	// walk almost stopped for a minute: VS near 0, PACE through "--:--" and
	// back; 23 samples kept.
	static function flat()
	{
		return [
			[0, 46.124702, 6.980961, 2245.0, 145, 0.00, 1, 0.0, null, null, "2245", "--", "--:--"],
			[2, 46.124699, 6.980944, 2245.2, 144, 1.29, 0, 0.0, null, null, "2245", "--", "--:--"],
			[6, 46.124705, 6.980905, 2245.8, 143, 4.41, 1, 0.0, null, null, "2246", "--", "--:--"],
			[10, 46.124716, 6.980862, 2246.0, 142, 8.59, 0, 0.0, null, null, "2246", "--", "--:--"],
			[14, 46.124724, 6.980826, 2246.6, 138, 11.56, 1, 1.6, null, null, "2247", "--", "--:--"],
			[16, 46.124718, 6.980803, 2246.8, 139, 13.36, 0, 1.8, null, null, "2247", "--", "--:--"],
			[21, 46.124716, 6.980773, 2247.6, 137, 15.40, 1, 2.6, 435.2, 0.7333, "2248", "+440", "22:44"],
			[28, 46.124703, 6.980772, 2247.8, 137, 17.03, 1, 2.8, 374.8, 0.6082, "2248", "+370", "27:24"],
			[30, 46.124699, 6.980759, 2247.8, 137, 17.95, 0, 2.8, 374.8, 0.6082, "2248", "+370", "27:24"],
			[32, 46.124699, 6.980751, 2248.0, 134, 18.60, 0, 3.0, 374.8, 0.6082, "2248", "+370", "27:24"],
			[33, 46.124699, 6.980750, 2248.0, 137, 18.65, 1, 3.0, 335.2, 0.5652, "2248", "+340", "29:29"],
			[34, 46.124699, 6.980750, 2248.0, 137, 18.65, 0, 3.0, 335.2, 0.5652, "2248", "+340", "29:29"],
			[39, 46.124699, 6.980750, 2248.0, 137, 18.65, 1, 3.0, 288.2, 0.4782, "2248", "+290", "34:51"],
			[46, 46.124716, 6.980705, 2248.4, 140, 22.53, 1, 3.4, 259.4, 0.4898, "2248", "+260", "34:02"],
			[47, 46.124717, 6.980694, 2248.4, 140, 23.43, 0, 3.4, 259.4, 0.4898, "2248", "+260", "34:02"],
			[52, 46.124701, 6.980667, 2248.2, 141, 26.52, 1, 3.4, 222.9, 0.5100, "2248", "+220", "32:41"],
			[56, 46.124697, 6.980662, 2247.8, 141, 27.68, 0, 3.4, 222.9, 0.5100, "2248", "+220", "32:41"],
			[64, 46.124698, 6.980663, 2247.6, 138, 27.93, 1, 3.4, 117.8, 0.4055, "2248", "+120", "41:06"],
			[67, 46.124695, 6.980667, 2247.4, 135, 28.40, 0, 3.4, 68.3, 0.3274, "2247", "+70", "50:54"],
			[68, 46.124696, 6.980666, 2247.4, 134, 28.40, 0, 3.4, 68.3, 0.3274, "2247", "+70", "50:54"],
			[70, 46.124696, 6.980664, 2247.4, 131, 28.40, 1, 3.4, 31.8, 0.3007, "2247", "+30", "55:25"],
			[73, 46.124696, 6.980664, 2247.4, 128, 28.40, 0, 3.4, 31.8, 0.3007, "2247", "+30", "55:25"],
			[76, 46.124696, 6.980664, 2247.4, 125, 28.40, 1, 3.4, -26.8, 0.2364, "2247", "-30", "--:--"],
			[79, 46.124696, 6.980663, 2247.4, 122, 28.51, 0, 3.4, -26.8, 0.2364, "2247", "-30", "--:--"],
			[82, 46.124701, 6.980661, 2247.2, 119, 29.38, 1, 3.4, -55.5, 0.2287, "2247", "-60", "--:--"],
			[84, 46.124705, 6.980673, 2247.2, 118, 30.13, 0, 3.4, -55.5, 0.2287, "2247", "-60", "--:--"],
			[94, 46.124701, 6.980666, 2247.2, 116, 30.25, 1, 3.4, -80.1, 0.2109, "2247", "-80", "--:--"],
			[104, 46.124713, 6.980678, 2247.0, 117, 32.04, 1, 3.4, -84.6, 0.1640, "2247", "-80", "--:--"],
			[112, 46.124715, 6.980679, 2247.0, 120, 32.30, 1, 3.4, -62.4, 0.0963, "2247", "-60", "--:--"],
			[118, 46.124715, 6.980678, 2247.2, 119, 32.31, 1, 3.4, -31.2, 0.0811, "2247", "-30", "--:--"],
			[120, 46.124715, 6.980680, 2247.2, 119, 32.43, 0, 3.4, -31.2, 0.0811, "2247", "-30", "--:--"],
			[122, 46.124726, 6.980681, 2247.4, 119, 32.76, 0, 3.4, -31.2, 0.0811, "2247", "-30", "--:--"],
			[125, 46.124749, 6.980693, 2247.4, 117, 33.30, 1, 3.4, -10.6, 0.0891, "2247", "-10", "--:--"],
			[132, 46.124802, 6.980670, 2247.4, 114, 41.40, 1, 3.4, 2.9, 0.2321, "2247", "0", "--:--"],
			[138, 46.124804, 6.980672, 2247.2, 113, 42.88, 1, 3.4, 11.5, 0.2411, "2247", "+10", "--:--"],
			[141, 46.124793, 6.980699, 2247.2, 113, 45.26, 0, 3.4, 11.5, 0.2411, "2247", "+10", "--:--"],
			[143, 46.124792, 6.980697, 2247.2, 113, 46.56, 1, 3.4, 14.6, 0.3329, "2247", "+10", "50:04"],
			[145, 46.124801, 6.980680, 2247.4, 113, 48.18, 0, 3.4, 14.6, 0.3329, "2247", "+10", "50:04"],
			[149, 46.124815, 6.980662, 2247.2, 112, 49.82, 1, 3.4, 10.8, 0.3558, "2247", "+10", "46:50"],
			[157, 46.124816, 6.980660, 2247.2, 113, 50.19, 1, 3.4, 11.9, 0.3425, "2247", "+10", "48:40"]
		];
	}

	// Montee raide: GPX 1389..1428 (lines 13907..14297), 11:26:03 -> 11:27:18
	// UTC, +1309 m/h, HR up to 179 (the maximum of the outing), a 10.5 m GPS
	// jump at t = 24; 14 samples kept. The VS changes on the non-kept row
	// t = 72: the sample t = 11 leaves the 60 s window.
	static function steepClimb()
	{
		return [
			[0, 46.126456, 6.975624, 2473.4, 159, 0.00, 1, 0.0, null, null, "2473", "--", "--:--"],
			[1, 46.126462, 6.975626, 2473.6, 160, 0.54, 0, 0.0, null, null, "2474", "--", "--:--"],
			[3, 46.126472, 6.975622, 2474.4, 162, 1.72, 0, 0.0, null, null, "2474", "--", "--:--"],
			[5, 46.126479, 6.975603, 2475.4, 162, 3.32, 1, 2.0, null, null, "2475", "--", "--:--"],
			[6, 46.126477, 6.975588, 2475.8, 162, 4.45, 0, 2.4, null, null, "2476", "--", "--:--"],
			[9, 46.126489, 6.975581, 2476.6, 164, 6.47, 0, 3.2, null, null, "2477", "--", "--:--"],
			[11, 46.126501, 6.975577, 2477.4, 164, 7.89, 1, 4.0, null, null, "2477", "--", "--:--"],
			[12, 46.126505, 6.975575, 2477.8, 164, 8.29, 0, 4.4, null, null, "2478", "--", "--:--"],
			[14, 46.126509, 6.975554, 2478.6, 165, 9.97, 0, 5.2, null, null, "2479", "--", "--:--"],
			[16, 46.126510, 6.975530, 2479.0, 166, 11.87, 1, 5.6, null, null, "2479", "--", "--:--"],
			[17, 46.126503, 6.975526, 2479.6, 167, 12.24, 0, 6.2, null, null, "2480", "--", "--:--"],
			[20, 46.126511, 6.975487, 2480.6, 169, 15.13, 0, 7.2, null, null, "2481", "--", "--:--"],
			[21, 46.126498, 6.975480, 2481.4, 170, 16.29, 1, 8.0, 1329.4, 0.7757, "2481", "+1330", "21:29"],
			[24, 46.126417, 6.975550, 2481.6, 170, 26.81, 0, 8.2, 1329.4, 0.7757, "2482", "+1330", "21:29"],
			[26, 46.126372, 6.975609, 2482.4, 170, 33.38, 1, 9.0, 1270.8, 1.2838, "2482", "+1270", "12:59"],
			[27, 46.126372, 6.975602, 2483.2, 170, 33.79, 0, 9.8, 1270.8, 1.2838, "2483", "+1270", "12:59"],
			[30, 46.126374, 6.975586, 2484.4, 171, 34.60, 0, 11.0, 1270.8, 1.2838, "2484", "+1270", "12:59"],
			[32, 46.126354, 6.975578, 2485.2, 173, 36.86, 1, 11.8, 1299.4, 1.1519, "2485", "+1300", "14:28"],
			[33, 46.126348, 6.975575, 2485.4, 174, 37.45, 0, 12.0, 1299.4, 1.1519, "2485", "+1300", "14:28"],
			[36, 46.126343, 6.975521, 2486.4, 175, 41.57, 0, 13.0, 1299.4, 1.1519, "2486", "+1300", "14:28"],
			[37, 46.126350, 6.975511, 2486.6, 176, 42.42, 1, 13.2, 1287.9, 1.1465, "2487", "+1290", "14:32"],
			[39, 46.126363, 6.975489, 2487.2, 177, 43.01, 0, 13.8, 1287.9, 1.1465, "2487", "+1290", "14:32"],
			[40, 46.126354, 6.975484, 2487.8, 177, 44.09, 0, 14.4, 1287.9, 1.1465, "2488", "+1290", "14:32"],
			[43, 46.126332, 6.975467, 2488.8, 177, 46.77, 1, 15.4, 1284.9, 1.0877, "2489", "+1280", "15:19"],
			[45, 46.126334, 6.975450, 2489.4, 178, 47.59, 0, 16.0, 1284.9, 1.0877, "2489", "+1280", "15:19"],
			[46, 46.126335, 6.975443, 2490.0, 177, 48.20, 0, 16.6, 1284.9, 1.0877, "2490", "+1280", "15:19"],
			[49, 46.126328, 6.975413, 2491.0, 177, 49.64, 1, 17.6, 1285.6, 1.0131, "2491", "+1290", "16:27"],
			[50, 46.126330, 6.975403, 2491.2, 176, 50.38, 0, 17.8, 1285.6, 1.0131, "2491", "+1290", "16:27"],
			[53, 46.126320, 6.975402, 2492.2, 177, 51.38, 0, 18.8, 1285.6, 1.0131, "2492", "+1290", "16:27"],
			[56, 46.126302, 6.975397, 2493.4, 176, 53.18, 1, 20.0, 1282.9, 0.9496, "2493", "+1280", "17:33"],
			[58, 46.126304, 6.975374, 2494.2, 177, 54.80, 0, 20.8, 1282.9, 0.9496, "2494", "+1280", "17:33"],
			[59, 46.126303, 6.975370, 2494.6, 177, 55.04, 0, 21.2, 1282.9, 0.9496, "2495", "+1280", "17:33"],
			[61, 46.126305, 6.975363, 2496.8, 178, 56.36, 1, 23.4, 1326.1, 0.9471, "2497", "+1330", "17:36"],
			[66, 46.126319, 6.975324, 2497.4, 178, 60.42, 1, 24.0, 1331.2, 0.9551, "2497", "+1330", "17:27"],
			[68, 46.126322, 6.975321, 2497.8, 178, 60.85, 0, 24.4, 1331.2, 0.9551, "2498", "+1330", "17:27"],
			[69, 46.126321, 6.975318, 2498.0, 178, 60.85, 0, 24.6, 1331.2, 0.9551, "2498", "+1330", "17:27"],
			[70, 46.126327, 6.975315, 2498.6, 178, 61.59, 0, 25.2, 1331.2, 0.9551, "2499", "+1330", "17:27"],
			[71, 46.126332, 6.975314, 2498.8, 178, 61.59, 1, 25.4, 1316.0, 0.8950, "2499", "+1320", "18:37"],
			[72, 46.126330, 6.975320, 2500.8, 179, 62.03, 0, 27.4, 1319.1, 0.9040, "2501", "+1320", "18:26"],
			[75, 46.126325, 6.975315, 2501.0, 179, 62.73, 0, 27.6, 1319.1, 0.9040, "2501", "+1320", "18:26"]
		];
	}
}

// Replay engine. Options (String keys, no new symbol):
//   "sim"             simulator world (see the file header);
//   "noActivity"      Activity.getActivityInfo() returns null on every tick;
//   "noPosition"      Position.getInfo() returns null on every tick;
//   "noSensor"        Sensor.getInfo() returns null on every tick;
//   "activityHrNull"  Activity.Info.currentHeartRate is null (Sensor has it);
//   "activityAltNull" Activity.Info.altitude exists but is null (D1).
(:test, :chaintest, :typecheck(false))
class Replay
{
	static function simAltitude(ele)
	{
		return SIM_SCALE * ele + SIM_OFFSET_M;
	}

	static function on(opts, key)
	{
		return opts.hasKey(key) && opts[key] == true;
	}

	// One onSensor() tick for a row, the sample stamped tMs.
	static function tick(data, trail, row, tMs, opts)
	{
		var sim = on(opts, "sim");
		var alt = sim ? simAltitude(row[C_ELE]) : row[C_ELE];
		var hr = sim ? null : row[C_HR];

		var pos = null;
		if (!on(opts, "noPosition"))
		{
			pos = $.ChainHelper.gps(row[C_LAT], row[C_LON], sim ? Position.QUALITY_POOR : Position.QUALITY_GOOD, alt, null);
		}
		var act = null;
		if (!on(opts, "noActivity"))
		{
			act = $.ChainHelper.act(on(opts, "activityAltNull") ? null : alt, row[C_DIST],
				on(opts, "activityHrNull") ? null : hr, null, row[C_T] * 1000);
			// Garmin's own D+ is not in the files: the D+ h1 of the reference,
			// x 0.2 in the simulator world (its altitude is scaled).
			act.totalAscent = sim ? SIM_SCALE * row[C_DPLUS] : row[C_DPLUS];
		}
		var sens = on(opts, "noSensor") ? null : $.ChainHelper.sensor(alt, null, hr);

		$.WatchDataTestHelper.feedTick(data, pos, act, sens);
		data.endMeasure();
		if ($.shouldRecordHikeSample($.hasActiveSession(), $.isRecording()))
		{
			data.recordHikeSampleAt(tMs);
		}
		$.feedBreadcrumbTrail(trail, data);
	}

	// null expected: actual must be null too.
	static function nearOrNull(errs, label, actual, expected, tol)
	{
		if (expected == null)
		{
			if (actual != null)
			{
				errs.add(label + ": expected null, got " + actual);
			}
			return;
		}
		$.ChainHelper.near(errs, label, actual, expected, tol);
	}

	// Replays every row, checking after each tick what the pages would show.
	// Returns [data, trail, endMs]; endMs is the time stamp of the last row,
	// set 900 ms after now: the pages read System.getTimer(), and since every
	// sample time is a whole second, a render within 900 ms of this call sees
	// the same 60 s window as the last row (pages() checks it).
	static function run(errs, name, rows, opts)
	{
		var sim = on(opts, "sim");
		var noDistance = on(opts, "noActivity") || on(opts, "activityAltNull");
		var noSample = on(opts, "activityAltNull");
		var last = rows[rows.size() - 1][C_T];
		var t0 = Sys.getTimer() + 900 - last * 1000;

		var data = new WatchData();
		var trail = new BreadcrumbTrail();
		var kept = 0;
		for (var i = 0; i < rows.size(); i++)
		{
			var row = rows[i];
			var t = t0 + row[C_T] * 1000;
			tick(data, trail, row, t, opts);
			var label = name + " t=" + row[C_T] + "s";

			var altText = (sim || noSample) ? "--" : row[C_ALT_TXT];
			$.ChainHelper.expect(errs, label + " ALTITUDE", $.formatHikeAltitude(data.getAltitude()), altText);
			$.ChainHelper.expect(errs, label + " Heart Rate", $.formatHeartRate(data.getHeartRate()), sim ? "--" : row[C_HR].toString());

			if (!noSample && row[C_KEPT] == 1)
			{
				kept += 1;
			}
			$.ChainHelper.expectEq(errs, label + " samples kept", data.hikeHistory.getCount(), kept);

			var vs = data.getHikeVerticalSpeedAt(t);
			if (noSample)
			{
				nearOrNull(errs, label + " VS", vs, null, 0);
				$.ChainHelper.expect(errs, label + " VERT. SPD.", $.formatVerticalSpeed(vs), "--");
			}
			else if (sim)
			{
				nearOrNull(errs, label + " VS (0.2 x reference)", vs, row[C_VS] == null ? null : SIM_SCALE * row[C_VS], SIM_VS_TOL_MH);
			}
			else
			{
				nearOrNull(errs, label + " VS", vs, row[C_VS], VS_TOL_MH);
				$.ChainHelper.expect(errs, label + " VERT. SPD.", $.formatVerticalSpeed(vs), row[C_VS_TXT]);
			}

			var sp = data.getHikeSpeedAt(t);
			nearOrNull(errs, label + " speed", sp, noDistance ? null : row[C_SPEED], SPEED_TOL_MPS);
			$.ChainHelper.expect(errs, label + " PACE", $.formatPace(sp), noDistance ? "--:--" : row[C_PACE_TXT]);
		}
		return [data, trail, t0 + last * 1000];
	}

	// The trail must be exactly the one built from every row's position
	// (expectAll) or stay empty.
	static function checkTrail(errs, name, trail, rows, expectAll)
	{
		if (!expectAll)
		{
			$.ChainHelper.expectEq(errs, name + " trail points", trail.getCount(), 0);
			return;
		}
		var reference = new BreadcrumbTrail();
		for (var i = 0; i < rows.size(); i++)
		{
			reference.update(rows[i][C_LAT], rows[i][C_LON]);
		}
		if (reference.getCount() < 2)
		{
			errs.add(name + " setup: reference trail of " + reference.getCount() + " points");
		}
		$.ChainHelper.expectEq(errs, name + " trail points", trail.getCount(), reference.getCount());
		var n = (trail.getCount() < reference.getCount()) ? trail.getCount() : reference.getCount();
		for (var i = 0; i < n; i++)
		{
			if (trail.getLats()[i] != reference.getLats()[i] || trail.getLons()[i] != reference.getLons()[i])
			{
				errs.add(name + " trail point " + i + " differs from the reference");
			}
		}
	}

	// The three hike pages drawn after the last row. position / pace:
	// "ALTITUDE|ELEV. GAIN|DISTANCE|TIMER" and "Heart Rate|VERT. SPD.|PACE|TIMER".
	static function pages(errs, name, r, position, pace, mapWaiting)
	{
		var data = r[0];
		$.ChainHelper.expect(errs, name + " Pace page", $.ChainHelper.pace(data), pace);
		var late = Sys.getTimer() - r[2];
		if (late > 0)
		{
			errs.add(name + ": Pace page drawn " + late + " ms after the last sample (window may differ)");
		}
		$.ChainHelper.expect(errs, name + " Position page", $.ChainHelper.position(data), position);
		var map = $.ChainHelper.map(data, r[1]);
		if (mapWaiting)
		{
			$.ChainHelper.expect(errs, name + " Map page", map, "Waiting for|GPS");
		}
		else if (map.find("Waiting") != null)
		{
			errs.add(name + " Map page: expected the trail, got \"" + map + "\"");
		}
	}

	// Common body: session recording, replay, trail, pages.
	static function check(logger, name, rows, opts, trailAll, position, pace)
	{
		$.ChainHelper.reset();
		$.session = new $.FakeSession(true);
		var errs = [];
		var r = run(errs, name, rows, opts);
		checkTrail(errs, name, r[1], rows, trailAll);
		pages(errs, name, r, position, pace, !trailAll);
		return $.ChainHelper.finish(errs, logger);
	}
}

// ---------------------------------------------------------------------------
// Watch world: every displayed value matches the reference, row by row.
// Final pages: ELEV. GAIN is the D+ h1 fed as Activity totalAscent, DISTANCE
// the TCX distance since the first point, TIMER the extract time.
// ---------------------------------------------------------------------------

(:test, :chaintest, :typecheck(false))
function testReplayRegularClimbWatch(logger)
{
	return Replay.check(logger, "regular/watch", ReplayData.regularClimb(), {}, true,
		"1852|17|0.1|01:32", "132|+670|17:27|01:32");
}

(:test, :chaintest, :typecheck(false))
function testReplayFlatWatch(logger)
{
	return Replay.check(logger, "flat/watch", ReplayData.flat(), {}, true,
		"2247|3|0.1|02:37", "113|+10|48:40|02:37");
}

(:test, :chaintest, :typecheck(false))
function testReplaySteepClimbWatch(logger)
{
	return Replay.check(logger, "steep/watch", ReplayData.steepClimb(), {}, true,
		"2501|28|0.1|01:15", "179|+1320|18:26|01:15");
}

// ---------------------------------------------------------------------------
// Simulator world (accuracy 2, altitude 0.2 x ele - 622 m, no heart rate):
// ALTITUDE and Heart Rate read "--" on every row (out of range / null, the
// simulator's doing, nothing forced in the app); VERT. SPD. is 0.2 x the
// reference; PACE is unchanged (the distance is not transformed); the map
// draws the trail (D6: QUALITY_POOR accepted) instead of "Waiting for GPS".
// Final VS: 0.2 x 671.8 = 134.4 -> "+130"; 0.2 x 11.9 = 2.4 -> "0";
// 0.2 x 1319.1 = 263.8 -> "+260". ELEV. GAIN: 0.2 x D+ h1 (3.3, 0.7, 5.5).
// ---------------------------------------------------------------------------

(:test, :chaintest, :typecheck(false))
function testReplayRegularClimbSimulator(logger)
{
	return Replay.check(logger, "regular/sim", ReplayData.regularClimb(), { "sim" => true }, true,
		"--|3|0.1|01:32", "--|+130|17:27|01:32");
}

(:test, :chaintest, :typecheck(false))
function testReplayFlatSimulator(logger)
{
	return Replay.check(logger, "flat/sim", ReplayData.flat(), { "sim" => true }, true,
		"--|1|0.1|02:37", "--|0|48:40|02:37");
}

(:test, :chaintest, :typecheck(false))
function testReplaySteepClimbSimulator(logger)
{
	return Replay.check(logger, "steep/sim", ReplayData.steepClimb(), { "sim" => true }, true,
		"--|6|0.1|01:15", "--|+260|18:26|01:15");
}

// ---------------------------------------------------------------------------
// One source null while the others are not (watch world).
// ---------------------------------------------------------------------------

// No Activity.Info: altitude and heart rate come from Sensor.Info (same
// values), VS as the reference; no distance, so PACE "--:--" and DISTANCE,
// ELEV. GAIN and TIMER "--" even with a session.
(:test, :chaintest, :typecheck(false))
function testReplaySourceActivityNull(logger)
{
	return Replay.check(logger, "regular/no Activity", ReplayData.regularClimb(), { "noActivity" => true }, true,
		"1852|--|--|--:--", "132|+670|--:--|--:--");
}

// Activity.Info without heart rate: Heart Rate comes from Sensor.Info.
(:test, :chaintest, :typecheck(false))
function testReplaySourceActivityHrNullUsesSensor(logger)
{
	return Replay.check(logger, "steep/Activity HR null", ReplayData.steepClimb(), { "activityHrNull" => true }, true,
		"2501|28|0.1|01:15", "179|+1320|18:26|01:15");
}

// No Sensor.Info: everything comes from Activity.Info, nothing changes.
(:test, :chaintest, :typecheck(false))
function testReplaySourceSensorNull(logger)
{
	return Replay.check(logger, "flat/no Sensor", ReplayData.flat(), { "noSensor" => true }, true,
		"2247|3|0.1|02:37", "113|+10|48:40|02:37");
}

// No Position.Info: no trail and "Waiting for GPS"; the other pages unchanged.
(:test, :chaintest, :typecheck(false))
function testReplaySourcePositionNull(logger)
{
	return Replay.check(logger, "regular/no Position", ReplayData.regularClimb(), { "noPosition" => true }, false,
		"1852|17|0.1|01:32", "132|+670|17:27|01:32");
}

// KNOWN POINT, NOT FIXED (decision pending): Activity.Info.altitude present
// but null hides the Sensor altitude (D1, getAltitude() unchanged), and
// HikeHistory.add() (HikeHistory.mc:32-35) drops the whole sample when the
// altitude is null, distance included: VERT. SPD. "--" and PACE "--:--" on
// every row although DISTANCE moves on. See "Defaut de l'app trouve" and
// "PACE couple a l'altitude" in docs/verifications/2026-10-13-etalon-marche.md.
// This pins the current behaviour; update it if that decision changes.
(:test, :chaintest, :typecheck(false))
function testReplayActivityAltitudeNullDropsPaceKnownPoint(logger)
{
	return Replay.check(logger, "regular/Activity altitude null", ReplayData.regularClimb(), { "activityAltNull" => true }, true,
		"--|17|0.1|01:32", "132|--|--:--|01:32");
}

// ---------------------------------------------------------------------------
// Map with the simulator's QUALITY_POOR (D6): every GPX position enters the
// trail, while (180, 180), (0, 0), a null position, and a LAST_KNOWN or
// NOT_AVAILABLE accuracy are still rejected. Also the simulator's values
// before and around the GPX: -255 m without position (default), -256.8 m
// (1826 m of the GPX): ALTITUDE "--".
// ---------------------------------------------------------------------------
(:test, :chaintest, :typecheck(false))
function testReplayMapPoorFixRejectsInvalidPoints(logger)
{
	$.ChainHelper.reset();
	var errs = [];
	var rows = ReplayData.regularClimb();
	var data = new WatchData();
	var trail = new BreadcrumbTrail();

	// Simulator default before the GPX plays: no position, accuracy 0, -255 m.
	$.WatchDataTestHelper.feedTick(data, $.ChainHelper.gps(null, null, Position.QUALITY_NOT_AVAILABLE, -255.0, null),
		null, $.ChainHelper.sensor(-255.0, null, null));
	$.feedBreadcrumbTrail(trail, data);
	$.ChainHelper.expect(errs, "before the GPX, Map page", $.ChainHelper.map(data, trail), "Waiting for|GPS");
	$.ChainHelper.expect(errs, "before the GPX, Position page", $.ChainHelper.position(data), "--|--|--|--:--");

	var invalid = [
		[180.0, 180.0, Position.QUALITY_POOR],
		[0.0, 0.0, Position.QUALITY_POOR],
		[null, null, Position.QUALITY_POOR],
		[46.2, 7.1, Position.QUALITY_LAST_KNOWN],
		[46.2, 7.1, Position.QUALITY_NOT_AVAILABLE]
	];
	for (var i = 0; i < rows.size(); i++)
	{
		var row = rows[i];
		var alt = Replay.simAltitude(row[C_ELE]);
		$.WatchDataTestHelper.feedTick(data, $.ChainHelper.gps(row[C_LAT], row[C_LON], Position.QUALITY_POOR, alt, null), null, null);
		$.ChainHelper.expectEq(errs, "t=" + row[C_T] + "s POOR fix usable", data.hasUsableFix(), true);
		$.feedBreadcrumbTrail(trail, data);

		if (i % 8 == 3)
		{
			var count = trail.getCount();
			for (var j = 0; j < invalid.size(); j++)
			{
				$.WatchDataTestHelper.feedTick(data, $.ChainHelper.gps(invalid[j][0], invalid[j][1], invalid[j][2], alt, null), null, null);
				$.ChainHelper.expectEq(errs, "t=" + row[C_T] + "s invalid " + j + " usable", data.hasUsableFix(), false);
				$.feedBreadcrumbTrail(trail, data);
			}
			$.ChainHelper.expectEq(errs, "t=" + row[C_T] + "s invalid points not in the trail", trail.getCount(), count);
		}
	}
	Replay.checkTrail(errs, "POOR replay", trail, rows, true);
	var map = $.ChainHelper.map(data, trail);
	if (map.find("Waiting") != null)
	{
		errs.add("Map page after the replay: expected the trail, got \"" + map + "\"");
	}

	// What the simulator sends at 1826 m of the GPX (diagnostic of 12/10).
	var lastRow = rows[rows.size() - 1];
	$.WatchDataTestHelper.feedTick(data, $.ChainHelper.gps(lastRow[C_LAT], lastRow[C_LON], Position.QUALITY_POOR, -256.8, null),
		null, $.ChainHelper.sensor(-256.8, null, null));
	$.ChainHelper.near(errs, "-256.8 m reaches getAltitude()", data.getAltitude(), -256.8, 0.001);
	$.ChainHelper.expect(errs, "-256.8 m, Position page", $.ChainHelper.position(data), "--|--|--|--:--");
	$.ChainHelper.expectEq(errs, "-256.8 m tick, fix still usable", data.hasUsableFix(), true);
	return $.ChainHelper.finish(errs, logger);
}

} // module HikeReplayTests
