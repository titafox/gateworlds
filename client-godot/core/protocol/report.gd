extends RefCounted
## The outcome of validating one document.

const Codes := preload("res://core/protocol/codes.gd")
const Finding := preload("res://core/protocol/finding.gd")

var findings: Array = []


func is_ok() -> bool:
	return findings.is_empty()


func push(code: String, path: String, detail: String) -> void:
	findings.append(Finding.new(code, path, detail))


func extend(other: Array) -> void:
	findings.append_array(other)


## SPEC §11: report every error found, not only the first. A creator fixing one error per
## round trip through review is a bad experience, and a bad experience means fewer worlds.
##
## Applies the specificity rule, then sorts and dedupes so output is stable regardless of the
## order the checks ran in.
func finish():
	var specific_paths: Array[String] = []
	for f in findings:
		if Codes.is_specific(f.code):
			specific_paths.append(f.path)

	var kept: Array = []
	for f in findings:
		if Codes.is_specific(f.code):
			kept.append(f)
			continue
		var covered := false
		for sp in specific_paths:
			if sp == f.path or Codes.is_ancestor(f.path, sp):
				covered = true
				break
		if not covered:
			kept.append(f)

	kept.sort_custom(
		func(a, b):
			if a.path == b.path:
				return a.code < b.code
			return a.path < b.path
	)

	var deduped: Array = []
	var seen := {}
	for f in kept:
		var k: String = f.key()
		if not seen.has(k):
			seen[k] = true
			deduped.append(f)

	findings = deduped
	return self
