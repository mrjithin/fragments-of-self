class_name JsonLoader
extends RefCounted
## Shared helper for loading JSON content files. Content is authored as JSON
## (per the design doc), loaded with FileAccess + JSON.parse_string.

static func load_dict(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("JsonLoader: cannot open %s (err %d)" % [path, FileAccess.get_open_error()])
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("JsonLoader: invalid JSON in %s" % path)
		return {}
	return parsed as Dictionary
