extends RefCounted
## The result of running one conformance vector.

var name := ""
var failure := ""
var report = null


func passed() -> bool:
	return failure.is_empty()
