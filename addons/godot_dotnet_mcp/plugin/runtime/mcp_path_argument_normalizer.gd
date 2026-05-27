@tool
extends RefCounted
class_name MCPPathArgumentNormalizer


static func normalize_project_path(path_value: String, allowed_extensions: Array[String], subject: String, allow_empty: bool = false) -> Dictionary:
	var path := path_value.strip_edges().uri_decode().replace("\\", "/")
	if path.is_empty():
		if allow_empty:
			return {"success": true, "path": ""}
		return {"success": false, "error": "Invalid %s: %s" % [subject, path_value]}
	if path.begins_with("/"):
		return {"success": false, "error": "Invalid %s: %s" % [subject, path_value]}
	if path.find("://") != -1 and not path.begins_with("res://"):
		return {"success": false, "error": "%s must use res://." % subject.capitalize()}
	if path.find(":") != -1 and not path.begins_with("res://"):
		return {"success": false, "error": "%s must be project-relative." % subject.capitalize()}
	if path.begins_with("res://"):
		path = path.substr("res://".length())
	var parts := path.split("/", false)
	if parts.is_empty():
		return {"success": false, "error": "Invalid %s: %s" % [subject, path_value]}
	for part in parts:
		if part.is_empty() or part == "." or part == "..":
			return {"success": false, "error": "Invalid %s: %s" % [subject, path_value]}
	var normalized := "res://%s" % "/".join(parts)
	var lower_path := normalized.to_lower()
	for extension in allowed_extensions:
		if lower_path.ends_with(extension):
			return {"success": true, "path": normalized}
	return {"success": false, "error": "%s has an unsupported extension." % subject.capitalize()}
