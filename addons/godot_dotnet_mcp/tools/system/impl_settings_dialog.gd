@tool
extends RefCounted

## System implementation: settings_dialog

var bridge

const HANDLED_TOOLS := ["settings_dialog"]

const SURFACES := {
	"project_settings": {
		"label": "Project Settings",
		"menu_title": "Project",
		"menu_titles": ["Project", "项目", "專案", "Proyecto", "Projet", "Projekt", "Progetto", "プロジェクト", "프로젝트"],
		"menu_items": ["Project Settings...", "Project Settings", "项目设置...", "项目设置"],
		"match_queries": ["Project Settings", "ProjectSettings", "项目设置"],
		"search_queries": ["filter", "search", "筛选", "搜索"],
		"tabs": ["General", "Plugins", "Input Map", "Localization", "AutoLoad"]
	},
	"editor_settings": {
		"label": "Editor Settings",
		"menu_title": "Editor",
		"menu_titles": ["Editor", "编辑器", "編輯器", "Editor", "Éditeur", "Editor", "Editor", "エディター", "에디터"],
		"menu_items": ["Editor Settings...", "Editor Settings", "编辑器设置...", "编辑器设置"],
		"match_queries": ["Editor Settings", "EditorSettings", "编辑器设置"],
		"search_queries": ["filter", "search", "筛选", "搜索"],
		"tabs": ["General", "Shortcuts"]
	}
}


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(_context: Dictionary) -> void:
	pass


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "settings_dialog",
			"description": "SETTINGS DIALOG: High-level settings-like editor dialog workflow entry. Use it to open Project Settings or Editor Settings, wait until the target dialog is visible, summarize search fields and candidate setting rows, focus a returned result, capture evidence, and close the visible settings surface. This tool orchestrates editor UI controls and popups; it does not write project/editor setting values.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["open", "status", "search", "focus_result", "capture", "close"],
						"description": "Settings dialog workflow action"
					},
					"surface": {
						"type": "string",
						"enum": ["project_settings", "editor_settings"],
						"description": "Registered settings-like editor surface"
					},
					"query": {
						"type": "string",
						"description": "Text to search in the settings dialog"
					},
					"setting_path": {
						"type": "string",
						"description": "Optional setting path or path fragment to search for"
					},
					"tab": {
						"type": "string",
						"description": "Optional tab title or category hint to include in the search"
					},
					"target_path": {
						"type": "string",
						"description": "Control path returned by status/search for focus_result"
					},
					"include_hidden": {
						"type": "boolean",
						"description": "Include hidden controls while observing a settings surface (default false)"
					},
					"limit": {
						"type": "integer",
						"description": "Maximum controls or results to inspect/return (default 100)"
					},
					"timeout_ms": {
						"type": "integer",
						"description": "Maximum wait time for open verification (default 1500)"
					},
					"poll_interval_ms": {
						"type": "integer",
						"description": "Polling interval for open verification (default 50)"
					},
					"capture": {
						"type": "boolean",
						"description": "Capture editor evidence after open/search/focus when supported"
					},
					"path": {
						"type": "string",
						"description": "Optional output screenshot path for capture"
					}
				},
				"required": ["action"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name not in HANDLED_TOOLS:
		return bridge.error("Unknown tool: %s" % tool_name)
	var action := str(args.get("action", "")).strip_edges()
	match action:
		"status":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _status(surface, args)
		"search":
			return bridge.error("search requires asynchronous execution")
		"focus_result":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _focus_result(surface, args)
		"capture":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _capture(surface, args)
		"close":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _close(surface, args)
		"open":
			return bridge.error("open requires asynchronous execution")
		_:
			return bridge.error("Unknown action: %s" % action)


func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name not in HANDLED_TOOLS:
		return bridge.error("Unknown tool: %s" % tool_name)
	var action := str(args.get("action", "")).strip_edges()
	match action:
		"open":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return await _open(surface, args)
		"search":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return await _search(surface, args)
		_:
			return execute(tool_name, args)


func _resolve_surface(args: Dictionary) -> String:
	var surface := str(args.get("surface", "project_settings")).strip_edges()
	if SURFACES.has(surface):
		return surface
	return ""


func _status(surface: String, args: Dictionary) -> Dictionary:
	var observation := _observe(surface, args, [])
	return bridge.success(observation, "Settings surface status observed")


func _search(surface: String, args: Dictionary) -> Dictionary:
	var query_values := _search_terms(args)
	var search_text := _primary_search_text(query_values)
	var search_write: Dictionary = {}
	if not search_text.is_empty():
		search_write = await _write_search_field(surface, args, search_text)
		if not bool(search_write.get("success", false)):
			return search_write
	var observation := _observe(surface, args, query_values)
	observation["workflow"].append({"step": "search", "queries": query_values, "result_count": int(observation.get("result_count", 0))})
	if not search_write.is_empty():
		observation["search_field_write"] = search_write.get("data", {})
	if bool(args.get("capture", false)):
		_attach_capture(observation, args)
	return bridge.success(observation, "Settings surface searched")


func _focus_result(surface: String, args: Dictionary) -> Dictionary:
	var target_path := str(args.get("target_path", "")).strip_edges()
	var workflow: Array[Dictionary] = []
	if target_path.is_empty():
		var query_values := _search_terms(args)
		var observation := _observe(surface, args, query_values)
		workflow.assign(observation.get("workflow", []))
		target_path = _first_result_path(observation.get("results", []))
	if target_path.is_empty():
		return bridge.error("target_path or a matching search result is required", {"surface": surface, "workflow": workflow})
	var focus_result := bridge.call_atomic("editor_ui_control", {
		"action": "focus_control",
		"target_path": target_path
	})
	if not bool(focus_result.get("success", false)):
		return focus_result
	var payload: Dictionary = focus_result.get("data", {}).duplicate(true)
	payload["surface"] = surface
	payload["focused_result"] = {"path": target_path}
	payload["workflow"] = _workflow_with_step(workflow, {"step": "focus_result", "target_path": target_path, "success": true})
	if bool(args.get("capture", false)):
		_attach_capture(payload, args)
	return bridge.success(payload, "Settings result focused")


func _capture(surface: String, args: Dictionary) -> Dictionary:
	var observation := _observe(surface, args, _search_terms(args))
	_attach_capture(observation, args)
	return bridge.success(observation, "Settings surface captured")


func _close(surface: String, args: Dictionary) -> Dictionary:
	var observation := _observe(surface, args, [])
	var target_path := str(args.get("target_path", "")).strip_edges()
	if target_path.is_empty():
		target_path = str(observation.get("primary_popup_path", "")).strip_edges()
	if target_path.is_empty():
		return bridge.error("No closable popup found for settings surface: %s" % surface, observation)
	var close_result := bridge.call_atomic("editor_popup", {
		"action": "close_popup",
		"target_path": target_path
	})
	if not bool(close_result.get("success", false)):
		return close_result
	var payload: Dictionary = close_result.get("data", {}).duplicate(true)
	payload["surface"] = surface
	payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {"step": "close", "target_path": target_path, "success": true})
	return bridge.success(payload, "Settings surface closed")


