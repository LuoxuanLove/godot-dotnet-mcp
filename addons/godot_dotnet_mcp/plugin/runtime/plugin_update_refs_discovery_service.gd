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


func append_release_rows(pending: Dictionary, items: Array) -> Dictionary:
	var next_pending := pending.duplicate(true)
	var rows: Array = duplicate_rows(next_pending.get("release_rows", []))
	for item in items:
		if not (item is Dictionary):
			continue
		var item_dict := item as Dictionary
		var tag := str(item_dict.get("tag_name", "")).strip_edges()
		if tag.is_empty():
			continue
		rows.append({
			"kind": "tag",
			"ref": tag,
			"commit": "",
			"title": _first_line(str(item_dict.get("name", tag))).strip_edges(),
			"date": str(item_dict.get("published_at", item_dict.get("created_at", ""))).strip_edges(),
			"stable": not bool(item_dict.get("prerelease", false))
		})
	next_pending["release_rows"] = rows
	return next_pending


func append_tag_rows(pending: Dictionary, items: Array) -> Dictionary:
	var next_pending := pending.duplicate(true)
	var rows: Array = duplicate_rows(next_pending.get("tag_rows", []))
	for item in items:
		if not (item is Dictionary):
			continue
		var item_dict := item as Dictionary
		var tag := str(item_dict.get("name", "")).strip_edges()
		if tag.is_empty():
			continue
		rows.append({
			"kind": "tag",
			"ref": tag,
			"commit": extract_commit(item_dict),
			"title": "tag",
			"date": "",
			"stable": true
		})
	next_pending["tag_rows"] = rows
	return next_pending


func append_branch_commit_rows(pending: Dictionary, branch: String, items: Array) -> Dictionary:
	var next_pending := pending.duplicate(true)
	var branch_rows := duplicate_branch_commit_rows(next_pending.get("branch_commit_rows", {}))
	var rows: Array = []
	for item in items:
		if not (item is Dictionary):
			continue
		var item_dict := item as Dictionary
		var commit_value = item_dict.get("commit", {})
		var commit_dict := {}
		if commit_value is Dictionary:
			commit_dict = commit_value as Dictionary
		var author_value = commit_dict.get("author", {})
		var author_dict := {}
		if author_value is Dictionary:
			author_dict = author_value as Dictionary
		var message := _first_line(str(commit_dict.get("message", ""))).strip_edges()
		rows.append({
			"kind": "branch",
			"ref": branch,
			"commit": str(item_dict.get("sha", "")).strip_edges(),
			"title": message if not message.is_empty() else "commit",
			"date": str(author_dict.get("date", "")).strip_edges(),
			"stable": false
		})
	branch_rows[branch] = rows
	next_pending["branch_commit_rows"] = branch_rows
	return next_pending


func begin_commit_history(pending: Dictionary, head_commit: String, reset: bool = false) -> Dictionary:
	var normalized_head := head_commit.strip_edges()
	if normalized_head.is_empty():
		return pending.duplicate(true)
	var next_pending := pending.duplicate(true)
	var histories := duplicate_commit_histories(next_pending.get("commit_histories", {}))
	if reset or not histories.has(normalized_head):
		histories[normalized_head] = {
			"head_commit": normalized_head,
			"commits": [],
			"complete": false,
			"done": false,
			"pages": 1
		}
	next_pending["commit_histories"] = histories
	return next_pending


func append_commit_history(pending: Dictionary, head_commit: String, items: Array) -> Dictionary:
	var normalized_head := head_commit.strip_edges()
	if normalized_head.is_empty():
		return pending.duplicate(true)
	var next_pending := begin_commit_history(pending, normalized_head)
	var histories := duplicate_commit_histories(next_pending.get("commit_histories", {}))
	var entry: Dictionary = histories.get(normalized_head, {})
	var commits := to_string_array(entry.get("commits", []))
	for item in items:
		if not (item is Dictionary):
			continue
		append_unique_ref(commits, str((item as Dictionary).get("sha", "")))
	entry["head_commit"] = normalized_head
	entry["commits"] = commits
	histories[normalized_head] = entry
	next_pending["commit_histories"] = histories
	return next_pending


func finish_commit_history(pending: Dictionary, head_commit: String, complete: bool) -> Dictionary:
	var normalized_head := head_commit.strip_edges()
	if normalized_head.is_empty():
		return pending.duplicate(true)
	var next_pending := begin_commit_history(pending, normalized_head)
	var histories := duplicate_commit_histories(next_pending.get("commit_histories", {}))
	var entry: Dictionary = histories.get(normalized_head, {})
	entry["head_commit"] = normalized_head
	entry["complete"] = complete
	entry["done"] = true
	histories[normalized_head] = entry
	next_pending["commit_histories"] = histories
	return next_pending


func mark_commit_history_failed(pending: Dictionary, head_commit: String) -> Dictionary:
	return finish_commit_history(pending, head_commit, false)


func get_commit_history_pages(pending: Dictionary, head_commit: String) -> int:
	var entry = duplicate_commit_histories(pending.get("commit_histories", {})).get(head_commit.strip_edges(), {})
	if not (entry is Dictionary):
		return 1
	return maxi(1, int((entry as Dictionary).get("pages", 1)))


