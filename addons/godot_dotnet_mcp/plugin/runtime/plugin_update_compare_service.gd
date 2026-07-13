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


func resolve_compare_head(target: Dictionary) -> String:
	var target_ref := str(target.get("ref", "")).strip_edges()
	var target_commit := str(target.get("commit", "")).strip_edges()
	if str(target.get("kind", "branch")) == "tag" and not target_ref.is_empty():
		return target_ref
	if not target_commit.is_empty():
		return target_commit
	return target_ref


func resolve_current_commit(freshness) -> String:
	if freshness is Dictionary:
		var sync_snapshot = (freshness as Dictionary).get("sync", {})
		if sync_snapshot is Dictionary:
			return str((sync_snapshot as Dictionary).get("source_git_commit", "")).strip_edges()
	return ""


func build_compare_cache_key(base_commit: String, target_kind: String, target_ref: String, target_commit: String) -> String:
	return "\n".join([
		base_commit.strip_edges(),
		target_kind.strip_edges(),
		target_ref.strip_edges(),
		target_commit.strip_edges()
	])


func build_compare_start_snapshot(base_commit: String, target: Dictionary, compare_cache: Dictionary = {}) -> Dictionary:
	var target_ref := str(target.get("ref", "")).strip_edges()
	var target_commit := str(target.get("commit", "")).strip_edges()
	var target_kind := str(target.get("kind", "branch")).strip_edges()
	var compare_head := resolve_compare_head(target)
	var state := "loading"
	var ahead_by := -1
	var behind_by := -1
	var source := "remote_required"
	if base_commit.strip_edges().is_empty() or compare_head.strip_edges().is_empty():
		state = "unavailable"
	elif not target_commit.is_empty() and base_commit == target_commit:
		state = "success"
		ahead_by = 0
		behind_by = 0
		source = "local_exact"
	else:
		var cache_key := build_compare_cache_key(base_commit, target_kind, target_ref, target_commit)
		var cached = compare_cache.get(cache_key, {})
		if cached is Dictionary and not target_commit.is_empty():
			var cached_entry := cached as Dictionary
			var cached_ahead := int((cached as Dictionary).get("ahead_by", -1))
			var cached_behind := int((cached as Dictionary).get("behind_by", -1))
			var cache_matches_target := str(cached_entry.get("base_commit", "")).strip_edges() == base_commit.strip_edges() \
				and str(cached_entry.get("target_kind", "")).strip_edges() == target_kind \
				and str(cached_entry.get("target_ref", "")).strip_edges() == target_ref \
				and str(cached_entry.get("target_commit", "")).strip_edges() == target_commit
			if cache_matches_target and cached_ahead >= 0 and cached_behind >= 0:
				state = "success"
				ahead_by = cached_ahead
				behind_by = cached_behind
				source = "cache"
	return {
		"state": state,
		"base_commit": base_commit.strip_edges(),
		"target_kind": target_kind,
		"target_ref": target_ref,
		"target_commit": target_commit,
		"compare_head": compare_head,
		"ahead_by": ahead_by,
		"behind_by": behind_by,
		"source": source,
		"error": ""
	}


func parse_compare_response(body: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		return {"success": false, "error": json.get_error_message()}
	if not (json.data is Dictionary):
		return {"success": false, "error": "Expected a JSON object"}
	var data := json.data as Dictionary
	if not data.has("ahead_by") or not data.has("behind_by"):
		return {"success": false, "error": "Compare response is missing ahead_by or behind_by"}
	var ahead_by := int(data.get("ahead_by", -1))
	var behind_by := int(data.get("behind_by", -1))
	if ahead_by < 0 or behind_by < 0:
		return {"success": false, "error": "Compare response contains invalid commit counts"}
	return {
		"success": true,
		"ahead_by": ahead_by,
		"behind_by": behind_by
	}