func _open(surface: String, args: Dictionary) -> Dictionary:
	var current := _observe(surface, args, [])
	if bool(current.get("dialog_found", false)):
		current["opened"] = true
		current["already_open"] = true
		if bool(args.get("capture", false)):
			_attach_capture(current, args)
		return bridge.success(current, "Settings surface already open")
	var spec: Dictionary = SURFACES.get(surface, {})
	var attempts: Array[Dictionary] = []
	for menu_title in _surface_menu_titles(spec):
		for item_text in spec.get("menu_items", []):
			var select_result := bridge.call_atomic("editor_ui_control", {
				"action": "select_menu_item",
				"menu_title": menu_title,
				"item_text": str(item_text)
			})
			attempts.append({
				"step": "select_menu_item",
				"menu_title": menu_title,
				"item_text": str(item_text),
				"success": bool(select_result.get("success", false)),
				"message": str(select_result.get("message", select_result.get("error", "")))
			})
			if bool(select_result.get("success", false)):
				var wait_result := await _wait_for_surface(surface, args)
				attempts.append({
					"step": "wait_for_ui",
					"success": bool(wait_result.get("success", false)),
					"message": str(wait_result.get("message", wait_result.get("error", "")))
				})
				if bool(wait_result.get("success", false)):
					var observation := _observe(surface, args, _search_terms(args))
					observation["opened"] = true
					observation["workflow"] = _merge_workflow(attempts, observation.get("workflow", []))
					observation["verification"] = wait_result.get("data", {})
					if bool(args.get("capture", false)):
						_attach_capture(observation, args)
					return bridge.success(observation, "Settings surface opened")
				return bridge.error("Timed out waiting for settings surface: %s" % surface, {"surface": surface, "opened": false, "workflow": attempts, "verification": wait_result.get("data", {})})
	return bridge.error("Failed to open settings surface: %s" % surface, {"surface": surface, "opened": false, "workflow": attempts})


