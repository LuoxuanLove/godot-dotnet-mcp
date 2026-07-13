@tool
extends RefCounted
class_name SettingsTabModelProjectionService

const DEFAULT_PORT := 3000
const DEFAULT_LOG_LEVEL := "info"
const DEFAULT_LANGUAGE := "en"
const DEFAULT_UPDATE_SOURCE := "latest_stable"
const DEFAULT_UPDATE_BRANCH := "dev"
const UPDATE_REPO_URL := "https://github.com/LuoxuanLove/godot-dotnet-mcp"


func project(model: Dictionary) -> Dictionary:
	var localization = model.get("localization")
	var settings: Dictionary = model.get("settings", {})
	var update_settings := _project_update_settings(settings)
	var freshness: Dictionary = model.get("plugin_freshness", {})

	return {
		"settings": {
			"port": int(settings.get("port", DEFAULT_PORT))
		},
		"options": {
			"log_levels": _project_enum_options(model.get("log_levels", []), _normalize_log_level(str(model.get("current_log_level", DEFAULT_LOG_LEVEL))), localization, "log_level"),
			"languages": _project_language_options(model, localization),
			"update_sources": _project_enum_options(["latest_stable", "latest_release", "custom_branch"], str(update_settings.get("source", DEFAULT_UPDATE_SOURCE)), localization, "settings_update_source"),
			"update_branches": _project_ref_options(_build_branch_values(model, update_settings), str(update_settings.get("custom_branch", DEFAULT_UPDATE_BRANCH)), localization, "settings_update_branch_unavailable"),
			"update_releases": _project_ref_options(_build_release_values(model, update_settings), str(update_settings.get("release_tag", "")), localization, "settings_update_release_unavailable")
		},
		"updates": {
			"description_text": _get_localized_text(localization, "settings_updates_description", "The plugin refreshes the version list once at startup; after that, only Refresh List or an explicit tool refresh contacts GitHub."),
			"refresh_text": _get_localized_text(localization, "settings_update_refresh_list", "Refresh List"),
			"source": str(update_settings.get("source", DEFAULT_UPDATE_SOURCE)),
			"active_channel": _resolve_update_channel(update_settings),
			"custom_branch": str(update_settings.get("custom_branch", DEFAULT_UPDATE_BRANCH)),
			"release_tag": str(update_settings.get("release_tag", "")),
			"show_branch_row": str(update_settings.get("source", DEFAULT_UPDATE_SOURCE)) == "custom_branch",
			"remote_url": UPDATE_REPO_URL,
			"current_branch": _resolve_current_branch(model, update_settings),
			"current_version": _resolve_current_version(model, freshness, localization),
			"current_commit": _read_freshness_value(freshness, ["sync", "source_git_commit"]),
			"version_rows": _build_version_rows(model, update_settings, localization),
			"empty_text": _build_update_table_empty_text(model, update_settings, localization),
			"audit_text": _build_update_audit_text(model, localization),
			"details_text": _build_update_details_text(model, update_settings, localization),
			"details_attention": _should_highlight_update_details(model),
			"status_text": _build_update_status_text(model, update_settings, localization),
			"progress": _project_update_sync_progress(model),
			"progress_visible": str(model.get("update_sync_state", "idle")) == "loading",
			"check_enabled": _is_update_check_enabled(model),
			"prepare_enabled": false,
			"apply_enabled": _is_update_sync_enabled(model, update_settings),
			"actions_enabled": _is_update_sync_enabled(model, update_settings)
		}
	}


func _resolve_update_channel(update_settings: Dictionary) -> String:
	return "development" if str(update_settings.get("source", DEFAULT_UPDATE_SOURCE)) == "custom_branch" else "stable"


func _project_update_settings(settings: Dictionary) -> Dictionary:
	var source := _normalize_update_source(str(settings.get("update_source", DEFAULT_UPDATE_SOURCE)))
	var custom_branch := str(settings.get("update_custom_branch", DEFAULT_UPDATE_BRANCH)).strip_edges()
	if custom_branch.is_empty():
		custom_branch = DEFAULT_UPDATE_BRANCH
	return {
		"source": source,
		"custom_branch": custom_branch,
		"release_tag": str(settings.get("update_release_tag", "")).strip_edges()
	}


