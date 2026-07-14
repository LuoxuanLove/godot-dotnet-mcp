extends RefCounted

const EntryServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_registry_entry_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var service = EntryServiceScript.new()
	var source_error := {
		"category": "broken",
		"path": "res://broken.gd",
		"message": "Failed to load",
		"source": "builtin"
	}
	var first_system_entry := {
		"category": "system",
		"path": "res://system_a.gd",
		"source": "builtin",
		"nested": {"value": "first"}
	}
	var index: Dictionary = service.build_index({
		"errors": [source_error],
		"entries": [
			first_system_entry,
			{"category": "", "path": "res://blank.gd", "source": "builtin"},
			{"category": "bad category", "path": "res://invalid.gd", "source": "builtin"},
			{"category": "project", "path": "res://project.gd", "source": "builtin"},
			{"category": "system", "path": "res://system_duplicate.gd", "source": "user"}
		]
	})

	var entries_by_category = index.get("entries_by_category", {})
	if not (entries_by_category is Dictionary):
		return _failure("Entry service should return an entries_by_category dictionary.")
	var entries_dict := entries_by_category as Dictionary
	if entries_dict.size() != 2 or not entries_dict.has("system") or not entries_dict.has("project"):
		return _failure("Entry service should index only non-empty first-seen categories.")
	if str((entries_dict.get("system", {}) as Dictionary).get("path", "")) != "res://system_a.gd":
		return _failure("Entry service should preserve the first duplicate category entry.")

	var ordered_categories = index.get("ordered_categories", [])
	if not (ordered_categories is Array) or (ordered_categories as Array) != ["system", "project"]:
		return _failure("Entry service should preserve first-seen registry category order.")

	var load_errors = index.get("load_errors", [])
	if not (load_errors is Array) or (load_errors as Array).size() != 3:
		return _failure("Entry service should preserve source errors and report duplicate plus invalid categories.")
	var duplicate_error = _find_load_error(load_errors as Array, "Duplicate tool category registered", "system")
	if not (duplicate_error is Dictionary):
		return _failure("Entry service duplicate error should be a dictionary.")
	var duplicate_dict := duplicate_error as Dictionary
	if str(duplicate_dict.get("message", "")) != "Duplicate tool category registered":
		return _failure("Entry service should report duplicate category errors with the loader-compatible message.")
	if str(duplicate_dict.get("category", "")) != "system" or str(duplicate_dict.get("path", "")) != "res://system_duplicate.gd" or str(duplicate_dict.get("source", "")) != "user":
		return _failure("Entry service duplicate category errors should preserve category, path, and source.")
	var invalid_error = _find_load_error(load_errors as Array, "Invalid MCP tool category registered", "bad category")
	if not (invalid_error is Dictionary):
		return _failure("Entry service invalid category error should be a dictionary.")
	var invalid_dict := invalid_error as Dictionary
	if str(invalid_dict.get("message", "")) != "Invalid MCP tool category registered":
		return _failure("Entry service should report invalid MCP tool category errors with the loader-compatible message.")
	if str(invalid_dict.get("category", "")) != "bad category" or str(invalid_dict.get("path", "")) != "res://invalid.gd":
		return _failure("Entry service invalid category errors should preserve category and path.")

	source_error["message"] = "mutated"
	first_system_entry["nested"]["value"] = "mutated"
	if str(((load_errors as Array)[0] as Dictionary).get("message", "")) != "Failed to load":
		return _failure("Entry service should deep-copy source load errors.")
	if str((((entries_dict.get("system", {}) as Dictionary).get("nested", {}) as Dictionary).get("value", ""))) != "first":
		return _failure("Entry service should deep-copy indexed entries.")

	var second_index: Dictionary = service.build_index({"entries": [{"category": "user", "path": "res://user.gd"}]})
	var second_entries = second_index.get("entries_by_category", {})
	if not (second_entries is Dictionary) or (second_entries as Dictionary).has("system"):
		return _failure("Entry service should not leak categories across build_index calls.")

	return {
		"name": "tool_registry_entry_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"category_count": entries_dict.size(),
			"load_error_count": (load_errors as Array).size(),
			"first_category": str((ordered_categories as Array)[0])
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_registry_entry_service_contracts",
		"success": false,
		"error": message
	}


func _find_load_error(load_errors: Array, message: String, category: String) -> Dictionary:
	for load_error in load_errors:
		if not (load_error is Dictionary):
			continue
		var load_error_dict := load_error as Dictionary
		if str(load_error_dict.get("message", "")) == message and str(load_error_dict.get("category", "")) == category:
			return load_error_dict
	return {}