func _observe(surface: String, args: Dictionary, query_values: Array[String]) -> Dictionary:
	var spec: Dictionary = SURFACES.get(surface, {})
	var controls_result := bridge.call_atomic("editor_ui_control", {
		"action": "list_visible",
		"include_hidden": bool(args.get("include_hidden", false)),
		"limit": _observation_limit(args),
		"max_depth": int(args.get("max_depth", 10))
	})
	var workflow: Array[Dictionary] = [{
		"step": "list_visible",
		"success": bool(controls_result.get("success", false))
	}]
	var control_rows: Array = []
	if bool(controls_result.get("success", false)):
		control_rows = controls_result.get("data", {}).get("controls", [])
	var popup_result := bridge.call_atomic("editor_popup", {"action": "list_visible"})
	workflow.append({
		"step": "list_popups",
		"success": bool(popup_result.get("success", false))
	})
	var popup_rows: Array = []
	if bool(popup_result.get("success", false)):
		popup_rows = popup_result.get("data", {}).get("popups", [])
	var surface_matches := _matching_rows(control_rows, spec.get("match_queries", []))
	var popup_matches := _matching_rows(popup_rows, spec.get("match_queries", []))
	var results := _candidate_results(control_rows, query_values, _result_limit(args))
	var search_field_path := _first_path(_matching_rows(control_rows, spec.get("search_queries", []), ["LineEdit", "TextEdit", "SearchBox"]), "path")
	return {
		"surface": surface,
		"title": str(spec.get("label", surface)),
		"opened": not surface_matches.is_empty() or not popup_matches.is_empty(),
		"dialog_found": not surface_matches.is_empty() or not popup_matches.is_empty(),
		"dialog_path": _first_path(surface_matches, "path"),
		"primary_popup_path": _first_path(popup_matches, "node_path"),
		"search_field_path": search_field_path,
		"current_tab": _current_tab_hint(control_rows, spec),
		"results": results,
		"result_count": results.size(),
		"visible_popup_count": popup_rows.size(),
		"surface_matches": surface_matches,
		"popup_matches": popup_matches,
		"observed_control_count": control_rows.size(),
		"workflow": workflow
	}


