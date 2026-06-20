@tool
extends RefCounted
class_name PluginUpdateRequestPlanningService


func resolve_sync_target(settings: Dictionary, refs_context: Dictionary) -> Dictionary:
	var source := _normalize_update_source(str(settings.get("update_source", "latest_stable")))
	var target_ref := ""
	var target_kind := "branch"
	match source:
		"custom_branch":
			var branch_ref := str(settings.get("update_custom_branch", "")).strip_edges()
			target_ref = branch_ref if not branch_ref.is_empty() else "dev"
		"latest_stable":
			target_ref = str(refs_context.get("latest_stable_release", "")).strip_edges()
			target_kind = "tag"
		"latest_release":
			var selected_release_tag := str(settings.get("update_release_tag", "")).strip_edges()
			target_ref = selected_release_tag if not selected_release_tag.is_empty() else str(refs_context.get("latest_release", "")).strip_edges()
			target_kind = "tag"
		_:
			target_ref = str(refs_context.get("latest_stable_release", "")).strip_edges()
			target_kind = "tag"
	return {
		"kind": target_kind,
		"ref": target_ref,
		"commit": resolve_ref_commit(target_ref, refs_context.get("commits", {}))
	}


func resolve_ref_commit(target_ref: String, commits_value) -> String:
	if not (commits_value is Dictionary):
		return ""
	var commits: Dictionary = commits_value
	return str(commits.get(target_ref, "")).strip_edges()


func should_resolve_branch_commit_before_archive(target: Dictionary) -> bool:
	if str(target.get("kind", "branch")) != "branch":
		return false
	return str(target.get("ref", "")).strip_edges() != "" and str(target.get("commit", "")).strip_edges() == ""


func get_branch_ref_url(target_ref: String, template: String) -> String:
	return template % target_ref.strip_edges().uri_encode()


func parse_branch_ref_response(body: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		return {"success": false, "error": json.get_error_message()}
	if not (json.data is Dictionary):
		return {"success": false, "error": "Expected a JSON object"}
	var data: Dictionary = json.data
	var commit_value = data.get("commit", {})
	if commit_value is Dictionary:
		var sha := str((commit_value as Dictionary).get("sha", "")).strip_edges()
		if not sha.is_empty():
			return {"success": true, "commit": sha}
	return {"success": false, "error": "Branch response did not include commit.sha"}


func build_archive_request_attempts(target: Dictionary, url_prefixes: Dictionary) -> Array:
	var target_kind := str(target.get("kind", "branch"))
	var target_ref := str(target.get("ref", "")).strip_edges()
	var target_commit := str(target.get("commit", "")).strip_edges()
	var encoded_ref := encode_archive_ref_path(target_ref)
	var attempts: Array = []
	if target_kind == "branch" and not target_commit.is_empty():
		attempts.append({
			"label": "codeload commit archive",
			"url": "%s%s" % [str(url_prefixes.get("commit_codeload", "")), target_commit.uri_encode()]
		})
		attempts.append({
			"label": "github commit archive",
			"url": "%s%s.zip" % [str(url_prefixes.get("commit_github", "")), target_commit.uri_encode()]
		})
	if not encoded_ref.is_empty():
		if target_kind == "tag":
			attempts.append({
				"label": "codeload tag archive",
				"url": "%s%s" % [str(url_prefixes.get("tag_codeload", "")), encoded_ref]
			})
			attempts.append({
				"label": "github tag archive",
				"url": "%s%s.zip" % [str(url_prefixes.get("tag_github", "")), encoded_ref]
			})
		elif target_commit.is_empty():
			attempts.append({
				"label": "codeload branch archive",
				"url": "%s%s" % [str(url_prefixes.get("branch_codeload", "")), encoded_ref]
			})
			attempts.append({
				"label": "github branch archive",
				"url": "%s%s.zip" % [str(url_prefixes.get("branch_github", "")), encoded_ref]
			})
	return attempts


func encode_archive_ref_path(target_ref: String) -> String:
	return target_ref.strip_edges().uri_encode().replace("%2F", "/")


func should_try_next_archive_attempt(error: String, attempts: Array, attempt_index: int) -> bool:
	if attempt_index < 0 or attempt_index + 1 >= attempts.size():
		return false
	return error.begins_with("Failed to open branch archive") or error.begins_with("Branch archive does not contain")


func format_archive_failures(failures: Array) -> String:
	if failures.is_empty():
		return "Update archive request failed before a download could start."
	var details: Array[String] = []
	for failure in failures:
		details.append(str(failure))
	return "Update archive request failed after %s attempt(s): %s" % [details.size(), "; ".join(details)]


func build_sync_marker(target: Dictionary, written: int, marker_context: Dictionary) -> Dictionary:
	return {
		"last_sync_at_unix": int(marker_context.get("unix_time", 0)),
		"source_repo_path": str(marker_context.get("source_repo_path", "")),
		"target_addon_path": str(marker_context.get("target_addon_path", "")),
		"source_git_commit": str(target.get("commit", "")),
		"source_ref_kind": str(target.get("kind", "")),
		"source_ref": str(target.get("ref", "")),
		"written_files": written
	}


func _normalize_update_source(source: String) -> String:
	if source == "latest_stable" or source == "latest_release" or source == "custom_branch":
		return source
	if source == "latest_dev" or source == "branch":
		return "custom_branch"
	if source == "release_tag":
		return "latest_release"
	return "latest_stable"
