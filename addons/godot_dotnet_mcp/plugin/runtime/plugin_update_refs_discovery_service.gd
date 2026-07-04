@tool
extends RefCounted
class_name PluginUpdateRefsDiscoveryService


func parse_refs_json_array(body: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		return {"success": false, "error": json.get_error_message()}
	if not (json.data is Array):
		return {"success": false, "error": "Expected a JSON array"}
	return {"success": true, "items": json.data}


func extract_next_url(headers: PackedStringArray) -> String:
	for header in headers:
		var header_text := str(header)
		if not header_text.to_lower().begins_with("link:"):
			continue
		var link_value := header_text.substr(header_text.find(":") + 1).strip_edges()
		for segment in link_value.split(","):
			if segment.find('rel="next"') == -1:
				continue
			var start := segment.find("<")
			var end := segment.find(">")
			if start >= 0 and end > start:
				return segment.substr(start + 1, end - start - 1)
	return ""


func append_names(pending: Dictionary, key: String, names: Array[String]) -> Dictionary:
	var next_pending := pending.duplicate(true)
	var values: Array[String] = to_string_array(next_pending.get(key, []))
	for name in names:
		append_unique_ref(values, name)
	next_pending[key] = values
	return next_pending


func append_commits(pending: Dictionary, items: Array, name_key: String) -> Dictionary:
	var next_pending := pending.duplicate(true)
	var commits: Dictionary = duplicate_commits(next_pending.get("commits", {}))
	for item in items:
		if not (item is Dictionary):
			continue
		var item_dict := item as Dictionary
		var name := str(item_dict.get(name_key, "")).strip_edges()
		var commit := extract_commit(item_dict)
		if not name.is_empty() and not commit.is_empty():
			commits[name] = commit
	next_pending["commits"] = commits
	return next_pending


func collect_names(items: Array, key: String) -> Array[String]:
	var names: Array[String] = []
	for item in items:
		if not (item is Dictionary):
			continue
		append_unique_ref(names, str((item as Dictionary).get(key, "")))
	return names


func collect_stable_release_names(items: Array) -> Array[String]:
	var names: Array[String] = []
	for item in items:
		if not (item is Dictionary):
			continue
		var item_dict := item as Dictionary
		if bool(item_dict.get("prerelease", false)):
			continue
		append_unique_ref(names, str(item_dict.get("tag_name", "")))
	return names


func extract_commit(item: Dictionary) -> String:
	var commit_value = item.get("commit", "")
	if commit_value is Dictionary:
		return str((commit_value as Dictionary).get("sha", "")).strip_edges()
	return str(item.get("target_commitish", "")).strip_edges()


func to_string_array(values) -> Array[String]:
	var result: Array[String] = []
	if not (values is Array):
		return result
	for value in values:
		append_unique_ref(result, str(value))
	return result


func duplicate_commits(raw_commits) -> Dictionary:
	var commits: Dictionary = {}
	if not (raw_commits is Dictionary):
		return commits
	for key in (raw_commits as Dictionary).keys():
		commits[str(key)] = str((raw_commits as Dictionary).get(key, ""))
	return commits


func build_final_snapshot(pending: Dictionary) -> Dictionary:
	var releases := to_string_array(pending.get("releases", []))
	var stable_releases := to_string_array(pending.get("stable_releases", []))
	var release_or_tag_values: Array[String] = []
	for release in releases:
		append_unique_ref(release_or_tag_values, release)
	for tag in to_string_array(pending.get("tags", [])):
		append_unique_ref(release_or_tag_values, tag)
	return {
		"branches": to_string_array(pending.get("branches", [])),
		"commits": duplicate_commits(pending.get("commits", {})),
		"releases": release_or_tag_values,
		"latest_release": releases[0] if not releases.is_empty() else "",
		"latest_stable_release": stable_releases[0] if not stable_releases.is_empty() else "",
		"release_source": "releases_and_tags",
		"errors": to_string_array(pending.get("errors", []))
	}


func record_active_request(
	pending: Dictionary,
	kind: String,
	url: String,
	serial: int,
	started_msec: int,
	timeout_msec: int,
	request_name: String,
	page: int
) -> Dictionary:
	var next_pending := pending.duplicate(true)
	var active_requests := duplicate_dictionary(next_pending.get("active_requests", {}))
	active_requests[kind] = {
		"kind": kind,
		"url": url,
		"serial": serial,
		"started_msec": started_msec,
		"timeout_msec": timeout_msec,
		"request_name": request_name,
		"page": page
	}
	next_pending["active_requests"] = active_requests
	return next_pending


func clear_active_request(pending: Dictionary, kind: String) -> Dictionary:
	var next_pending := pending.duplicate(true)
	var active_requests := duplicate_dictionary(next_pending.get("active_requests", {}))
	active_requests.erase(kind)
	next_pending["active_requests"] = active_requests
	return next_pending


func find_stale_active_requests(pending: Dictionary, now_msec: int) -> Array[Dictionary]:
	var stale: Array[Dictionary] = []
	var active_requests := duplicate_dictionary(pending.get("active_requests", {}))
	for raw_kind in active_requests.keys():
		var kind := str(raw_kind)
		if is_kind_done(pending, kind):
			continue
		var request = active_requests.get(raw_kind, {})
		if not (request is Dictionary):
			continue
		var request_dict: Dictionary = request as Dictionary
		var timeout_msec := int(request_dict.get("timeout_msec", 0))
		var started_msec := int(request_dict.get("started_msec", 0))
		if timeout_msec <= 0 or started_msec <= 0:
			continue
		if now_msec - started_msec >= timeout_msec:
			stale.append(request_dict.duplicate(true))
	return stale


func build_pending_status(pending: Dictionary, now_msec: int) -> Dictionary:
	if pending.is_empty():
		return {}
	var active: Array[Dictionary] = []
	var active_requests := duplicate_dictionary(pending.get("active_requests", {}))
	for raw_kind in active_requests.keys():
		var request = active_requests.get(raw_kind, {})
		if not (request is Dictionary):
			continue
		var request_dict: Dictionary = (request as Dictionary).duplicate(true)
		request_dict["elapsed_msec"] = maxi(0, now_msec - int(request_dict.get("started_msec", now_msec)))
		active.append(request_dict)
	return {
		"serial": int(pending.get("serial", 0)),
		"background": bool(pending.get("background", false)),
		"waiting_kinds": get_waiting_kinds(pending),
		"active_requests": active,
		"errors": to_string_array(pending.get("errors", []))
	}


func get_waiting_kinds(pending: Dictionary) -> Array[String]:
	var waiting: Array[String] = []
	for kind in ["branches", "releases", "tags"]:
		if not is_kind_done(pending, kind):
			waiting.append(kind)
	return waiting


func is_kind_done(pending: Dictionary, kind: String) -> bool:
	match kind:
		"branches":
			return bool(pending.get("branch_done", false))
		"releases":
			return bool(pending.get("release_done", false))
		"tags":
			return bool(pending.get("tag_done", false))
		_:
			return false


func duplicate_dictionary(raw_value) -> Dictionary:
	if raw_value is Dictionary:
		return (raw_value as Dictionary).duplicate(true)
	return {}


func append_unique_ref(values: Array[String], value: String) -> void:
	var normalized := value.strip_edges()
	if normalized.is_empty() or values.has(normalized):
		return
	values.append(normalized)