func _normalize_update_source(source: String) -> String:
	var normalized := source.strip_edges()
	match normalized:
		"latest_dev", "branch":
			return "custom_branch"
		"release_tag":
			return "latest_release"
		"custom_branch", "latest_stable", "latest_release":
			return normalized
		_:
			return DEFAULT_UPDATE_SOURCE

func _build_branch_values(model: Dictionary, update_settings: Dictionary) -> Array[String]:
	var values: Array[String] = []
	_append_unique_string(values, DEFAULT_UPDATE_BRANCH)
	_append_unique_string(values, str(update_settings.get("custom_branch", DEFAULT_UPDATE_BRANCH)))
	for branch in _normalize_string_array(model.get("update_refs_branches", [])):
		_append_unique_string(values, branch)
	return values


func _build_release_values(model: Dictionary, update_settings: Dictionary) -> Array[String]:
	var values: Array[String] = []
	_append_unique_string(values, str(update_settings.get("release_tag", "")))
	for release_tag in _normalize_string_array(model.get("update_refs_releases", [])):
		_append_unique_string(values, release_tag)
	if values.is_empty():
		values.append("")
	return values


func _project_ref_options(values: Array[String], current_value: String, localization, empty_key: String) -> Array:
	var options: Array = []
	for value in values:
		var text := value
		if value.is_empty():
			text = _get_localized_text(localization, empty_key, "No discovered refs yet")
		options.append({"text": text, "value": value, "selected": value == current_value})
	return options


func _resolve_current_branch(model: Dictionary, update_settings: Dictionary) -> String:
	var freshness: Dictionary = model.get("plugin_freshness", {})
	var sync_ref := _read_freshness_value(freshness, ["sync", "source_ref"])
	if not sync_ref.is_empty():
		return sync_ref
	return str(update_settings.get("custom_branch", DEFAULT_UPDATE_BRANCH))


func _build_version_rows(model: Dictionary, update_settings: Dictionary, localization) -> Array:
	if _resolve_update_channel(update_settings) == "development":
		return _build_development_rows(model, update_settings, localization)
	return _build_stable_rows(model, localization)


func _build_stable_rows(model: Dictionary, localization) -> Array:
	var current_commit := _read_freshness_value(model.get("plugin_freshness", {}), ["sync", "source_git_commit"])
	var current_ref := _read_freshness_value(model.get("plugin_freshness", {}), ["sync", "source_ref"])
	var rows: Array = []
	var source_rows = model.get("update_refs_release_rows", [])
	if source_rows is Array and not (source_rows as Array).is_empty():
		for raw_row in source_rows as Array:
			if raw_row is Dictionary:
				rows.append(_build_version_row(raw_row as Dictionary, current_ref, current_commit, localization))
		return rows
	var commits: Dictionary = model.get("update_refs_commits", {})
	for release_ref in _normalize_string_array(model.get("update_refs_releases", [])):
		rows.append(_build_version_row({
			"kind": "tag",
			"ref": release_ref,
			"commit": str(commits.get(release_ref, "")),
			"title": release_ref,
			"date": ""
		}, current_ref, current_commit, localization))
	return rows


func _build_development_rows(model: Dictionary, update_settings: Dictionary, localization) -> Array:
	var branch := str(update_settings.get("custom_branch", DEFAULT_UPDATE_BRANCH)).strip_edges()
	var current_commit := _read_freshness_value(model.get("plugin_freshness", {}), ["sync", "source_git_commit"])
	var current_ref := _read_freshness_value(model.get("plugin_freshness", {}), ["sync", "source_ref"])
	var branch_rows: Dictionary = model.get("update_refs_branch_commit_rows", {})
	var source_rows = branch_rows.get(branch, []) if branch_rows is Dictionary else []
	var rows: Array = []
	if source_rows is Array:
		for raw_row in source_rows as Array:
			if raw_row is Dictionary:
				rows.append(_build_version_row(raw_row as Dictionary, current_ref, current_commit, localization))
	if not rows.is_empty():
		return rows
	var commits: Dictionary = model.get("update_refs_commits", {})
	var branch_commit := str(commits.get(branch, "")).strip_edges()
	if not branch_commit.is_empty():
		rows.append(_build_version_row({
			"kind": "branch",
			"ref": branch,
			"commit": branch_commit,
			"title": _get_localized_text(localization, "settings_update_branch_head", "branch head"),
			"date": ""
		}, current_ref, current_commit, localization))
	return rows