func increment_commit_history_page(pending: Dictionary, head_commit: String) -> Dictionary:
	var normalized_head := head_commit.strip_edges()
	var next_pending := begin_commit_history(pending, normalized_head)
	var histories := duplicate_commit_histories(next_pending.get("commit_histories", {}))
	var entry: Dictionary = histories.get(normalized_head, {})
	entry["pages"] = get_commit_history_pages(next_pending, normalized_head) + 1
	histories[normalized_head] = entry
	next_pending["commit_histories"] = histories
	return next_pending


func are_commit_histories_done(pending: Dictionary) -> bool:
	var histories := duplicate_commit_histories(pending.get("commit_histories", {}))
	if histories.is_empty():
		return true
	for entry in histories.values():
		if not (entry is Dictionary) or not bool((entry as Dictionary).get("done", false)):
			return false
	return true


func duplicate_commit_histories(raw_histories) -> Dictionary:
	var histories := {}
	if not (raw_histories is Dictionary):
		return histories
	for raw_key in (raw_histories as Dictionary).keys():
		var head_commit := str(raw_key).strip_edges()
		var raw_entry = (raw_histories as Dictionary).get(raw_key, {})
		if head_commit.is_empty() or not (raw_entry is Dictionary):
			continue
		var entry := raw_entry as Dictionary
		histories[head_commit] = {
			"head_commit": str(entry.get("head_commit", head_commit)).strip_edges(),
			"commits": to_string_array(entry.get("commits", [])),
			"complete": bool(entry.get("complete", false)),
			"done": bool(entry.get("done", false)),
			"pages": maxi(1, int(entry.get("pages", 1))),
		"checked_unix": int(entry.get("checked_unix", 0))
		}
	return histories


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


func duplicate_rows(raw_rows) -> Array:
	var rows: Array = []
	if not (raw_rows is Array):
		return rows
	for row in raw_rows:
		if row is Dictionary:
			rows.append((row as Dictionary).duplicate(true))
	return rows


func duplicate_branch_commit_rows(raw_rows) -> Dictionary:
	var rows: Dictionary = {}
	if not (raw_rows is Dictionary):
		return rows
	for key in (raw_rows as Dictionary).keys():
		rows[str(key)] = duplicate_rows((raw_rows as Dictionary).get(key, []))
	return rows


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
		"release_rows": build_release_table_rows(pending),
		"branch_commit_rows": duplicate_branch_commit_rows(pending.get("branch_commit_rows", {})),
		"commit_histories": duplicate_commit_histories(pending.get("commit_histories", {})),
		"errors": to_string_array(pending.get("errors", []))
	}


func build_release_table_rows(pending: Dictionary) -> Array:
	var commits := duplicate_commits(pending.get("commits", {}))
	var rows := duplicate_rows(pending.get("release_rows", []))
	var seen: Array[String] = []
	var result: Array = []
	for row in rows:
		if not (row is Dictionary):
			continue
		var row_dict: Dictionary = (row as Dictionary).duplicate(true)
		var ref := str(row_dict.get("ref", "")).strip_edges()
		if ref.is_empty() or seen.has(ref):
			continue
		row_dict["commit"] = str(commits.get(ref, row_dict.get("commit", ""))).strip_edges()
		result.append(row_dict)
		seen.append(ref)
	for tag_row in duplicate_rows(pending.get("tag_rows", [])):
		var tag_ref := str(tag_row.get("ref", "")).strip_edges()
		if tag_ref.is_empty() or seen.has(tag_ref):
			continue
		var normalized_tag_row: Dictionary = (tag_row as Dictionary).duplicate(true)
		normalized_tag_row["commit"] = str(commits.get(tag_ref, normalized_tag_row.get("commit", ""))).strip_edges()
		result.append(normalized_tag_row)
		seen.append(tag_ref)
	return result


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
	for kind in ["branches", "releases", "tags", "branch_commits"]:
		if not is_kind_done(pending, kind):
			waiting.append(kind)
	for raw_head in duplicate_commit_histories(pending.get("commit_histories", {})).keys():
		var head_commit := str(raw_head)
		if not is_kind_done(pending, "commit_history:%s" % head_commit):
			waiting.append("commit_history:%s" % head_commit)
	return waiting


func is_kind_done(pending: Dictionary, kind: String) -> bool:
	match kind:
		"branches":
			return bool(pending.get("branch_done", false))
		"releases":
			return bool(pending.get("release_done", false))
		"tags":
			return bool(pending.get("tag_done", false))
		"branch_commits":
			return bool(pending.get("branch_commits_done", false))
		_:
			if kind.begins_with("commit_history:"):
				var head_commit := kind.trim_prefix("commit_history:").strip_edges()
				var entry = duplicate_commit_histories(pending.get("commit_histories", {})).get(head_commit, {})
				return entry is Dictionary and bool((entry as Dictionary).get("done", false))
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


func _first_line(text: String) -> String:
	var lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	return str(lines[0]) if not lines.is_empty() else text
