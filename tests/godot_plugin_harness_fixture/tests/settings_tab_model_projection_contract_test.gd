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
		"settings_update_compare_summary": "Current plugin %s [%s] -> selected target %s [%s], commit difference: %s.",
		"settings_update_compare_difference": "current ahead %d / target ahead %d",
		"settings_update_compare_loading": "checking...",
		"settings_update_compare_deferred": "verified on update",
		"settings_update_sync_loading": "Syncing",
		"settings_update_sync_refreshing_editor": "Refreshing editor",
		"settings_update_sync_success": "Synced",
		"settings_update_sync_error": "Sync failed"
	}

	func get_text(key: String) -> String:
		return str(TEXTS.get(key, key))

	func get_available_language_codes() -> Array:
		return ["zh_CN", "en"]

	func get_language_display_name(language_code: String, _current_language: String) -> String:
		return "Chinese" if language_code == "zh_CN" else "English"


class LegacyUpdateLocalization extends FakeLocalization:
	func get_text(key: String) -> String:
		match key:
			"settings_update_branch_unavailable":
				return "Select branch mode to load branches"
			"settings_update_release_unavailable":
				return "Select release/tag mode to load releases / tags"
			_:
				return super.get_text(key)


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
		"update_compare_target_ref": "feature/settings",
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
	if JSON.stringify(_option_values(update_branches)) != JSON.stringify(["dev", "feature/settings", "main"]) or _selected_option_value(update_branches) != "feature/settings":
		return _failure("Settings projection should keep dev first while preserving the current branch.")
	var update_releases: Array = options.get("update_releases", [])
	if update_releases.size() != 2 or not bool((update_releases[0] as Dictionary).get("selected", false)):
		return _failure("Settings projection should offer discovered release/tag selector options and preserve the current tag.")
	var updates: Dictionary = projected.get("updates", {})
	if updates.has("description_text") or str(updates.get("refresh_text", "")) != "Refresh List":
		return _failure("Settings projection should omit the redundant update description while keeping the explicit refresh action copy.")
	if updates.has("version_text") or updates.has("source_text") or updates.has("commit_text"):
		return _failure("Settings projection should not expose removed current version, plugin path, or commit summary rows.")
	if bool(updates.get("prepare_enabled", true)) or not bool(updates.get("apply_enabled", false)):
		return _failure("Settings update Sync should be enabled while Prepare remains disabled.")
	if bool(updates.get("details_attention", true)):
		return _failure("Settings projection should keep update details collapsed when rate-limit state is absent.")
	if str(updates.get("source", "")) != "custom_branch" or not bool(updates.get("show_branch_row", false)):
		return _failure("Settings projection should expose only the branch target row for custom branch sources.")
	var status_text := str(updates.get("status_text", ""))
	var details_text := str(updates.get("details_text", ""))
	if not status_text.contains("Synced feature/settings.") or status_text.contains("Current plugin") or not details_text.is_empty():
		return _failure("Settings projection should keep sync success in the primary status without duplicating it in details.")
	var selected_row_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "custom_branch", "update_custom_branch": "feature/settings"},
		"update_refs_state": "success",
		"update_refs_commits": {"feature/settings": "new-sha"},
		"update_refs_branch_commit_rows": {"feature/settings": [
			{"kind": "branch", "ref": "feature/settings", "commit": "new-sha", "title": "Newest", "date": ""},
			{"kind": "branch", "ref": "feature/settings", "commit": "old-sha", "title": "Older", "date": ""}
		]},
		"update_selected_target_kind": "branch",
		"update_selected_target_ref": "feature/settings",
		"update_selected_target_commit": "old-sha",
		"update_compare_state": "unverified",
		"update_compare_target_ref": "feature/settings",
		"update_compare_target_commit": "old-sha",
		"plugin_version": "2.0.0",
		"plugin_freshness": {"sync": {"source_git_commit": "new-sha"}}
	})
	var selected_rows: Array = (selected_row_projection.get("updates", {}) as Dictionary).get("version_rows", [])
	if selected_rows.size() != 2 or bool((selected_rows[0] as Dictionary).get("selected", false)) or not bool((selected_rows[1] as Dictionary).get("selected", false)) or not str((selected_row_projection.get("updates", {}) as Dictionary).get("status_text", "")).contains("old-sha"):
		return _failure("Settings projection should select exactly the clicked commit row and use it as the comparison target.")
	var rate_limited_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {},
		"update_refs_rate_limit_remaining": "0",
		"plugin_freshness": {}
	})
	if bool((rate_limited_projection.get("updates", {}) as Dictionary).get("details_attention", true)):
		return _failure("Settings projection should not expand an empty details region when rate-limit audit text already carries the available evidence.")
	var refs_error_without_message: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {},
		"update_refs_state": "error",
		"update_refs_error": "",
		"plugin_freshness": {}
	})
	if str((refs_error_without_message.get("updates", {}) as Dictionary).get("status_text", "")) != "Refs failed" or not str((refs_error_without_message.get("updates", {}) as Dictionary).get("details_text", "")).is_empty():
		return _failure("Settings projection should show a single fallback refs error without duplicating it in details.")
	var sync_error_without_message: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {},
		"update_refs_state": "success",
		"update_sync_state": "error",
		"update_sync_error": "",
		"plugin_freshness": {}
	})
	if str((sync_error_without_message.get("updates", {}) as Dictionary).get("status_text", "")) != "Sync failed" or not str((sync_error_without_message.get("updates", {}) as Dictionary).get("details_text", "")).is_empty():
		return _failure("Settings projection should show a single fallback sync error without duplicating it in details.")
	var sync_error_matching_summary: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {},
		"update_refs_state": "success",
		"update_sync_state": "error",
		"update_sync_error": "Sync failed",
		"plugin_freshness": {}
	})
	var matching_sync_updates: Dictionary = sync_error_matching_summary.get("updates", {})
	if str(matching_sync_updates.get("status_text", "")) != "Sync failed" or not str(matching_sync_updates.get("details_text", "")).is_empty() or bool(matching_sync_updates.get("details_attention", true)):
		return _failure("Settings projection should remove a producer error when it is identical to the primary status summary.")
	var foreground_compare_error: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {},
		"update_refs_state": "success",
		"update_compare_state": "error",
		"update_compare_error": "Foreground compare failed before target verification.",
		"plugin_freshness": {}
	})
	var foreground_compare_error_updates: Dictionary = foreground_compare_error.get("updates", {})
	if not bool(foreground_compare_error_updates.get("details_attention", false)) or str(foreground_compare_error_updates.get("details_text", "")) != "Foreground compare failed before target verification.":
		return _failure("Settings projection should automatically expose the actual foreground compare failure in update details.")
	var foreground_compare_error_without_message: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {},
		"update_refs_state": "success",
		"update_compare_state": "error",
		"update_compare_error": "",
		"plugin_freshness": {}
	})
	var foreground_compare_fallback_updates: Dictionary = foreground_compare_error_without_message.get("updates", {})
	if bool(foreground_compare_fallback_updates.get("details_attention", true)) or not str(foreground_compare_fallback_updates.get("details_text", "")).is_empty() or not str(foreground_compare_fallback_updates.get("status_text", "")).contains("use Switch"):
		return _failure("Settings projection should show one actionable fallback compare error without duplicating it in details.")
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
	var missing_commit_details := str((missing_commit_projection.get("updates", {}) as Dictionary).get("details_text", ""))
	if not missing_commit_status.contains("Current plugin Unavailable [unrecorded]") or not missing_commit_status.contains("selected target Unavailable [Unavailable]") or missing_commit_status.contains("selected target dev") or not missing_commit_details.is_empty():
		return _failure("Settings projection should keep missing-hash comparison in the primary status without duplicating it in details.")

	var latest_release_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "latest_release"},
		"update_refs_state": "success",
		"update_refs_latest_release": "v1.1.0-beta",
		"update_refs_versions": {"v1.1.0-beta": "v1.1.0-beta"},
		"update_compare_state": "success",
		"update_compare_target_ref": "v1.1.0-beta",
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
	if bool((tag_only_latest_projection.get("updates", {}) as Dictionary).get("apply_enabled", true)) or str((tag_only_latest_projection.get("updates", {}) as Dictionary).get("details_text", "")).contains("Selected target: 01"):
		return _failure("Settings projection should not treat tag-only refs such as 01 as the latest GitHub release.")
	var explicit_tag_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "release_tag", "update_release_tag": "01"},
		"update_refs_releases": ["01"],
		"update_refs_latest_release": "v1.1.0-beta.1",
		"plugin_freshness": {}
	})
	if str((explicit_tag_projection.get("updates", {}) as Dictionary).get("source", "")) != "latest_release" or str((explicit_tag_projection.get("updates", {}) as Dictionary).get("details_text", "")).contains("Selected target: 01"):
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
		"update_refs_state": "success",
		"update_refs_latest_stable_release": "v1.0.0",
		"update_refs_versions": {"v1.0.0": "v1.0.0"},
		"update_compare_state": "success",
		"update_compare_target_ref": "v1.0.0",
		"plugin_freshness": {}
	})
	if not bool((latest_stable_projection.get("updates", {}) as Dictionary).get("apply_enabled", false)) or not str((latest_stable_projection.get("updates", {}) as Dictionary).get("status_text", "")).contains("v1.0.0"):
		return _failure("Settings projection should resolve latest stable release targets from discovered release state.")
	var stale_selection_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "custom_branch", "update_custom_branch": "feature/new"},
		"update_refs_state": "success",
		"update_refs_commits": {"feature/old": "old-sha", "feature/new": "new-sha"},
		"update_compare_state": "success",
		"update_compare_target_ref": "feature/old",
		"update_selection_refresh_pending": true,
		"plugin_freshness": {}
	})
	if not bool((stale_selection_projection.get("updates", {}) as Dictionary).get("apply_enabled", false)):
		return _failure("Settings projection should keep update Sync enabled while the newly selected target is still refreshing so the sync request can wait for verification.")

	var background_compare_refresh_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "custom_branch", "update_custom_branch": "feature/settings"},
		"update_refs_state": "success",
		"update_refs_refresh_state": "loading",
		"update_refs_commits": {"feature/settings": "1234567890abcdef"},
		"update_compare_state": "success",
		"update_compare_refresh_state": "loading",
		"update_compare_target_ref": "feature/settings",
		"update_compare_target_commit": "1234567890abcdef",
		"plugin_freshness": {}
	})
	if not bool((background_compare_refresh_projection.get("updates", {}) as Dictionary).get("apply_enabled", false)):
		return _failure("Settings projection should keep update Sync enabled while background refs or compare refreshes are loading.")
	var cached_refs_error_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "custom_branch", "update_custom_branch": "feature/settings"},
		"update_refs_state": "success",
		"update_refs_refresh_state": "error",
		"update_refs_refresh_error": "Background refs refresh failed; cached versions remain available.",
		"update_refs_commits": {"feature/settings": "1234567890abcdef"},
		"update_refs_branch_commit_rows": {"feature/settings": [{"kind": "branch", "ref": "feature/settings", "commit": "1234567890abcdef", "title": "Cached settings update", "date": "2026-07-12T12:00:00Z"}]},
		"update_compare_state": "success",
		"update_compare_target_ref": "feature/settings",
		"update_compare_target_commit": "1234567890abcdef",
		"plugin_freshness": {}
	})
	var cached_refs_error_updates: Dictionary = cached_refs_error_projection.get("updates", {})
	if not bool(cached_refs_error_updates.get("apply_enabled", false)) or (cached_refs_error_updates.get("version_rows", []) as Array).is_empty() or not bool(cached_refs_error_updates.get("details_attention", false)) or not str(cached_refs_error_updates.get("details_text", "")).contains("Background refs refresh failed") or not str(cached_refs_error_updates.get("status_text", "")).contains("Current plugin"):
		return _failure("Settings projection should preserve cached refs and actions while surfacing a background refs refresh failure in expanded details.")
	var cached_compare_error_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "custom_branch", "update_custom_branch": "feature/settings"},
		"update_refs_state": "success",
		"update_refs_commits": {"feature/settings": "1234567890abcdef"},
		"update_compare_state": "success",
		"update_compare_refresh_state": "error",
		"update_compare_refresh_error": "Background compare refresh timed out; cached comparison remains available.",
		"update_compare_target_ref": "feature/settings",
		"update_compare_target_commit": "1234567890abcdef",
		"update_compare_ahead_by": 2,
		"update_compare_behind_by": 0,
		"plugin_freshness": {}
	})
	var cached_compare_error_updates: Dictionary = cached_compare_error_projection.get("updates", {})
	if not bool(cached_compare_error_updates.get("apply_enabled", false)) or not bool(cached_compare_error_updates.get("details_attention", false)) or not str(cached_compare_error_updates.get("details_text", "")).contains("Background compare refresh timed out") or not str(cached_compare_error_updates.get("status_text", "")).contains("current ahead 0 / target ahead 2"):
		return _failure("Settings projection should surface a background compare refresh failure without discarding the cached comparison or update action.")
	var unavailable_compare_refresh_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "custom_branch", "update_custom_branch": "feature/settings"},
		"update_refs_state": "success",
		"update_refs_commits": {"feature/settings": "1234567890abcdef"},
		"update_compare_state": "success",
		"update_compare_refresh_state": "unavailable",
		"update_compare_refresh_error": "",
		"update_compare_target_ref": "feature/settings",
		"update_compare_target_commit": "1234567890abcdef",
		"plugin_freshness": {}
	})
	var unavailable_compare_refresh_updates: Dictionary = unavailable_compare_refresh_projection.get("updates", {})
	if not bool(unavailable_compare_refresh_updates.get("details_attention", false)) or not str(unavailable_compare_refresh_updates.get("details_text", "")).contains("use Switch"):
		return _failure("Settings projection should provide actionable details when a background compare refresh is unavailable without a producer error message.")

	var refresh_loading_projection: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "custom_branch", "update_custom_branch": "dev"},
		"update_refs_state": "success",
		"update_sync_state": "loading",
		"update_sync_status": "Refreshing editor file system before reload.",
		"plugin_freshness": {}
	})
	var refresh_loading_updates: Dictionary = refresh_loading_projection.get("updates", {})
	if bool(refresh_loading_updates.get("apply_enabled", true)) or bool(refresh_loading_updates.get("check_enabled", true)) or not str(refresh_loading_updates.get("status_text", "")).contains("Refreshing editor file system before reload."):
		return _failure("Settings projection should keep update sync controls disabled and show the editor refresh status while sync remains loading.")

	var fallback: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {},
		"current_log_level": "trace",
		"current_language": "zh_CN",
		"log_levels": ["debug", "info"],
		"languages": {"en": true, "zh_CN": true},
		"plugin_freshness": {}
	})
	if (fallback.get("updates", {}) as Dictionary).has("version_text"):
		return _failure("Settings projection should not expose a current version summary row when version data is missing.")
	var latest_stable: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "latest_stable"},
		"update_refs_state": "success",
		"update_refs_latest_stable_release": "v2.0.0",
		"update_refs_latest_release": "v2.1.0-beta.1",
		"update_refs_versions": {"v2.0.0": "v2.0.0", "v2.1.0-beta.1": "v2.1.0-beta.1"},
		"update_compare_state": "success",
		"update_compare_target_ref": "v2.0.0"
	})
	if not bool((latest_stable.get("updates", {}) as Dictionary).get("apply_enabled", false)) or not str((latest_stable.get("updates", {}) as Dictionary).get("status_text", "")).contains("v2.0.0"):
		return _failure("Settings projection should sync the latest stable release when discovered.")
	var latest_release: Dictionary = service.project({
		"localization": FakeLocalization.new(),
		"settings": {"update_source": "latest_release"},
		"update_refs_state": "success",
		"update_refs_latest_stable_release": "v2.0.0",
		"update_refs_latest_release": "v2.1.0-beta.1",
		"update_refs_versions": {"v2.0.0": "v2.0.0", "v2.1.0-beta.1": "v2.1.0-beta.1"},
		"update_compare_state": "success",
		"update_compare_target_ref": "v2.1.0-beta.1"
	})
	if not bool((latest_release.get("updates", {}) as Dictionary).get("apply_enabled", false)) or not str((latest_release.get("updates", {}) as Dictionary).get("status_text", "")).contains("v2.1.0-beta.1"):
		return _failure("Settings projection should sync the latest release, including prereleases, when discovered.")
	var fallback_branches: Array = (fallback.get("options", {}) as Dictionary).get("update_branches", [])
	if fallback_branches.is_empty() or str((fallback_branches[0] as Dictionary).get("value", "")) != "dev":
		return _failure("Settings projection should keep dev as a fallback branch option before network discovery succeeds.")
	var legacy_unavailable_projection: Dictionary = service.project({
		"localization": LegacyUpdateLocalization.new(),
		"settings": {"update_source": "latest_stable", "update_custom_branch": "dev"},
		"plugin_freshness": {}
	})
	var legacy_status_text := str((legacy_unavailable_projection.get("updates", {}) as Dictionary).get("status_text", ""))
	if not legacy_status_text.is_empty():
		return _failure("Settings projection should avoid redundant idle guidance when the Refresh List button is already visible.")

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