func _build_version_row(raw_row: Dictionary, current_ref: String, current_commit: String, localization) -> Dictionary:
	var target_ref := str(raw_row.get("ref", "")).strip_edges()
	var target_commit := str(raw_row.get("commit", "")).strip_edges()
	var kind := str(raw_row.get("kind", "branch")).strip_edges()
	var display_id := _short_commit(target_commit, localization) if kind == "branch" and not target_commit.is_empty() else target_ref
	var is_current := (not target_commit.is_empty() and target_commit == current_commit) or (target_commit.is_empty() and not target_ref.is_empty() and target_ref == current_ref)
	return {
		"kind": kind,
		"ref": target_ref,
		"commit": target_commit,
		"id": display_id,
		"title": str(raw_row.get("title", target_ref)).strip_edges(),
		"date": _format_update_row_date(str(raw_row.get("date", "")).strip_edges()),
		"current": is_current,
		"switch_enabled": not target_ref.is_empty() and not is_current
	}


func _format_update_row_date(date_text: String) -> String:
	if date_text.is_empty():
		return ""
	return date_text.replace("T", " ").replace("Z", "")


func _build_update_table_empty_text(model: Dictionary, update_settings: Dictionary, localization) -> String:
	if str(model.get("update_refs_state", "idle")) == "loading":
		return _get_localized_text(localization, "settings_update_refs_loading", "Loading update refs.")
	if _resolve_update_channel(update_settings) == "development":
		return _get_localized_text(localization, "settings_update_branch_unavailable", "Click Refresh List to load commits for the selected branch.")
	return _get_localized_text(localization, "settings_update_release_unavailable", "Click Refresh List to load stable releases and tags.")


func _build_update_audit_text(model: Dictionary, localization) -> String:
	var trigger := str(model.get("update_refs_last_trigger", "")).strip_edges()
	var checked_unix := int(model.get("update_refs_last_checked_unix", 0))
	var status := int(model.get("update_refs_last_http_status", 0))
	var reset_unix := int(model.get("update_refs_rate_limit_reset_unix", 0))
	var parts: Array[String] = []
	if not trigger.is_empty():
		parts.append("%s %s" % [_get_localized_text(localization, "settings_update_last_trigger", "Last trigger:"), trigger])
	if checked_unix > 0:
		parts.append("%s %s" % [_get_localized_text(localization, "settings_update_last_refresh", "Last refresh:"), Time.get_datetime_string_from_unix_time(checked_unix, true)])
	if status > 0:
		parts.append("HTTP %d" % status)
	if reset_unix > 0 and str(model.get("update_refs_rate_limit_remaining", "")) == "0":
		parts.append("%s %s" % [_get_localized_text(localization, "settings_update_rate_limit_reset", "Rate limit resets:"), Time.get_datetime_string_from_unix_time(reset_unix, true)])
	return "  |  ".join(parts)


func _build_update_details_text(model: Dictionary, update_settings: Dictionary, localization) -> String:
	var refs_state := str(model.get("update_refs_state", "idle"))
	var sync_state := str(model.get("update_sync_state", "idle"))
	if refs_state == "error":
		return str(model.get("update_refs_error", "")).strip_edges()
	if sync_state == "error":
		return str(model.get("update_sync_error", "")).strip_edges()
	var details := _build_background_refresh_errors(model, localization)
	if refs_state == "idle" and sync_state == "idle":
		return "\n".join(details)
	details.append(_build_update_compare_status_text(model, update_settings, localization))
	return "\n".join(details)


