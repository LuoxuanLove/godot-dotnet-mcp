@tool
extends RefCounted
class_name SettingsStore

const PluginRuntimeState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")
const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")
const TreeCollapseState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tree_collapse_state.gd")
const FileWriteTransaction = preload("res://addons/godot_dotnet_mcp/plugin/config/file_write_transaction.gd")
const TOOL_CONFIG_EXCHANGE_ROOT := "user://godot_dotnet_mcp/config_exchange"
const UPDATE_COMPARE_CACHE_LIMIT := 32


func load_plugin_settings(default_settings: Dictionary, settings_path: String, all_categories: Array, default_domains: Array) -> Dictionary:
	var settings = default_settings.duplicate(true)
	var has_settings_file = FileAccess.file_exists(settings_path)

	if has_settings_file:
		var file = FileAccess.open(settings_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data = json.get_data()
				if data is Dictionary:
					settings.merge(data, true)
			file.close()
	else:
		settings["collapsed_nodes"] = {
			TreeCollapseState.KIND_DOMAIN: default_domains.duplicate(),
			TreeCollapseState.KIND_CATEGORY: all_categories.duplicate(),
			TreeCollapseState.KIND_TOOL: PluginRuntimeState.DEFAULT_COLLAPSED_SYSTEM_TOOLS.duplicate(),
			TreeCollapseState.KIND_ATOMIC: SystemTreeCatalog.get_default_collapsed_atomic_tools()
		}

	if str(settings.get("tool_profile_id", "")).is_empty():
		settings["tool_profile_id"] = "default"
	settings["update_source"] = _normalize_update_source(str(settings.get("update_source", "latest_stable")))

	TreeCollapseState.normalize_settings(
		settings,
		all_categories,
		default_domains,
		PluginRuntimeState.DEFAULT_COLLAPSED_SYSTEM_TOOLS
	)

	return {
		"settings": settings,
		"has_settings_file": has_settings_file
	}


func _normalize_update_source(source: String) -> String:
	match source.strip_edges():
		"latest_dev", "branch":
			return "custom_branch"
		"release_tag":
			return "latest_release"
		"custom_branch", "latest_stable", "latest_release":
			return source.strip_edges()
		_:
			return "latest_stable"


func save_plugin_settings(settings_path: String, settings: Dictionary) -> void:
	var write_result := _write_json_file_atomically(settings_path, settings)
	if not bool(write_result.get("success", false)):
		push_warning("[MCP] Failed to persist plugin settings: %s" % str(write_result))


func load_update_refs_cache(cache_path: String) -> Dictionary:
	if not FileAccess.file_exists(cache_path):
		return {}
	var file := FileAccess.open(cache_path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var text := file.get_as_text()
	file.close()
	if json.parse(text) != OK:
		return {}
	var data = json.get_data()
	if not (data is Dictionary):
		return {}
	return normalize_update_refs_cache(data as Dictionary)


func save_update_refs_cache(cache_path: String, cache: Dictionary) -> void:
	var normalized := normalize_update_refs_cache(cache)
	if normalized.is_empty():
		_remove_file_if_exists(cache_path)
		return
	var write_result := _write_json_file_atomically(cache_path, normalized)
	if not bool(write_result.get("success", false)):
		push_warning("[MCP] Failed to persist update refs cache: %s" % str(write_result))


func normalize_update_refs_cache(cache: Dictionary) -> Dictionary:
	var branches := _normalize_string_array(cache.get("branches", []))
	var releases := _normalize_string_array(cache.get("releases", []))
	var commits := _normalize_string_dictionary(cache.get("commits", {}))
	var versions := _normalize_string_dictionary(cache.get("versions", {}))
	var release_rows := _normalize_update_ref_rows(cache.get("release_rows", []))
	var branch_commit_rows := _normalize_update_branch_commit_rows(cache.get("branch_commit_rows", {}))
	var compare_cache := _normalize_update_compare_cache(cache.get("compare_cache", {}))
	if branches.is_empty() and releases.is_empty() and commits.is_empty() and release_rows.is_empty() and branch_commit_rows.is_empty():
		return {}
	return {
		"format_version": 2,
		"saved_unix": int(cache.get("saved_unix", 0)),
		"last_checked_unix": int(cache.get("last_checked_unix", 0)),
		"last_trigger": str(cache.get("last_trigger", "")).strip_edges(),
		"last_http_status": int(cache.get("last_http_status", 0)),
		"branches": branches,
		"releases": releases,
		"latest_stable_release": str(cache.get("latest_stable_release", "")).strip_edges(),
		"latest_release": str(cache.get("latest_release", "")).strip_edges(),
		"release_source": str(cache.get("release_source", "")).strip_edges(),
		"commits": commits,
		"versions": versions,
		"release_rows": release_rows,
		"branch_commit_rows": branch_commit_rows,
		"compare_cache": compare_cache
	}


func load_custom_profiles(profile_dir: String) -> Dictionary:
	var profiles: Dictionary = {}
	var dir = DirAccess.open(profile_dir)
	if dir == null:
		return profiles

	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".json"):
			continue

		var slug = file_name.get_basename()
		var file_path = _build_profile_file_path(profile_dir, slug)
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			continue

		var json = JSON.new()
		var text = file.get_as_text()
		file.close()
		if json.parse(text) != OK:
			continue

		var data = json.get_data()
		if not (data is Dictionary):
			continue

		var profile_id = "custom:%s" % slug
		var disabled_tools = data.get("disabled_tools", [])
		if not (disabled_tools is Array):
			disabled_tools = []
		profiles[profile_id] = {
			"id": profile_id,
			"name": str(data.get("name", slug)),
			"file_path": file_path,
			"disabled_tools": disabled_tools
		}
	dir.list_dir_end()
	return profiles


func save_custom_profile(profile_dir: String, profile_name: String, disabled_tools: Array) -> Dictionary:
	var slug = _slugify_profile_name(profile_name)
	var file_path = _build_profile_file_path(profile_dir, slug)
	var write_result := _write_json_file_atomically(file_path, {
		"name": profile_name,
		"disabled_tools": disabled_tools
	})
	if not bool(write_result.get("success", false)):
		return {"success": false, "error_code": "profile_write_failed", "file_path": file_path}

	return {
		"success": true,
		"slug": slug,
		"file_path": file_path
	}


func delete_custom_profile(profile_dir: String, profile_id: String) -> Dictionary:
	var slug = _custom_profile_slug_from_id(profile_id)
	if slug.is_empty():
		return {"success": false, "error_code": "invalid_profile_id"}

	var file_path = _build_profile_file_path(profile_dir, slug)
	if not FileAccess.file_exists(file_path):
		return {"success": false, "error_code": "profile_not_found", "profile_id": profile_id}

	var error = DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	if error != OK:
		return {"success": false, "error_code": "delete_failed", "profile_id": profile_id, "file_path": file_path}

	return {"success": true, "profile_id": profile_id, "file_path": file_path}


func rename_custom_profile(profile_dir: String, profile_id: String, profile_name: String) -> Dictionary:
	var slug = _custom_profile_slug_from_id(profile_id)
	if slug.is_empty():
		return {"success": false, "error_code": "invalid_profile_id"}

	var trimmed_name = profile_name.strip_edges()
	if trimmed_name.is_empty():
		return {"success": false, "error_code": "empty_profile_name", "profile_id": profile_id}

	var old_file_path = _build_profile_file_path(profile_dir, slug)
	var read_result = _read_custom_profile_file(old_file_path)
	if not bool(read_result.get("success", false)):
		return {
			"success": false,
			"error_code": str(read_result.get("error_code", "profile_not_found")),
			"profile_id": profile_id,
			"file_path": old_file_path
		}

	var new_slug = _slugify_profile_name(trimmed_name)
	var new_profile_id = "custom:%s" % new_slug
	var new_file_path = _build_profile_file_path(profile_dir, new_slug)
	if new_slug != slug and FileAccess.file_exists(new_file_path):
		return {
			"success": false,
			"error_code": "profile_name_conflict",
			"profile_id": profile_id,
			"new_profile_id": new_profile_id,
			"file_path": new_file_path
		}

	var disabled_tools = read_result.get("data", {}).get("disabled_tools", [])
	if not (disabled_tools is Array):
		disabled_tools = []

	var save_result = save_custom_profile(profile_dir, trimmed_name, disabled_tools)
	if not bool(save_result.get("success", false)):
		return {"success": false, "error_code": "save_failed", "profile_id": profile_id}

	if new_slug != slug:
		var delete_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(old_file_path))
		if delete_error != OK:
			return {
				"success": false,
				"error_code": "delete_failed",
				"profile_id": profile_id,
				"file_path": old_file_path
			}

	return {
		"success": true,
		"old_profile_id": profile_id,
		"profile_id": new_profile_id,
		"profile_name": trimmed_name,
		"file_path": new_file_path,
		"slug": new_slug
	}


