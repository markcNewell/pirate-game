extends RefCounted
## Base for test files: each `test_*` method runs once, and checks record failures
## instead of stopping, so one run reports every broken check.

var failures: Array[String] = []
var current := ""


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