func _build_background_refresh_errors(model: Dictionary, localization) -> Array[String]:
	var errors: Array[String] = []
	if str(model.get("update_refs_refresh_state", "idle")) == "error":
		var refs_error := str(model.get("update_refs_refresh_error", "")).strip_edges()
		if refs_error.is_empty():
			refs_error = _get_localized_text(localization, "settings_update_refs_error", "Update refs discovery failed.")
		errors.append(refs_error)
	if ["error", "unavailable"].has(str(model.get("update_compare_refresh_state", "idle"))):
		var compare_error := str(model.get("update_compare_refresh_error", "")).strip_edges()
		if compare_error.is_empty():
			compare_error = _get_localized_text(localization, "settings_update_compare_required", "Update target could not be verified; use Switch for an explicit manual change.")
		errors.append(compare_error)
	return errors


func _should_highlight_update_details(model: Dictionary) -> bool:
	if str(model.get("update_refs_state", "idle")) == "error" or str(model.get("update_sync_state", "idle")) == "error":
		return true
	if str(model.get("update_refs_refresh_state", "idle")) == "error" or ["error", "unavailable"].has(str(model.get("update_compare_refresh_state", "idle"))):
		return true
	var remaining := str(model.get("update_refs_rate_limit_remaining", "")).strip_edges()
	return not remaining.is_empty() and remaining == "0"


func _build_update_status_text(model: Dictionary, update_settings: Dictionary, localization) -> String:
	var sync_state := str(model.get("update_sync_state", "idle"))
	if sync_state != "idle":
		return _build_update_sync_status_text(model, update_settings, localization)
	return _build_update_refs_status_text(model, update_settings, localization)


func _project_update_sync_progress(model: Dictionary) -> float:
	var state := str(model.get("update_sync_state", "idle"))
	if state == "success":
		return 1.0
	if state != "loading":
		return 0.0
	return clampf(float(model.get("update_sync_progress", 0.0)), 0.0, 1.0)


func _build_update_refs_status_text(model: Dictionary, update_settings: Dictionary, localization) -> String:
	var state := str(model.get("update_refs_state", "idle"))
	var target := _build_selected_update_target(model, update_settings, localization)
	match state:
		"loading":
			return "%s %s" % [_get_localized_text(localization, "settings_update_refs_loading", "Loading update refs."), target]
		"success":
			return _get_localized_text(localization, "settings_update_refs_success", "Version list refreshed.")
		"error":
			var error := str(model.get("update_refs_error", "")).strip_edges()
			if error.is_empty():
				error = _get_localized_text(localization, "settings_update_refs_error", "Update refs discovery failed.")
			return "%s %s" % [error, target]
		_:
			return "%s %s" % [_get_localized_text(localization, "settings_update_refs_idle", "Click Check for Updates to refresh branches, releases, and tags."), target]


func _build_update_sync_status_text(model: Dictionary, update_settings: Dictionary, localization) -> String:
	var state := str(model.get("update_sync_state", "idle"))
	var target := _build_selected_update_target(model, update_settings, localization)
	match state:
		"loading":
			var status := str(model.get("update_sync_status", "")).strip_edges()
			if status.is_empty():
				status = _get_localized_text(localization, "settings_update_sync_loading", "Syncing selected update...")
			return "%s %s" % [status, target]
		"success":
			var status := str(model.get("update_sync_status", "")).strip_edges()
			if status.is_empty():
				status = _get_localized_text(localization, "settings_update_sync_success", "Update sync completed.")
			return status
		"error":
			var error := str(model.get("update_sync_error", "")).strip_edges()
			if error.is_empty():
				error = _get_localized_text(localization, "settings_update_sync_error", "Update sync failed.")
			return "%s %s" % [error, target]
		_:
			return _build_update_refs_status_text(model, update_settings, localization)


func _build_update_compare_status_text(model: Dictionary, update_settings: Dictionary, localization) -> String:
	var current_version := _resolve_current_version(model, model.get("plugin_freshness", {}), localization)
	var current_commit := _short_commit(_read_freshness_value(model.get("plugin_freshness", {}), ["sync", "source_git_commit"]), localization, "settings_update_commit_unrecorded", "unrecorded")
	var target_ref := _resolve_selected_update_target_value(model, update_settings)
	var target_version := _resolve_target_update_version(model, target_ref, localization)
	var target_commit := _short_commit(_resolve_target_update_commit(model, target_ref), localization)
	var compare_text := _build_compare_difference_text(model, localization)
	var template := _get_localized_text(localization, "settings_update_compare_summary", "Current plugin %s [%s] -> selected target %s [%s], commit difference: %s.")
	return template % [current_version, current_commit, target_version, target_commit, compare_text]


