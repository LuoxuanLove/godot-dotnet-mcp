@tool
extends RefCounted
class_name PluginUpdateCompareService


func build_target_version_url(target_ref: String, target_kind: String, branch_template: String, tag_template: String) -> String:
	var normalized_ref := target_ref.strip_edges()
	var template := tag_template if target_kind == "tag" else branch_template
	return template % normalized_ref.uri_encode().replace("%2F", "/")


func parse_plugin_cfg_version(content: String) -> String:
	for line in content.split("\n"):
		var normalized := str(line).strip_edges()
		if not normalized.begins_with("version"):
			continue
		var separator := normalized.find("=")
		if separator == -1:
			continue
		var value := normalized.substr(separator + 1).strip_edges()
		if value.length() >= 2 and ((value.begins_with("\"") and value.ends_with("\"")) or (value.begins_with("'") and value.ends_with("'"))):
			value = value.substr(1, value.length() - 2)
		return value.strip_edges()
	return ""


func resolve_current_commit(freshness) -> String:
	if freshness is Dictionary:
		var sync_snapshot = (freshness as Dictionary).get("sync", {})
		if sync_snapshot is Dictionary:
			return str((sync_snapshot as Dictionary).get("source_git_commit", "")).strip_edges()
	return ""


func build_local_compare_snapshot(base_commit: String, target: Dictionary, commit_histories = {}) -> Dictionary:
	var target_ref := str(target.get("ref", "")).strip_edges()
	var target_commit := str(target.get("commit", "")).strip_edges()
	var target_kind := str(target.get("kind", "branch")).strip_edges()
	var normalized_base := base_commit.strip_edges()
	var state := "unavailable"
	var error := ""
	var ahead_by := -1
	var behind_by := -1
	var source := "local_history"
	if normalized_base.is_empty() or target_ref.is_empty() or target_commit.is_empty():
		error = "local_history_unavailable"
	elif normalized_base == target_commit:
		state = "success"
		ahead_by = 0
		behind_by = 0
		source = "local_exact"
	elif not (commit_histories is Dictionary):
		error = "local_history_unavailable"
	else:
		var histories := commit_histories as Dictionary
		var base_history = histories.get(normalized_base, {})
		var target_history = histories.get(target_commit, {})
		if not (base_history is Dictionary) or not (target_history is Dictionary):
			error = "local_history_unavailable"
		elif not bool((base_history as Dictionary).get("complete", false)) or not bool((target_history as Dictionary).get("complete", false)):
			error = "local_history_incomplete"
		else:
			var base_commits := _normalize_history_commits((base_history as Dictionary).get("commits", []))
			var target_commits := _normalize_history_commits((target_history as Dictionary).get("commits", []))
			if base_commits.is_empty() or target_commits.is_empty() or not base_commits.has(normalized_base) or not target_commits.has(target_commit):
				error = "local_history_incomplete"
			else:
				var base_set := {}
				for commit in base_commits:
					base_set[commit] = true
				var target_set := {}
				for commit in target_commits:
					target_set[commit] = true
				var common_found := false
				for commit in target_commits:
					if base_set.has(commit):
						common_found = true
						break
				if not common_found:
					error = "local_history_no_common_commit"
				else:
					ahead_by = 0
					behind_by = 0
					for commit in target_commits:
						if not base_set.has(commit):
							ahead_by += 1
					for commit in base_commits:
						if not target_set.has(commit):
							behind_by += 1
					state = "success"
	return {
		"state": state,
		"base_commit": normalized_base,
		"target_kind": target_kind,
		"target_ref": target_ref,
		"target_commit": target_commit,
		"ahead_by": ahead_by,
		"behind_by": behind_by,
		"source": source,
		"error": error
	}


func _normalize_history_commits(raw_commits) -> Array[String]:
	var commits: Array[String] = []
	if not (raw_commits is Array):
		return commits
	for raw_commit in raw_commits as Array:
		var commit := str(raw_commit).strip_edges()
		if not commit.is_empty() and not commits.has(commit):
			commits.append(commit)
	return commits
