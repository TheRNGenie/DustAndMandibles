class_name TestCase
extends RefCounted
## Base class for tests run by tests/run_tests.gd.

var failures: PackedStringArray = []


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("expected true. " + msg)


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		failures.append("expected false. " + msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		failures.append("expected %s, got %s. %s" % [str(expected), str(actual), msg])


func assert_almost(actual: float, expected: float, tolerance: float = 0.001, msg: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("expected %.4f, got %.4f. %s" % [expected, actual, msg])