func _resolve_current_version(model: Dictionary, freshness: Dictionary, localization) -> String:
	var version := str(model.get("plugin_version", "")).strip_edges()
	if version.is_empty():
		version = _read_freshness_value(freshness, ["running_instance", "source_version"])
	if version.is_empty():
		version = _read_freshness_value(freshness, ["disk_source", "source_version"])
	if version.is_empty():
		version = _get_localized_text(localization, "settings_update_unavailable", "Unavailable")
	return version


func _resolve_selected_update_target_value(model: Dictionary, update_settings: Dictionary) -> String:
	var source := str(update_settings.get("source", DEFAULT_UPDATE_SOURCE))
	match source:
		"custom_branch":
			return str(update_settings.get("custom_branch", DEFAULT_UPDATE_BRANCH)).strip_edges()
		"latest_stable":
			return str(model.get("update_refs_latest_stable_release", "")).strip_edges()
		"latest_release":
			return str(model.get("update_refs_latest_release", "")).strip_edges()
		_:
			return str(model.get("update_refs_latest_stable_release", "")).strip_edges()


func _resolve_target_update_commit(model: Dictionary, target_ref: String) -> String:
	var commits: Dictionary = model.get("update_refs_commits", {})
	return str(commits.get(target_ref, model.get("update_compare_target_commit", ""))).strip_edges()


func _resolve_target_update_version(model: Dictionary, target_ref: String, localization) -> String:
	var versions: Dictionary = model.get("update_refs_versions", {})
	var version := str(versions.get(target_ref, "")).strip_edges()
	if version.is_empty():
		return _get_localized_text(localization, "settings_update_unavailable", "Unavailable")
	return version


func _short_commit(commit: String, localization, missing_key: String = "settings_update_unavailable", missing_fallback: String = "Unavailable") -> String:
	var normalized := commit.strip_edges()
	if normalized.is_empty():
		return _get_localized_text(localization, missing_key, missing_fallback)
	return normalized.substr(0, mini(7, normalized.length()))


func _build_compare_difference_text(model: Dictionary, localization) -> String:
	var state := str(model.get("update_compare_state", "idle"))
	if state == "loading":
		return _get_localized_text(localization, "settings_update_compare_loading", "checking...")
	var ahead_by := int(model.get("update_compare_ahead_by", -1))
	var behind_by := int(model.get("update_compare_behind_by", -1))
	if state == "success" and ahead_by >= 0 and behind_by >= 0:
		var template := _get_localized_text(localization, "settings_update_compare_difference", "current ahead %d / target ahead %d")
		return template % [behind_by, ahead_by]
	return _get_localized_text(localization, "settings_update_unavailable", "Unavailable")


func _is_update_check_enabled(model: Dictionary) -> bool:
	return str(model.get("update_refs_state", "idle")) != "loading" and str(model.get("update_sync_state", "idle")) != "loading"


func _is_update_sync_enabled(model: Dictionary, update_settings: Dictionary) -> bool:
	if str(model.get("update_sync_state", "idle")) == "loading":
		return false
	var source := str(update_settings.get("source", DEFAULT_UPDATE_SOURCE))
	match source:
		"custom_branch":
			var target_ref := str(update_settings.get("custom_branch", DEFAULT_UPDATE_BRANCH)).strip_edges()
			return not target_ref.is_empty()
		"latest_stable":
			var target_ref := str(model.get("update_refs_latest_stable_release", "")).strip_edges()
			return not target_ref.is_empty()
		"latest_release":
			var target_ref := str(model.get("update_refs_latest_release", "")).strip_edges()
			return not target_ref.is_empty()
		_:
			return false


