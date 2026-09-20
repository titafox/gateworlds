extends RefCounted
## Facts a document cannot carry about itself.
##
## Stated explicitly by the caller -- a conformance vector declares it in `$vector.context`,
## a package loader derives it from the package it is reading. Never inferred from the
## expected outcome.

## The world that defines this document. Empty means item-namespace checking is skipped,
## because there is nothing to compare against.
var world_id := ""
## Item ids a `pickup` may reference.
var known_items: Dictionary = {}


func with_world_id(id: String):
	world_id = id
	return self


func with_items(ids: Array):
	for i in ids:
		known_items[i] = true
	return self
