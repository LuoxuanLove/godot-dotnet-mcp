extends RefCounted

const SettingsTabModelProjectionServiceScript = preload("res://addons/godot_dotnet_mcp/ui/settings_tab_model_projection.gd")


class FakeLocalization extends RefCounted:
	const TEXTS := {
		"log_level_debug": "Debug",
		"log_level_info": "Info",
		"log_level_warning": "Warning",
		"log_level_error": "Error",
		"settings_update_source_latest_dev": "Latest dev",
		"settings_update_source_custom_branch": "Custom branch",
		"settings_update_source_latest_stable": "Latest stable release",
		"settings_update_source_latest_release": "Latest release",
		"settings_update_source_release_tag": "Release tag",
		"settings_current_version": "Current version:",
		"settings_current_source": "Plugin Path:",
		"settings_current_commit": "Commit:",
		"settings_update_unavailable": "Unavailable",
		"settings_update_commit_unrecorded": "unrecorded",
		"settings_update_branch_unavailable": "No branches",
		"settings_update_release_unavailable": "No releases",
		"settings_update_refs_idle": "Idle refs",
		"settings_update_refs_loading": "Loading refs",
		"settings_update_refs_success": "Refs loaded",
		"settings_update_refs_error": "Refs failed",
		"settings_update_selected_target": "Selected target:",
		"settings_update_compare_summary": "Current version %s [%s], target version %s [%s], commit difference: %s.",
		"settings_update_compare_difference": "ahead %d / behind %d",
		"settings_update_compare_loading": "checking...",
		"settings_update_sync_loading": "Syncing",
		"settings_update_sync_success": "Synced",
		"settings_update_sync_error": "Sync failed"
	}

	func get_text(key: String) -> String:
		return str(TEXTS.get(key, key))

	func get_available_language_codes() -> Array:
		return ["zh_CN", "en"]

	func get_language_display_name(language_code: String, _current_language: String) -> String:
		return "Chinese" if language_code == "zh_CN" else "English"