func export_tool_config(file_path: String, profile_id: String, disabled_tools: Array) -> Dictionary:
	var normalized_path = _normalize_tool_config_exchange_path(file_path)
	if normalized_path.is_empty():
		return {"success": false, "error_code": "config_path_required"}

	var write_result := _write_json_file_atomically(normalized_path, {
		"format_version": 1,
		"profile_id": profile_id,
		"disabled_tools": disabled_tools.duplicate()
	})
	if not bool(write_result.get("success", false)):
		return {"success": false, "error_code": "config_write_failed", "file_path": normalized_path}

	return {"success": true, "file_path": normalized_path}


func import_tool_config(file_path: String) -> Dictionary:
	var normalized_path = _normalize_tool_config_exchange_path(file_path)
	if normalized_path.is_empty():
		return {"success": false, "error_code": "config_path_required"}
	if not FileAccess.file_exists(normalized_path):
		return {"success": false, "error_code": "config_not_found", "file_path": normalized_path}

	var file = FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error_code": "config_open_failed", "file_path": normalized_path}

	var json = JSON.new()
	var text = file.get_as_text()
	file.close()
	if json.parse(text) != OK:
		return {"success": false, "error_code": "config_parse_failed", "file_path": normalized_path}

	var data = json.get_data()
	if not (data is Dictionary):
		return {"success": false, "error_code": "config_parse_failed", "file_path": normalized_path}

	var profile_id = str(data.get("profile_id", "")).strip_edges()
	if profile_id.is_empty():
		return {"success": false, "error_code": "config_profile_required", "file_path": normalized_path}

	var disabled_tools = data.get("disabled_tools", null)
	if not (disabled_tools is Array):
		return {"success": false, "error_code": "config_disabled_tools_invalid", "file_path": normalized_path}

	var normalized_disabled_tools: Array[String] = []
	for tool_name in disabled_tools:
		if not (tool_name is String):
			return {"success": false, "error_code": "config_disabled_tools_invalid", "file_path": normalized_path}
		var normalized_name = str(tool_name).strip_edges()
		if normalized_name.is_empty():
			return {"success": false, "error_code": "config_disabled_tools_invalid", "file_path": normalized_path}
		normalized_disabled_tools.append(normalized_name)

	return {
		"success": true,
		"file_path": normalized_path,
		"data": {
			"format_version": int(data.get("format_version", 1)),
			"profile_id": profile_id,
			"disabled_tools": normalized_disabled_tools
		}
	}


