extends SceneTree
## Headless test runner.
##
##   godot --headless --path client-godot --script res://tests/run_tests.gd
##
## Exits non-zero on any failure, so it drops into CI unchanged.

const Conformance := preload("res://core/protocol/conformance.gd")
const Harness := preload("res://tests/harness.gd")
const TestProtocol := preload("res://tests/test_protocol.gd")
const TestWorld := preload("res://tests/test_world.gd")

const VECTOR_DIR := "res://protocol/conformance"
## Ratchet. Raise it when tests are added; never lower it to make a run pass.
const MIN_CHECKS := 100


func _initialize() -> void:
	var failed := false

	print("== unit tests ==")
	var t := Harness.new()
	TestProtocol.run(t)
	TestWorld.run(t, self)
	for f in t.failures:
		print("  FAIL  %s" % f)
	print("  %d checks, %d failed" % [t.checks, t.failures.size()])
	failed = failed or not t.failures.is_empty()

	# A GDScript runtime error aborts the function it happens in, so the checks after it
	# never run -- and a harness that only counts failures would report zero. Fewer checks
	# than last time is itself a failure.
	if t.checks < MIN_CHECKS:
		print("  FAIL  expected at least %d checks, ran %d -- did a test abort early?"
			% [MIN_CHECKS, t.checks])
		failed = true

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
