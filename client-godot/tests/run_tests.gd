extends SceneTree
## Headless test runner.
##
##   godot --headless --path client-godot --script res://tests/run_tests.gd
##
## Exits non-zero on any failure, so it drops into CI unchanged.

const Conformance := preload("res://core/protocol/conformance.gd")
const Harness := preload("res://tests/harness.gd")
const TestProtocol := preload("res://tests/test_protocol.gd")

const VECTOR_DIR := "res://protocol/conformance"


func _initialize() -> void:
	var failed := false

	print("== unit tests ==")
	var t := Harness.new()
	TestProtocol.run(t)
	for f in t.failures:
		print("  FAIL  %s" % f)
	print("  %d checks, %d failed" % [t.checks, t.failures.size()])
	failed = failed or not t.failures.is_empty()

	print("\n== conformance vectors ==")
	var outcomes := Conformance.run_dir(VECTOR_DIR)
	var passed := 0
	var bad: Array = []
	for o in outcomes:
		if o.passed():
			passed += 1
		else:
			bad.append(o)
	# The same rule the validator follows: report every failure, not just the first.
	for o in bad:
		print("  FAIL  %s" % o.name)
		print("        %s" % o.failure)
	print("  %d passed, %d failed, %d total" % [passed, bad.size(), outcomes.size()])

	if outcomes.size() < 27:
		# A runner reporting "0 failed" over an empty set looks exactly like success.
		print("  FAIL  expected at least 27 vectors, found %d" % outcomes.size())
		failed = true
	failed = failed or not bad.is_empty()

	print("\n%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)
