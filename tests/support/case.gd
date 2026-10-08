extends RefCounted
## Base for test files: each `test_*` method runs once, and checks record failures
## instead of stopping, so one run reports every broken check.

var failures: Array[String] = []
var current := ""


## Every test starts from the same sea: a calm ServerSim (or a test) switches the storm off for
## everyone, and the order test files are found in is the file system's. (Here, not in the
## runner, which is compiled before the autoloads these classes need.)
func fresh_sea() -> void:
	Storm.enabled = true
	Storm.pin = Vector2.INF
	Daylight.override = -1.0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [current, message])


func check_eq(actual: Variant, expected: Variant, message := "") -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s %s" % [current, expected, actual, message])


func check_near(actual: float, expected: float, tolerance: float, message := "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append(
			"%s: expected %.4f ± %.4f, got %.4f %s" % [current, expected, tolerance, actual, message]
		)
