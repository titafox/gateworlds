extends RefCounted
## A single validation finding. `path` is an RFC 6901 JSON Pointer into the document; the
## empty string is the document root.

var code: String
var path: String
var detail: String


func _init(p_code: String, p_path: String, p_detail: String) -> void:
	code = p_code
	path = p_path
	detail = p_detail


## Identity for set comparison against a vector's expectations: code and location, not the
## human-readable detail. Two implementations must agree on what went wrong and where -- they
## are not required to phrase it identically.
func key() -> String:
	return "%s\t%s" % [code, path]


func _to_string() -> String:
	return "%s at %s: %s" % [code, "<root>" if path.is_empty() else path, detail]