func _candidate_results(rows: Array, query_values: Array[String], limit: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for row in rows:
		if not (row is Dictionary):
			continue
		var dict := row as Dictionary
		if not query_values.is_empty() and not _haystack_matches(dict, query_values):
			continue
		var path := str(dict.get("path", dict.get("node_path", ""))).strip_edges()
		var text := str(dict.get("text", dict.get("title", dict.get("name", "")))).strip_edges()
		if path.is_empty() and text.is_empty():
			continue
		results.append({
			"text": text,
			"class": str(dict.get("class", "")),
			"path": path,
			"visible": bool(dict.get("visible", true)),
			"enabled": bool(dict.get("enabled", true)),
			"section_hint": _section_hint(dict),
			"setting_path_hint": _setting_path_hint(dict),
			"value_text_hint": _value_text_hint(dict)
		})
		if results.size() >= limit:
			break
	return results


func _search_terms(args: Dictionary) -> Array[String]:
	var values: Array[String] = []
	for key in ["query", "setting_path", "tab"]:
		_append_search_term(values, str(args.get(key, "")))
	return values


func _append_search_term(values: Array[String], value: String) -> void:
	var normalized := value.strip_edges()
	if not normalized.is_empty() and not values.has(normalized):
		values.append(normalized)


func _primary_search_text(query_values: Array[String]) -> String:
	for value in query_values:
		if not value.strip_edges().is_empty():
			return value.strip_edges()
	return ""


func _write_search_field(surface: String, args: Dictionary, text: String) -> Dictionary:
	var observation := _observe(surface, args, [])
	var search_field_path := str(observation.get("search_field_path", "")).strip_edges()
	if search_field_path.is_empty():
		return bridge.error("No search field found for settings surface: %s" % surface, observation)
	var set_result := bridge.call_atomic("editor_ui_control", {
		"action": "set_text",
		"target_path": search_field_path,
		"text": text
	})
	if not bool(set_result.get("success", false)):
		return set_result
	var wait_result: Dictionary = await bridge.call_atomic_async("editor_ui_control", {
		"action": "wait_for_ui",
		"target_path": search_field_path,
		"condition": "text_equals",
		"text": text,
		"timeout_ms": int(args.get("timeout_ms", 1500)),
		"poll_interval_ms": int(args.get("poll_interval_ms", 50)),
		"limit": _observation_limit(args),
		"max_depth": int(args.get("max_depth", 10))
	})
	var payload: Dictionary = set_result.get("data", {}).duplicate(true)
	payload["surface"] = surface
	payload["search_field_path"] = search_field_path
	payload["text"] = text
	payload["verification"] = wait_result.get("data", {})
	if bool(wait_result.get("success", false)):
		return bridge.success(payload, "Settings search field updated")
	return bridge.error("Timed out waiting for settings search field text", payload)


func _surface_menu_titles(spec: Dictionary) -> Array[String]:
	var titles: Array[String] = []
	for title in spec.get("menu_titles", []):
		_append_search_term(titles, str(title))
	_append_search_term(titles, str(spec.get("menu_title", "")))
	return titles


func _merge_workflow(first, second) -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	_append_workflow_entries(merged, first)
	_append_workflow_entries(merged, second)
	return merged


func _workflow_with_step(workflow, step: Dictionary) -> Array[Dictionary]:
	var merged := _merge_workflow(workflow, [])
	merged.append(step)
	return merged


func _append_workflow_entries(target: Array[Dictionary], entries) -> void:
	if not (entries is Array):
		return
	for entry in entries:
		if entry is Dictionary:
			target.append((entry as Dictionary).duplicate(true))


func _matching_rows(rows: Array, queries: Array, class_filters: Array = []) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	var normalized_queries := _normalize_queries(queries)
	var normalized_classes := _normalize_queries(class_filters)
	for row in rows:
		if not (row is Dictionary):
			continue
		var dict := row as Dictionary
		if not normalized_classes.is_empty() and not _class_matches(dict, normalized_classes):
			continue
		if normalized_queries.is_empty() or _haystack_matches(dict, normalized_queries):
			matches.append(dict.duplicate(true))
	return matches


func _normalize_queries(queries: Array) -> Array[String]:
	var normalized: Array[String] = []
	for query in queries:
		var value := str(query).strip_edges().to_lower()
		if not value.is_empty():
			normalized.append(value)
	return normalized


func _class_matches(row: Dictionary, class_filters: Array[String]) -> bool:
	var class_name := str(row.get("class", "")).to_lower()
	for class_filter in class_filters:
		if class_name.contains(class_filter.to_lower()):
			return true
	return false


func _haystack_matches(row: Dictionary, queries: Array[String]) -> bool:
	var haystack := " ".join([
		str(row.get("path", "")),
		str(row.get("node_path", "")),
		str(row.get("name", "")),
		str(row.get("title", "")),
		str(row.get("text", "")),
		str(row.get("class", "")),
		str(row.get("tooltip", ""))
	]).to_lower()
	for query in queries:
		if haystack.contains(query.to_lower()):
			return true
	return false


func _first_path(rows: Array, key: String) -> String:
	for row in rows:
		if row is Dictionary:
			var value := str((row as Dictionary).get(key, "")).strip_edges()
			if not value.is_empty():
				return value
	return ""


func _first_result_path(rows: Array) -> String:
	for row in rows:
		if row is Dictionary:
			var path := str((row as Dictionary).get("path", "")).strip_edges()
			if not path.is_empty():
				return path
	return ""


func _wait_for_surface(surface: String, args: Dictionary) -> Dictionary:
	var spec: Dictionary = SURFACES.get(surface, {})
	var match_queries: Array = spec.get("match_queries", [])
	var wait_queries: Array[String] = []
	for query in match_queries:
		_append_search_term(wait_queries, str(query))
	_append_search_term(wait_queries, str(spec.get("label", surface)))
	var last_result: Dictionary = {}
	for query in wait_queries:
		var wait_result: Dictionary = await bridge.call_atomic_async("editor_ui_control", {
			"action": "wait_for_ui",
			"text_query": query,
			"condition": "text_contains",
			"text": query,
			"timeout_ms": int(args.get("timeout_ms", 1500)),
			"poll_interval_ms": int(args.get("poll_interval_ms", 50)),
			"limit": _observation_limit(args),
			"max_depth": int(args.get("max_depth", 10))
		})
		if bool(wait_result.get("success", false)):
			return wait_result
		last_result = wait_result
	return last_result


func _attach_capture(payload: Dictionary, args: Dictionary) -> void:
	var capture_args := {"action": "capture"}
	var output_path := str(args.get("path", "")).strip_edges()
	if not output_path.is_empty():
		capture_args["path"] = output_path
	var capture_result := bridge.call_atomic("editor_screenshot", capture_args)
	payload["capture"] = capture_result.get("data", {}) if bool(capture_result.get("success", false)) else {}
	payload["capture_path"] = str(capture_result.get("data", {}).get("path", ""))
	if not bool(capture_result.get("success", false)):
		payload["capture_error"] = str(capture_result.get("message", capture_result.get("error", "")))


func _observation_limit(args: Dictionary) -> int:
	return max(1, int(args.get("limit", 100)))


func _result_limit(args: Dictionary) -> int:
	return max(1, int(args.get("limit", 100)))


func _current_tab_hint(rows: Array, spec: Dictionary) -> String:
	var tabs: Array = spec.get("tabs", [])
	for row in rows:
		if not (row is Dictionary):
			continue
		var dict := row as Dictionary
		var text := str(dict.get("text", dict.get("title", dict.get("name", ""))))
		for tab in tabs:
			if text.to_lower().contains(str(tab).to_lower()):
				return str(tab)
	return ""


func _section_hint(row: Dictionary) -> String:
	return str(row.get("section", row.get("category", row.get("parent_text", ""))))


func _setting_path_hint(row: Dictionary) -> String:
	var text := str(row.get("setting_path", row.get("path_hint", ""))).strip_edges()
	if not text.is_empty():
		return text
	var tooltip := str(row.get("tooltip", "")).strip_edges()
	if tooltip.contains("/") or tooltip.contains("."):
		return tooltip
	return ""


func _value_text_hint(row: Dictionary) -> String:
	for key in ["value_text", "value", "text"]:
		var value := str(row.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""