func _slugify_profile_name(profile_name: String) -> String:
	var lowered = profile_name.strip_edges().to_lower()
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_-]+")
	var sanitized = regex.sub(lowered, "_", true).strip_edges()
	sanitized = sanitized.trim_prefix("_").trim_suffix("_")
	return sanitized if not sanitized.is_empty() else "custom_profile"


func _build_profile_file_path(profile_dir: String, profile_slug: String) -> String:
	return "%s/%s.json" % [profile_dir, profile_slug]


func _custom_profile_slug_from_id(profile_id: String) -> String:
	if not profile_id.begins_with("custom:"):
		return ""
	return profile_id.trim_prefix("custom:")


func _normalize_tool_config_exchange_path(file_path: String) -> String:
	var normalized = file_path.strip_edges().replace("\\", "/")
	if normalized.is_empty():
		return ""
	if not normalized.begins_with("user://"):
		normalized = "%s/%s" % [TOOL_CONFIG_EXCHANGE_ROOT, normalized.trim_prefix("/")]
	if not normalized.ends_with(".json"):
		normalized += ".json"

	var global_root = ProjectSettings.globalize_path(TOOL_CONFIG_EXCHANGE_ROOT).replace("\\", "/")
	var global_path = ProjectSettings.globalize_path(normalized).replace("\\", "/")
	if not global_path.begins_with(global_root + "/"):
		return ""

	var localized = ProjectSettings.localize_path(global_path).replace("\\", "/")
	if not localized.begins_with(TOOL_CONFIG_EXCHANGE_ROOT + "/"):
		return ""
	return localized


