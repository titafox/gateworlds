extends RefCounted
## A test collector small enough that it needs no explanation and no dependency.

var failures: Array[String] = []
var checks := 0
var _group := ""

func group(name: String) -> void:
	_group = name

func ok(condition: bool, what: String) -> void:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [_group, what])

func eq(actual: Variant, expected: Variant, what: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("%s: %s\n      expected: %s\n      actual:   %s"
			% [_group, what, str(expected), str(actual)])