func run_case(_tree: SceneTree) -> Dictionary:
	var service = SettingsTabModelProjectionServiceScript.new()
	var projected: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {
			"port": 4101,
			"update_source": "custom_branch",
			"update_custom_branch": "feature/settings",
			"update_release_tag": "v1.0.0"
		},
		"current_log_level": "warning",
		"current_language": "en",
		"log_levels": ["debug", "info", "warning", "error"],
		"update_refs_branches": ["dev", "feature/settings", "main"],
		"update_refs_releases": ["v1.0.0", "v0.9.0"],
		"update_refs_state": "success",
		"update_refs_status": "Discovered refs.",
		"update_refs_latest_stable_release": "v1.0.0",
		"update_refs_latest_release": "v1.1.0-beta.1",
		"update_refs_commits": {"feature/settings": "1234567890abcdef"},
		"update_refs_versions": {"feature/settings": "2.0.0"},
		"update_compare_state": "success",
		"update_compare_ahead_by": 4,
		"update_compare_behind_by": 1,
		"update_sync_state": "success",
		"update_sync_status": "Synced feature/settings.",
		"plugin_version": "1.2.3",
		"plugin_freshness": {
			"running_instance": {"source_root": "res://addons/godot_dotnet_mcp"},
			"sync": {"source_git_commit": "abcdef123456"}
		}
	})

	if int((projected.get("settings", {}) as Dictionary).get("port", 0)) != 4101:
		return _failure("Settings projection should pass through the persisted port.")
	var options: Dictionary = projected.get("options", {})
	var log_levels: Array = options.get("log_levels", [])
	if log_levels.size() != 4 or not bool((log_levels[2] as Dictionary).get("selected", false)):
		return _failure("Settings projection should mark the current log level.")
	var languages: Array = options.get("languages", [])
	if languages.size() != 2 or not bool((languages[1] as Dictionary).get("selected", false)):
		return _failure("Settings projection should mark the current language.")
	var update_sources: Array = options.get("update_sources", [])
	if JSON.stringify(_option_values(update_sources)) != JSON.stringify(["latest_stable", "latest_release", "custom_branch"]) or not bool((update_sources[2] as Dictionary).get("selected", false)):
		return _failure("Settings projection should expose latest stable, latest release, then custom branch and select custom branch mode.")
	var update_branches: Array = options.get("update_branches", [])
	if update_branches.size() != 3 or _selected_option_value(update_branches) != "feature/settings":
		return _failure("Settings projection should offer discovered branch selector options and preserve the current branch.")
	var update_releases: Array = options.get("update_releases", [])
	if update_releases.size() != 2 or not bool((update_releases[0] as Dictionary).get("selected", false)):
		return _failure("Settings projection should offer discovered release/tag selector options and preserve the current tag.")
	var updates: Dictionary = projected.get("updates", {})
	if str(updates.get("version_text", "")) != "Current version: 1.2.3":
		return _failure("Settings projection should display the current plugin version.")
	if str(updates.get("source_text", "")) != "Plugin Path: res://addons/godot_dotnet_mcp":
		return _failure("Settings projection should display the current plugin path when available.")
	if not str(updates.get("commit_text", "")).contains("abcdef123456"):
		return _failure("Settings projection should display the sync commit when available.")
	if bool(updates.get("prepare_enabled", true)) or not bool(updates.get("apply_enabled", false)):
		return _failure("Settings update Sync should be enabled while Prepare remains disabled.")
	if str(updates.get("source", "")) != "custom_branch" or not bool(updates.get("show_branch_row", false)):
		return _failure("Settings projection should expose only the branch target row for custom branch sources.")
	var status_text := str(updates.get("status_text", ""))
	if not status_text.contains("Synced feature/settings.") or status_text.contains("Discovered") or status_text.contains("Selected target:") or not status_text.contains("Current version 1.2.3 [abcdef1]") or not status_text.contains("target version 2.0.0 [1234567]") or status_text.contains("target version feature/settings") or not status_text.contains("ahead 4 / behind 1"):
		return _failure("Settings projection should keep sync success text together with current/target hashes and ahead/behind commit difference.")
	var missing_commit_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "custom_branch", "update_custom_branch": "dev"},
		"update_refs_state": "success",
		"update_refs_commits": {},
		"update_refs_versions": {},
		"update_compare_state": "unavailable",
		"plugin_freshness": {}
	})
	var missing_commit_status := str((missing_commit_projection.get("updates", {}) as Dictionary).get("status_text", ""))
	if not missing_commit_status.contains("Current version Unavailable [unrecorded]") or not missing_commit_status.contains("target version Unavailable [Unavailable]") or missing_commit_status.contains("target version dev"):
		return _failure("Settings projection should use unrecorded for missing hashes and not fall back to raw refs as target versions.")

	var latest_release_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "latest_release"},
		"update_refs_latest_release": "v1.1.0-beta",
		"plugin_freshness": {}
	})
	if not bool((latest_release_projection.get("updates", {}) as Dictionary).get("apply_enabled", false)) or not str((latest_release_projection.get("updates", {}) as Dictionary).get("status_text", "")).contains("v1.1.0-beta"):
		return _failure("Settings projection should resolve latest release targets, including prereleases, from discovered release state.")
	if bool((latest_release_projection.get("updates", {}) as Dictionary).get("show_branch_row", true)):
		return _failure("Settings projection should not expose editable target rows for automatic latest release sources.")
	var tag_only_latest_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "latest_release", "update_release_tag": "01"},
		"update_refs_releases": ["01"],
		"update_refs_latest_release": "",
		"update_refs_latest_stable_release": "",
		"plugin_freshness": {}
	})
	if bool((tag_only_latest_projection.get("updates", {}) as Dictionary).get("apply_enabled", true)) or str((tag_only_latest_projection.get("updates", {}) as Dictionary).get("status_text", "")).contains("Selected target: 01"):
		return _failure("Settings projection should not treat tag-only refs such as 01 as the latest GitHub release.")
	var explicit_tag_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "release_tag", "update_release_tag": "01"},
		"update_refs_releases": ["01"],
		"update_refs_latest_release": "v1.1.0-beta.1",
		"plugin_freshness": {}
	})
	if str((explicit_tag_projection.get("updates", {}) as Dictionary).get("source", "")) != "latest_release" or str((explicit_tag_projection.get("updates", {}) as Dictionary).get("status_text", "")).contains("Selected target: 01"):
		return _failure("Settings projection should normalize old explicit release/tag settings to latest release and ignore saved downgrade tags.")
	var removed_latest_dev_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "latest_dev", "update_custom_branch": ""},
		"update_refs_latest_stable_release": "v1.0.0",
		"plugin_freshness": {}
	})
	if str((removed_latest_dev_projection.get("updates", {}) as Dictionary).get("source", "")) != "custom_branch" or not bool((removed_latest_dev_projection.get("updates", {}) as Dictionary).get("show_branch_row", false)) or _selected_option_value((removed_latest_dev_projection.get("options", {}) as Dictionary).get("update_sources", [])) != "custom_branch" or _selected_option_value((removed_latest_dev_projection.get("options", {}) as Dictionary).get("update_branches", [])) != "dev":
		return _failure("Settings projection should preserve legacy latest_dev settings as custom_branch with dev fallback.")
	var legacy_branch_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "branch", "update_custom_branch": "feature/legacy"},
		"plugin_freshness": {}
	})
	if str((legacy_branch_projection.get("updates", {}) as Dictionary).get("source", "")) != "custom_branch" or not bool((legacy_branch_projection.get("updates", {}) as Dictionary).get("show_branch_row", false)) or _selected_option_value((legacy_branch_projection.get("options", {}) as Dictionary).get("update_sources", [])) != "custom_branch":
		return _failure("Settings projection should normalize legacy branch settings to custom_branch.")

	var latest_stable_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "latest_stable"},
		"update_refs_latest_stable_release": "v1.0.0",
		"plugin_freshness": {}
	})
	if not bool((latest_stable_projection.get("updates", {}) as Dictionary).get("apply_enabled", false)) or not str((latest_stable_projection.get("updates", {}) as Dictionary).get("status_text", "")).contains("v1.0.0"):
		return _failure("Settings projection should resolve latest stable release targets from discovered release state.")

	var fallback: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {},
		"current_log_level": "trace",
		"current_language": "zh_CN",
		"log_levels": ["debug", "info"],
		"languages": {"en": true, "zh_CN": true},
		"plugin_freshness": {}
	})
	if not str((fallback.get("updates", {}) as Dictionary).get("version_text", "")).contains("Unavailable"):
		return _failure("Settings projection should use unavailable copy when version data is missing.")
	var latest_stable: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "latest_stable"},
		"update_refs_latest_stable_release": "v2.0.0",
		"update_refs_latest_release": "v2.1.0-beta.1"
	})
	if not bool((latest_stable.get("updates", {}) as Dictionary).get("apply_enabled", false)) or not str((latest_stable.get("updates", {}) as Dictionary).get("status_text", "")).contains("v2.0.0"):
		return _failure("Settings projection should sync the latest stable release when discovered.")
	var latest_release: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "latest_release"},
		"update_refs_latest_stable_release": "v2.0.0",
		"update_refs_latest_release": "v2.1.0-beta.1"
	})
	if not bool((latest_release.get("updates", {}) as Dictionary).get("apply_enabled", false)) or not str((latest_release.get("updates", {}) as Dictionary).get("status_text", "")).contains("v2.1.0-beta.1"):
		return _failure("Settings projection should sync the latest release, including prereleases, when discovered.")
	var fallback_branches: Array = (fallback.get("options", {}) as Dictionary).get("update_branches", [])
	if fallback_branches.is_empty() or str((fallback_branches[0] as Dictionary).get("value", "")) != "dev":
		return _failure("Settings projection should keep dev as a fallback branch option before network discovery succeeds.")

	return {"name": "settings_tab_model_projection_contracts", "success": true, "error": ""}


func _failure(message: String) -> Dictionary:
	return {"name": "settings_tab_model_projection_contracts", "success": false, "error": message}


func _selected_option_value(options: Array) -> String:
	for option in options:
		if option is Dictionary and bool((option as Dictionary).get("selected", false)):
			return str((option as Dictionary).get("value", ""))
	return ""

func _option_values(options: Array) -> Array[String]:
	var values: Array[String] = []
	for option in options:
		if option is Dictionary:
			values.append(str((option as Dictionary).get("value", "")))
	return values
