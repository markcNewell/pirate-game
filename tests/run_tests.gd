extends SceneTree
## Runs every tests/test_*.gd file headless:
##   godot --headless --path . -s tests/run_tests.gd
## TEST_ONLY=story runs only the files whose names contain "story".
## Exits 1 if any check failed or any script error was logged, so CI can gate on it.


## Counts engine and script errors, which GDScript cannot catch, so a test that crashes
## half-way still fails the run instead of passing silently.
class ErrorCounter:
	extends Logger

	var count := 0
	var last := ""

	func _log_error(
		function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		count += 1
		last = "%s (%s:%d %s)" % [rationale if rationale else code, file, line, function]


func _initialize() -> void:
	var errors := ErrorCounter.new()
	OS.add_logger(errors)

	var only := OS.get_environment("TEST_ONLY")
	var files: Array[String] = []
	for file in DirAccess.get_files_at("res://tests"):
		if file.begins_with("test_") and file.ends_with(".gd") and (only == "" or file.contains(only)):
			files.append(file)
	files.sort()

	var total := 0
	var failures: Array[String] = []
	for file in files:
		var before := errors.count
		var script: GDScript = load("res://tests/" + file)
		if script == null or errors.count > before:
			failures.append("%s did not compile: %s" % [file, errors.last])
			continue
		var suite: RefCounted = script.new()
		for method in suite.get_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			suite.current = "%s %s" % [file, name]
			before = errors.count
			suite.call(name)
			if errors.count > before:
				suite.failures.append("%s: script error: %s" % [suite.current, errors.last])
			total += 1
		failures.append_array(suite.failures)

	for failure in failures:
		printerr("FAIL ", failure)
	print("%d tests, %d failures" % [total, failures.size()])
	OS.remove_logger(errors)
	quit(1 if failures.size() > 0 else 0)
