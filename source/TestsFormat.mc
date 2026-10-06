using Toybox.Test;

// Unit tests of the display formatters in Utils.mc that bound what the hike
// pages and the compass show (defects D2 hike page, D3, D5, D6, D7, D8 of the
// test plan; display bounds decided on 2026-10-06).

// D6: a negative duration has no meaning on a timer: "--:--". Everything
// from 0 up is unchanged (testFormatDuration in Tests.mc).
(:test)
function testFormatDurationNegative(logger)
{
	Test.assertEqualMessage(formatDuration(-1), "--:--", "-1 ms (bound just below 0)");
	Test.assertEqualMessage(formatDuration(-999), "--:--", "-999 ms (was 00:00)");
	Test.assertEqualMessage(formatDuration(-1000), "--:--", "-1 s (was 00:-1)");
	Test.assertEqualMessage(formatDuration(-65000), "--:--", "-65 s (was -1:-5)");
	Test.assertEqualMessage(formatDuration(-3600000), "--:--", "-1 h");
	Test.assertEqualMessage(formatDuration(-0.5), "--:--", "negative Float");
	Test.assertEqualMessage(formatDuration(0), "00:00", "0 is still valid (bound)");
	Test.assertEqualMessage(formatDuration(-0.0), "00:00", "-0.0 is zero, not negative");
	Test.assertEqualMessage(formatDuration(999), "00:00", "999 ms still truncated to 00:00");
	return true;
}