func _build_selected_update_target(model: Dictionary, update_settings: Dictionary, localization) -> String:
	var source := str(update_settings.get("source", DEFAULT_UPDATE_SOURCE))
	var target := DEFAULT_UPDATE_BRANCH
	match source:
		"custom_branch":
			target = str(update_settings.get("custom_branch", DEFAULT_UPDATE_BRANCH))
		"latest_stable":
			target = str(model.get("update_refs_latest_stable_release", ""))
		"latest_release":
			target = str(model.get("update_refs_latest_release", ""))
		_:
			target = str(model.get("update_refs_latest_stable_release", ""))
	if target.strip_edges().is_empty():
		var empty_key := "settings_update_branch_unavailable" if source == "custom_branch" else "settings_update_release_unavailable"
		target = _get_localized_text(localization, empty_key, "Click Check for Updates to refresh refs.")
	return "%s %s" % [_get_localized_text(localization, "settings_update_selected_target", "Selected target:"), target]


func _normalize_string_array(raw_values) -> Array[String]:
	var values: Array[String] = []
	if not (raw_values is Array):
		return values
	for raw_value in raw_values:
		_append_unique_string(values, str(raw_value))
	return values


func _append_unique_string(values: Array[String], value: String) -> void:
	var normalized := value.strip_edges()
	if normalized.is_empty() or values.has(normalized):
		return
	values.append(normalized)


func _read_freshness_value(freshness: Dictionary, path: Array[String]) -> String:
	var current: Variant = freshness
	for key in path:
		if not (current is Dictionary):
			return ""
		current = (current as Dictionary).get(key, "")
	return str(current).strip_edges()


func _project_enum_options(values, current_value: String, localization, key_prefix: String) -> Array:
	var options: Array = []
	if not (values is Array):
		return options

	for raw_value in values:
		var value := str(raw_value)
		var key := "%s_%s" % [key_prefix, value]
		options.append({
			"text": _get_localized_text(localization, key, value.capitalize()),
			"value": value,
			"selected": value == current_value
		})
	return options


func _project_language_options(model: Dictionary, localization) -> Array:
	var current_language = str(model.get("current_language", DEFAULT_LANGUAGE))
	var language_codes: Array = []
	if localization != null and localization.has_method("get_available_language_codes"):
		language_codes = localization.get_available_language_codes()
	else:
		var languages: Dictionary = model.get("languages", {})
		language_codes = languages.keys()
		language_codes.sort()

	var options: Array = []
	for raw_code in language_codes:
		var language_code := str(raw_code)
		options.append({
			"text": _get_language_display_name(localization, language_code, current_language),
			"value": language_code,
			"selected": language_code == current_language
		})
	return options


func _get_language_display_name(localization, language_code: String, current_language: String) -> String:
	if language_code.is_empty():
		language_code = DEFAULT_LANGUAGE
	if localization != null and localization.has_method("get_language_display_name"):
		return str(localization.get_language_display_name(language_code, current_language))
	return language_code.capitalize()


func _normalize_log_level(level: String) -> String:
	var normalized := level.to_lower().strip_edges()
	if normalized == "trace":
		return "debug"
	match normalized:
		"debug", "info", "warning", "error":
			return normalized
		_:
			return DEFAULT_LOG_LEVEL


func _get_localized_text(localization, key: String, fallback: String = "") -> String:
	if localization != null and localization.has_method("get_text"):
		var translated := str(localization.get_text(key))
		if _is_stale_manual_update_check_text(key, translated):
			return fallback if not fallback.is_empty() else key
		if not translated.is_empty() and translated != key:
			return translated
	return fallback if not fallback.is_empty() else key


func _is_stale_manual_update_check_text(key: String, text: String) -> bool:
	if not ["settings_update_refs_idle", "settings_update_branch_unavailable", "settings_update_release_unavailable", "settings_update_placeholder_status"].has(key):
		return false
	return text.contains("Select an update mode") \
		or text.contains("Select branch mode") \
		or text.contains("Select release/tag mode") \
		or text.contains("load branches") \
		or text.contains("load releases") \
		or text.contains("选择更新方式") \
		or text.contains("选择分支模式") \
		or text.contains("选择发布") \
		or text.contains("選擇更新方式") \
		or text.contains("選擇分支模式") \
		or text.contains("選擇發布") \
		or text.contains("自動") \
		or text.contains("자동")