func _read_custom_profile_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"success": false, "error_code": "profile_not_found"}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error_code": "profile_open_failed"}

	var json = JSON.new()
	var text = file.get_as_text()
	file.close()
	if json.parse(text) != OK:
		return {"success": false, "error_code": "profile_parse_failed"}

	var data = json.get_data()
	if not (data is Dictionary):
		return {"success": false, "error_code": "profile_parse_failed"}

	return {"success": true, "data": data}


func _write_json_file_atomically(file_path: String, payload: Dictionary) -> Dictionary:
	var text := JSON.stringify(payload, "\t")
	return FileWriteTransaction.write_text_atomically(file_path, text)


func _remove_file_if_exists(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		return
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	if error != OK:
		push_warning("[MCP] Failed to remove stale update refs cache: %s" % error)


func _normalize_string_array(raw_values) -> Array[String]:
	var values: Array[String] = []
	if not (raw_values is Array):
		return values
	for raw_value in raw_values:
		var value := str(raw_value).strip_edges()
		if value.is_empty() or values.has(value):
			continue
		values.append(value)
	return values


func _normalize_string_dictionary(raw_value) -> Dictionary:
	var result := {}
	if not (raw_value is Dictionary):
		return result
	for raw_key in (raw_value as Dictionary).keys():
		var key := str(raw_key).strip_edges()
		var value := str((raw_value as Dictionary).get(raw_key, "")).strip_edges()
		if key.is_empty() or value.is_empty():
			continue
		result[key] = value
	return result


func _normalize_update_ref_rows(raw_rows) -> Array:
	var rows: Array = []
	if not (raw_rows is Array):
		return rows
	for raw_row in raw_rows as Array:
		if not (raw_row is Dictionary):
			continue
		var row := raw_row as Dictionary
		var target_ref := str(row.get("ref", "")).strip_edges()
		if target_ref.is_empty():
			continue
		rows.append({
			"kind": str(row.get("kind", "tag")).strip_edges(),
			"ref": target_ref,
			"commit": str(row.get("commit", "")).strip_edges(),
			"title": str(row.get("title", target_ref)).strip_edges(),
			"date": str(row.get("date", "")).strip_edges(),
			"stable": bool(row.get("stable", false))
		})
	return rows


func _normalize_update_branch_commit_rows(raw_rows) -> Dictionary:
	var rows := {}
	if not (raw_rows is Dictionary):
		return rows
	for raw_key in (raw_rows as Dictionary).keys():
		var branch := str(raw_key).strip_edges()
		if branch.is_empty():
			continue
		var branch_rows := _normalize_update_ref_rows((raw_rows as Dictionary).get(raw_key, []))
		if not branch_rows.is_empty():
			rows[branch] = branch_rows
	return rows


func _normalize_update_compare_cache(raw_cache) -> Dictionary:
	var result := {}
	if not (raw_cache is Dictionary):
		return result
	for raw_key in (raw_cache as Dictionary).keys():
		if result.size() >= UPDATE_COMPARE_CACHE_LIMIT:
			break
		var value = (raw_cache as Dictionary).get(raw_key, {})
		if not (value is Dictionary):
			continue
		var entry := value as Dictionary
		var base_commit := str(entry.get("base_commit", "")).strip_edges()
		var target_kind := str(entry.get("target_kind", "branch")).strip_edges()
		var target_ref := str(entry.get("target_ref", "")).strip_edges()
		var target_commit := str(entry.get("target_commit", "")).strip_edges()
		var ahead_by := int(entry.get("ahead_by", -1))
		var behind_by := int(entry.get("behind_by", -1))
		if base_commit.is_empty() or target_ref.is_empty() or target_commit.is_empty() or ahead_by < 0 or behind_by < 0:
			continue
		var normalized_kind := "tag" if target_kind == "tag" else "branch"
		var normalized_key := "\n".join([base_commit, normalized_kind, target_ref, target_commit])
		result[normalized_key] = {
			"base_commit": base_commit,
			"target_kind": normalized_kind,
			"target_ref": target_ref,
			"target_commit": target_commit,
			"ahead_by": ahead_by,
			"behind_by": behind_by,
			"checked_unix": int(entry.get("checked_unix", 0))
		}
	return result
