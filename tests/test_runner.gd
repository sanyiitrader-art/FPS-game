extends SceneTree
## Headless test runner. Run with:
##   godot --headless --path . --script res://tests/test_runner.gd
##
## Each suite is a script (extends RefCounted) with methods named test_*(t). The runner
## passes itself as t, so tests call t.check(...) and t.equal(...). The process exits with
## code 1 if any check failed. New suites are added to SUITES as the project grows.

const SUITES := [
	"res://tests/test_session.gd",
]

var checks := 0
var failures := 0
var tests_run := 0
var _context := ""


func _init() -> void:
	for path in SUITES:
		_run_suite(String(path))
	print("Tests finished: %d tests, %d checks, %d failed." % [tests_run, checks, failures])
	quit(1 if failures > 0 else 0)


func _run_suite(path: String) -> void:
	var script := load(path) as Script
	if script == null:
		failures += 1
		print("::error::Could not load test suite %s" % path)
		return
	var suite = script.new()
	var names: Array[String] = []
	for method in script.get_script_method_list():
		var method_name := String(method["name"])
		if method_name.begins_with("test_"):
			names.append(method_name)
	names.sort()
	print("== %s ==" % path.get_file())
	for method_name in names:
		_context = "%s::%s" % [path.get_file(), method_name]
		var before := failures
		tests_run += 1
		suite.call(method_name, self)
		print("  %s  %s" % ["ok  " if failures == before else "FAIL", method_name])


func check(condition: bool, message: String = "") -> void:
	checks += 1
	if not condition:
		failures += 1
		print("::error::%s: %s" % [_context, message])


func equal(actual: Variant, expected: Variant, message: String = "") -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])