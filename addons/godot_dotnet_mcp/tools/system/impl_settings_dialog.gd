@tool
extends RefCounted

## System implementation: settings_dialog

var bridge

const HANDLED_TOOLS := ["settings_dialog"]

const SURFACES := {
	"project_settings": {
		"label": "Project Settings",
		"menu_title": "Project",
		"menu_titles": ["Project", "项目", "專案", "Proyecto", "Projet", "Projekt", "Progetto", "Projeto", "Проект", "プロジェクト", "프로젝트"],
		"menu_items": [
			"Project Settings...", "Project Settings",
			"项目设置...", "项目设置", "專案設定...", "專案設定",
			"Configuración del Proyecto...", "Configuración del Proyecto",
			"Paramètres du projet...", "Paramètres du projet",
			"Projekteinstellungen...", "Projekteinstellungen",
			"Impostazioni progetto...", "Impostazioni progetto",
			"Configurações do Projeto...", "Configurações do Projeto",
			"Настройки проекта...", "Настройки проекта",
			"プロジェクト設定...", "プロジェクト設定",
			"프로젝트 설정...", "프로젝트 설정"
		],
		"match_queries": ["Project Settings", "ProjectSettings", "项目设置"],
		"search_queries": ["filter", "search", "筛选", "搜索"],
		"tabs": ["General", "Plugins", "Input Map", "Localization", "AutoLoad"]
	},
	"editor_settings": {
		"label": "Editor Settings",
		"menu_title": "Editor",
		"menu_titles": ["Editor", "编辑器", "編輯器", "Editor", "Éditeur", "Editor", "Editor", "Editor", "Редактор", "エディター", "에디터"],
		"menu_items": [
			"Editor Settings...", "Editor Settings",
			"编辑器设置...", "编辑器设置", "編輯器設定...", "編輯器設定",
			"Configuración del Editor...", "Configuración del Editor",
			"Paramètres de l'éditeur...", "Paramètres de l'éditeur",
			"Editoreinstellungen...", "Editoreinstellungen",
			"Impostazioni editor...", "Impostazioni editor",
			"Configurações do Editor...", "Configurações do Editor",
			"Настройки редактора...", "Настройки редактора",
			"エディター設定...", "エディター設定",
			"에디터 설정...", "에디터 설정"
		],
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
			"description": "SETTINGS DIALOG: High-level settings-like editor dialog workflow entry. Use it to open Project Settings or Editor Settings, wait until the target dialog is visible, summarize search fields and candidate setting rows, list conservative read-only row models, read current visible row values, focus a unique row's value editor, focus a returned result, capture evidence, and close the visible settings surface. This tool orchestrates editor UI controls and popups; it does not write project/editor setting values.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["open", "status", "search", "list_rows", "read_value", "focus_value", "focus_result", "capture", "close"],
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
						"description": "Optional setting path or path fragment. search writes this text into the settings filter; list_rows/read_value/focus_value only filter currently observed visible rows."
					},
					"tab": {
						"type": "string",
						"description": "Optional tab title or category hint to include in the search"
					},
					"target_path": {
						"type": "string",
						"description": "Control path returned by status/search/list_rows for focus_result, or a row/value control path used by read_value/focus_value"
					},
					"include_raw_controls": {
						"type": "boolean",
						"description": "Include raw observed control rows in list_rows for diagnostics (default false)"
					},
					"require_confidence": {
						"type": "string",
						"enum": ["low", "medium", "high"],
						"description": "Minimum row model confidence accepted by read_value/focus_value (default medium)"
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
		"list_rows":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _list_rows(surface, args)
		"read_value":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _read_value(surface, args)
		"focus_value":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _focus_value(surface, args)
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
	var observation: Dictionary = _observe(surface, args, [])
	return bridge.success(observation, "Settings surface status observed")


func _search(surface: String, args: Dictionary) -> Dictionary:
	var query_values: Array[String] = _search_terms(args)
	var search_text := _primary_search_text(query_values)
	var search_write: Dictionary = {}
	if not search_text.is_empty():
		search_write = await _write_search_field(surface, args, search_text)
		if not bool(search_write.get("success", false)):
			return search_write
	var observation: Dictionary = _observe(surface, args, query_values)
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
		var query_values: Array[String] = _search_terms(args)
		var observation: Dictionary = _observe(surface, args, query_values)
		workflow.assign(observation.get("workflow", []))
		target_path = _first_result_path(observation.get("results", []))
	if target_path.is_empty():
		return bridge.error("target_path or a matching search result is required", {"surface": surface, "workflow": workflow})
	var focus_result: Dictionary = bridge.call_atomic("editor_ui_control", {
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


func _list_rows(surface: String, args: Dictionary) -> Dictionary:
	var query_values: Array[String] = _search_terms(args)
	var observation: Dictionary = _observe(surface, args, query_values)
	var rows: Array[Dictionary] = _settings_row_models(observation.get("all_controls", []), surface, query_values, _result_limit(args))
	var payload: Dictionary = {
		"surface": surface,
		"dialog_found": bool(observation.get("dialog_found", false)),
		"dialog_path": str(observation.get("dialog_path", "")),
		"primary_popup_path": str(observation.get("primary_popup_path", "")),
		"current_tab": str(observation.get("current_tab", "")),
		"rows": rows,
		"row_count": rows.size(),
		"model_quality": _row_model_quality(rows),
		"workflow": _workflow_with_step(observation.get("workflow", []), {
			"step": "list_rows",
			"queries": query_values,
			"row_count": rows.size(),
			"success": true
		})
	}
	if bool(args.get("include_raw_controls", false)):
		payload["raw_controls"] = observation.get("all_controls", [])
	if bool(args.get("capture", false)):
		_attach_capture(payload, args)
	return bridge.success(payload, "Settings rows listed")


func _read_value(surface: String, args: Dictionary) -> Dictionary:
	var query_values: Array[String] = _search_terms(args)
	var observation: Dictionary = _observe(surface, _read_value_observation_args(args), query_values)
	if not bool(observation.get("dialog_found", false)):
		var missing_payload := observation.duplicate(true)
		missing_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "read_value",
			"success": false,
			"reason": "surface_not_visible"
		})
		return bridge.error("Settings surface is not visible for read_value: %s" % surface, missing_payload)
	if bool(observation.get("control_truncated", false)) and str(args.get("target_path", "")).strip_edges().is_empty():
		var truncated_payload := observation.duplicate(true)
		truncated_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "read_value",
			"success": false,
			"reason": "control_enumeration_truncated"
		})
		return bridge.error("Settings controls were truncated; pass target_path or increase limit before read_value.", truncated_payload)
	var all_controls: Array = observation.get("all_controls", [])
	var row_resolution: Dictionary = _resolve_row_for_value_read(all_controls, surface, args, query_values)
	if not bool(row_resolution.get("success", false)):
		var error_payload := observation.duplicate(true)
		error_payload["resolution"] = row_resolution
		error_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "read_value",
			"success": false,
			"reason": str(row_resolution.get("reason", "row_not_found"))
		})
		return bridge.error(str(row_resolution.get("message", "No unique settings row matched read_value.")), error_payload)
	var row: Dictionary = row_resolution.get("row", {})
	var value_payload: Dictionary = _read_row_value(row, all_controls)
	value_payload["surface"] = surface
	value_payload["dialog_found"] = bool(observation.get("dialog_found", false))
	value_payload["dialog_path"] = str(observation.get("dialog_path", ""))
	value_payload["primary_popup_path"] = str(observation.get("primary_popup_path", ""))
	value_payload["row"] = row
	value_payload["resolution"] = row_resolution.get("resolution", {})
	value_payload["verification"] = {
		"unique_row": true,
		"require_confidence": _required_confidence(args),
		"row_confidence": str(row.get("confidence", "low")),
		"value_source": str(value_payload.get("value_source", ""))
	}
	value_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
		"step": "read_value",
		"target_path": str(args.get("target_path", "")),
		"setting_path": str(args.get("setting_path", "")),
		"queries": query_values,
		"success": true
	})
	if bool(args.get("capture", false)):
		_attach_capture(value_payload, args)
	return bridge.success(value_payload, "Settings row value read")


func _focus_value(surface: String, args: Dictionary) -> Dictionary:
	var query_values: Array[String] = _search_terms(args)
	var observation: Dictionary = _observe(surface, _read_value_observation_args(args), query_values)
	if not bool(observation.get("dialog_found", false)):
		var missing_payload := observation.duplicate(true)
		missing_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "focus_value",
			"success": false,
			"reason": "surface_not_visible"
		})
		return bridge.error("Settings surface is not visible for focus_value: %s" % surface, missing_payload)
	if bool(observation.get("control_truncated", false)) and str(args.get("target_path", "")).strip_edges().is_empty():
		var truncated_payload := observation.duplicate(true)
		truncated_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "focus_value",
			"success": false,
			"reason": "control_enumeration_truncated"
		})
		return bridge.error("Settings controls were truncated; pass target_path or increase limit before focus_value.", truncated_payload)
	var all_controls: Array = observation.get("all_controls", [])
	var row_resolution: Dictionary = _resolve_row_for_value_action(all_controls, surface, args, query_values, "focus_value")
	if not bool(row_resolution.get("success", false)):
		var error_payload := observation.duplicate(true)
		error_payload["resolution"] = row_resolution
		error_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "focus_value",
			"success": false,
			"reason": str(row_resolution.get("reason", "row_not_found"))
		})
		return bridge.error(str(row_resolution.get("message", "No unique settings row matched focus_value.")), error_payload)
	var row: Dictionary = row_resolution.get("row", {})
	var value_payload: Dictionary = _read_row_value(row, all_controls)
	var value_path := str(value_payload.get("value_control_path", value_payload.get("value_source", ""))).strip_edges()
	if value_path.is_empty():
		var missing_value_payload := observation.duplicate(true)
		missing_value_payload["row"] = row
		missing_value_payload["value"] = value_payload
		missing_value_payload["resolution"] = row_resolution.get("resolution", {})
		missing_value_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "focus_value",
			"success": false,
			"reason": "value_control_not_found"
		})
		return bridge.error("No value control path was found for focus_value.", missing_value_payload)
	var focus_result: Dictionary = bridge.call_atomic("editor_ui_control", {
		"action": "focus_control",
		"target_path": value_path
	})
	if not bool(focus_result.get("success", false)):
		var focus_payload := observation.duplicate(true)
		focus_payload["row"] = row
		focus_payload["value"] = value_payload
		focus_payload["focus"] = focus_result
		focus_payload["resolution"] = row_resolution.get("resolution", {})
		focus_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "focus_value",
			"target_path": value_path,
			"success": false,
			"reason": "focus_failed"
		})
		return bridge.error(str(focus_result.get("message", focus_result.get("error", "Settings row value focus failed."))), focus_payload)
	var payload: Dictionary = focus_result.get("data", {}).duplicate(true)
	payload["surface"] = surface
	payload["dialog_found"] = bool(observation.get("dialog_found", false))
	payload["dialog_path"] = str(observation.get("dialog_path", ""))
	payload["primary_popup_path"] = str(observation.get("primary_popup_path", ""))
	payload["row"] = row
	payload["focused_value"] = {
		"path": value_path,
		"editor_type": str(value_payload.get("value_editor_type", "unknown")),
		"confidence": str(value_payload.get("confidence", row.get("confidence", "low")))
	}
	payload["value_control"] = value_payload.get("value_control", {})
	payload["value_control_path"] = value_path
	payload["value_editor_type"] = str(value_payload.get("value_editor_type", "unknown"))
	payload["value_text"] = str(value_payload.get("value_text", ""))
	payload["resolution"] = row_resolution.get("resolution", {})
	payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
		"step": "focus_value",
		"target_path": value_path,
		"setting_path": str(args.get("setting_path", "")),
		"queries": query_values,
		"success": true
	})
	if bool(args.get("capture", false)):
		_attach_capture(payload, args)
	return bridge.success(payload, "Settings row value focused")


func _capture(surface: String, args: Dictionary) -> Dictionary:
	var observation: Dictionary = _observe(surface, args, _search_terms(args))
	_attach_capture(observation, args)
	return bridge.success(observation, "Settings surface captured")


func _close(surface: String, args: Dictionary) -> Dictionary:
	var observation: Dictionary = _observe(surface, args, [])
	var target_path := str(args.get("target_path", "")).strip_edges()
	if target_path.is_empty():
		target_path = str(observation.get("primary_popup_path", "")).strip_edges()
	if target_path.is_empty():
		return bridge.error("No closable popup found for settings surface: %s" % surface, observation)
	var close_result: Dictionary = bridge.call_atomic("editor_popup", {
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
	var current: Dictionary = _observe(surface, args, [])
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
			var select_result: Dictionary = bridge.call_atomic("editor_ui_control", {
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
				var wait_result: Dictionary = await _wait_for_surface(surface, args)
				attempts.append({
					"step": "wait_for_ui",
					"success": bool(wait_result.get("success", false)),
					"message": str(wait_result.get("message", wait_result.get("error", "")))
				})
				if bool(wait_result.get("success", false)):
					var observation: Dictionary = _observe(surface, args, _search_terms(args))
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
	var observation_limit := _observation_limit(args)
	var controls_result: Dictionary = bridge.call_atomic("editor_ui_control", {
		"action": "list_visible",
		"include_hidden": bool(args.get("include_hidden", false)),
		"limit": observation_limit,
		"max_depth": int(args.get("max_depth", 10))
	})
	var workflow: Array[Dictionary] = [{
		"step": "list_visible",
		"success": bool(controls_result.get("success", false))
	}]
	var control_rows: Array = []
	if bool(controls_result.get("success", false)):
		control_rows = controls_result.get("data", {}).get("controls", [])
	var popup_result: Dictionary = bridge.call_atomic("editor_popup", {"action": "list_visible"})
	workflow.append({
		"step": "list_popups",
		"success": bool(popup_result.get("success", false))
	})
	var popup_rows: Array = []
	if bool(popup_result.get("success", false)):
		popup_rows = popup_result.get("data", {}).get("popups", [])
	var surface_matches: Array[Dictionary] = _matching_rows(control_rows, spec.get("match_queries", []))
	var popup_matches: Array[Dictionary] = _matching_rows(popup_rows, spec.get("match_queries", []))
	var surface_roots := _surface_root_paths(surface_matches, popup_matches)
	var scoped_control_rows := _controls_under_roots(control_rows, surface_roots)
	var results: Array[Dictionary] = _candidate_results(scoped_control_rows, query_values, _result_limit(args), surface)
	var search_field_path: String = _first_path(_matching_rows(scoped_control_rows, spec.get("search_queries", []), ["LineEdit", "TextEdit", "SearchBox"]), "path")
	var total_control_count := int(controls_result.get("data", {}).get("count", control_rows.size()))
	var control_truncated := control_rows.size() >= observation_limit
	return {
		"surface": surface,
		"title": str(spec.get("label", surface)),
		"opened": not surface_matches.is_empty() or not popup_matches.is_empty(),
		"dialog_found": not surface_matches.is_empty() or not popup_matches.is_empty(),
		"dialog_path": _first_path(surface_matches, "path"),
		"primary_popup_path": _first_path(popup_matches, "node_path"),
		"search_field_path": search_field_path,
		"current_tab": _current_tab_hint(scoped_control_rows, spec),
		"results": results,
		"result_count": results.size(),
		"all_controls": scoped_control_rows,
		"visible_popup_count": popup_rows.size(),
		"surface_matches": surface_matches,
		"popup_matches": popup_matches,
		"observed_control_count": scoped_control_rows.size(),
		"total_control_count": total_control_count,
		"control_limit": observation_limit,
		"control_truncated": control_truncated,
		"workflow": workflow
	}


func _candidate_results(rows: Array, query_values: Array[String], limit: int, surface: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for row in rows:
		if not (row is Dictionary):
			continue
		var dict := row as Dictionary
		if not _is_settings_search_result_candidate(dict):
			continue
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
			"value_text_hint": _value_text_hint(dict),
			"row_model": _build_row_model(dict, surface, "")
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
	var observation: Dictionary = _observe(surface, args, [])
	var search_field_path := str(observation.get("search_field_path", "")).strip_edges()
	if search_field_path.is_empty():
		return bridge.error("No search field found for settings surface: %s" % surface, observation)
	var set_result: Dictionary = bridge.call_atomic("editor_ui_control", {
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
	var normalized_queries: Array[String] = _normalize_queries(queries)
	var normalized_classes: Array[String] = _normalize_queries(class_filters)
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
	var control_class := str(row.get("class", "")).to_lower()
	for class_filter in class_filters:
		if control_class.contains(class_filter.to_lower()):
			return true
	return false


func _haystack_matches(row: Dictionary, queries: Array[String]) -> bool:
	var setting_hint := _setting_path_hint(row)
	var haystack := " ".join([
		str(row.get("path", "")),
		str(row.get("node_path", "")),
		str(row.get("name", "")),
		str(row.get("title", "")),
		str(row.get("text", "")),
		str(row.get("class", "")),
		str(row.get("tooltip", "")),
		str(row.get("parent_path", "")),
		str(row.get("setting_path", "")),
		str(row.get("path_hint", "")),
		str(row.get("value_text", "")),
		str(row.get("value", "")),
		setting_hint,
		" ".join(_setting_path_aliases(setting_hint))
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
	var capture_result: Dictionary = bridge.call_atomic("editor_screenshot", capture_args)
	payload["capture"] = capture_result.get("data", {}) if bool(capture_result.get("success", false)) else {}
	payload["capture_path"] = str(capture_result.get("data", {}).get("path", ""))
	if not bool(capture_result.get("success", false)):
		payload["capture_error"] = str(capture_result.get("message", capture_result.get("error", "")))


func _observation_limit(args: Dictionary) -> int:
	return max(1, int(args.get("limit", 100)))


func _read_value_observation_args(args: Dictionary) -> Dictionary:
	var observed_args := args.duplicate(true)
	observed_args["limit"] = max(_observation_limit(args), 500)
	return observed_args


func _result_limit(args: Dictionary) -> int:
	return max(1, int(args.get("limit", 100)))


func _surface_root_paths(surface_matches: Array, popup_matches: Array) -> Array[String]:
	var roots: Array[String] = []
	for row in surface_matches:
		if row is Dictionary:
			_append_search_term(roots, str((row as Dictionary).get("path", (row as Dictionary).get("node_path", ""))))
	for row in popup_matches:
		if row is Dictionary:
			_append_search_term(roots, str((row as Dictionary).get("node_path", (row as Dictionary).get("path", ""))))
	return roots


func _controls_under_roots(rows: Array, roots: Array[String]) -> Array:
	if roots.is_empty():
		return []
	var scoped: Array = []
	for row in rows:
		if not (row is Dictionary):
			continue
		var path := str((row as Dictionary).get("path", (row as Dictionary).get("node_path", ""))).strip_edges()
		for root in roots:
			if path == root or path.begins_with("%s/" % root):
				scoped.append(row)
				break
	return scoped


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
	var path := str(row.get("path", row.get("node_path", ""))).strip_edges()
	var tail := _settings_path_tail(path)
	if not tail.is_empty():
		tail = _strip_settings_ui_prefix(tail)
		if not tail.is_empty():
			return _path_tail_to_setting_path(tail)
	return ""


func _settings_path_tail(path: String) -> String:
	for marker in ["ProjectSettings/", "EditorSettings/", "Settings/"]:
		var index := path.find(marker)
		if index >= 0:
			return path.substr(index + marker.length()).strip_edges()
	return ""


func _setting_path_aliases(setting_path: String) -> Array[String]:
	var aliases: Array[String] = []
	var segments := setting_path.split("/", false)
	if segments.size() >= 2:
		var prefix: Array[String] = []
		for index in range(0, segments.size() - 1):
			prefix.append(str(segments[index]))
		var previous := str(segments[segments.size() - 2])
		var leaf := str(segments[segments.size() - 1])
		var nested_prefix := prefix.duplicate()
		nested_prefix.append("%s_%s" % [previous, leaf])
		aliases.append("/".join(nested_prefix))
		prefix.remove_at(prefix.size() - 1)
		prefix.append("%s_%s" % [previous, leaf])
		aliases.append("/".join(prefix))
	return aliases


func _value_text_hint(row: Dictionary) -> String:
	for key in ["value_text", "value", "text"]:
		var value := str(row.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _path_tail_to_setting_path(path_tail: String) -> String:
	var segments := path_tail.split("/", false)
	var normalized: Array[String] = []
	for segment in segments:
		var cleaned := _camel_to_snake(str(segment).strip_edges())
		if not cleaned.is_empty():
			normalized.append(cleaned)
	return "/".join(normalized)


func _strip_settings_ui_prefix(path_tail: String) -> String:
	var segments := path_tail.split("/", false)
	if segments.is_empty():
		return path_tail
	var first := str(segments[0]).strip_edges().to_lower()
	if first in ["general", "advanced"]:
		segments.remove_at(0)
	elif first == "interface":
		pass
	elif first in ["plugins", "input_map", "localization", "autoload", "shortcuts"]:
		pass
	if segments.is_empty():
		return ""
	return "/".join(segments)


func _camel_to_snake(value: String) -> String:
	var result := ""
	for index in range(value.length()):
		var character := value.substr(index, 1)
		if index > 0 and _should_insert_snake_separator(value, index):
			result += "_"
		result += character.to_lower()
	return result


func _should_insert_snake_separator(value: String, index: int) -> bool:
	var character := value.substr(index, 1)
	var previous := value.substr(index - 1, 1)
	var next := value.substr(index + 1, 1) if index + 1 < value.length() else ""
	if _is_ascii_digit(character):
		return _is_ascii_letter(previous)
	if _is_uppercase_letter(character):
		if _is_lowercase_letter(previous):
			return true
		if _is_uppercase_letter(previous) and _is_lowercase_letter(next):
			return true
	return false


func _is_ascii_digit(character: String) -> bool:
	return character >= "0" and character <= "9"


func _is_ascii_letter(character: String) -> bool:
	return character.to_lower() != character.to_upper()


func _is_uppercase_letter(character: String) -> bool:
	return _is_ascii_letter(character) and character == character.to_upper()


func _is_lowercase_letter(character: String) -> bool:
	return _is_ascii_letter(character) and character == character.to_lower()


func _settings_row_models(rows: Array, surface: String, query_values: Array[String], limit: int) -> Array[Dictionary]:
	var models: Array[Dictionary] = []
	for row in rows:
		if not (row is Dictionary):
			continue
		var dict := row as Dictionary
		if not _is_settings_row_candidate(dict):
			continue
		if not query_values.is_empty() and not _haystack_matches(dict, query_values):
			continue
		models.append(_build_row_model(dict, surface, ""))
		if models.size() >= limit:
			break
	return models


func _resolve_row_for_value_read(rows: Array, surface: String, args: Dictionary, query_values: Array[String]) -> Dictionary:
	return _resolve_row_for_value_action(rows, surface, args, query_values, "read_value")


func _resolve_row_for_value_action(rows: Array, surface: String, args: Dictionary, query_values: Array[String], action_name: String) -> Dictionary:
	var target_path := str(args.get("target_path", "")).strip_edges()
	var required := _required_confidence(args)
	var candidates: Array[Dictionary] = []
	for model in _settings_row_models(rows, surface, query_values, max(1, rows.size())):
		if not target_path.is_empty() and not _row_matches_target_path(model, target_path):
			continue
		if not _confidence_meets(str(model.get("confidence", "low")), required):
			continue
		candidates.append(model)
	if candidates.is_empty():
		return {
			"success": false,
			"reason": "row_not_found",
			"message": "No settings row matched %s with the requested selector and confidence." % action_name,
			"candidate_count": 0,
			"candidates": []
		}
	if candidates.size() > 1:
		return {
			"success": false,
			"reason": "ambiguous_row",
			"message": "Multiple settings rows matched %s; pass target_path or a more specific setting_path." % action_name,
			"candidate_count": candidates.size(),
			"candidates": candidates
		}
	return {
		"success": true,
		"row": candidates[0],
		"resolution": {
			"candidate_count": 1,
			"selector": _value_action_selector_summary(args),
			"require_confidence": required
		}
	}


func _read_row_value(row: Dictionary, rows: Array) -> Dictionary:
	var value_control: Dictionary = _value_control_for_row(row, rows)
	var source_row: Dictionary = value_control if not value_control.is_empty() else row
	var editor_type := str(row.get("value_editor_type", "unknown"))
	if editor_type == "unknown":
		editor_type = _value_editor_type_hint(source_row)
	var raw_text := _value_text_hint(source_row)
	var typed_value = _typed_value_from_row(source_row, editor_type, raw_text)
	var source_path := str(source_row.get("path", source_row.get("node_path", row.get("value_control_path", "")))).strip_edges()
	return {
		"value": typed_value,
		"value_text": raw_text,
		"value_editor_type": editor_type,
		"value_source": source_path,
		"value_control": source_row.duplicate(true),
		"value_control_path": source_path,
		"confidence": str(row.get("confidence", "low"))
	}


func _value_control_for_row(row: Dictionary, rows: Array) -> Dictionary:
	var value_path := str(row.get("value_control_path", "")).strip_edges()
	if not value_path.is_empty() and value_path != str(row.get("row_control_path", "")):
		for candidate in rows:
			if candidate is Dictionary:
				var candidate_path := str((candidate as Dictionary).get("path", (candidate as Dictionary).get("node_path", ""))).strip_edges()
				if candidate_path == value_path:
					return (candidate as Dictionary).duplicate(true)
	var row_path := str(row.get("row_control_path", "")).strip_edges()
	if row_path.is_empty():
		return {}
	for candidate in rows:
		if not (candidate is Dictionary):
			continue
		var dict := candidate as Dictionary
		if str(dict.get("parent_path", "")).strip_edges() != row_path:
			continue
		var candidate_path := str(dict.get("path", dict.get("node_path", ""))).strip_edges().to_lower()
		if candidate_path.ends_with("/value") or _value_editor_type_hint(dict) != "unknown":
			return dict.duplicate(true)
	return {}


func _typed_value_from_row(row: Dictionary, editor_type: String, raw_text: String):
	match editor_type:
		"bool":
			if row.has("pressed"):
				return bool(row.get("pressed", false))
			if row.has("button_pressed"):
				return bool(row.get("button_pressed", false))
			if row.has("value"):
				var raw_value = row.get("value")
				if raw_value is bool:
					return raw_value
			return raw_text
		"number":
			var number_value = row.get("value", raw_text)
			if number_value is int or number_value is float:
				return number_value
			var number_text := str(number_value).strip_edges()
			if number_text.is_valid_float():
				return number_text.to_float()
			return raw_text
		"enum":
			return {
				"text": raw_text,
				"selected": row.get("selected", row.get("selected_index", null))
			}
		_:
			return raw_text


func _row_matches_target_path(row: Dictionary, target_path: String) -> bool:
	for key in ["row_control_path", "label_control_path", "value_control_path"]:
		if str(row.get(key, "")).strip_edges() == target_path:
			return true
	var row_path := str(row.get("row_control_path", "")).strip_edges()
	if not row_path.is_empty() and target_path.begins_with("%s/" % row_path):
		return true
	return false


func _required_confidence(args: Dictionary) -> String:
	var required := str(args.get("require_confidence", "medium")).strip_edges().to_lower()
	if required in ["low", "medium", "high"]:
		return required
	return "medium"


func _confidence_meets(actual: String, required: String) -> bool:
	var ranks := {"low": 0, "medium": 1, "high": 2}
	return int(ranks.get(actual, 0)) >= int(ranks.get(required, 1))


func _read_value_selector_summary(args: Dictionary) -> Dictionary:
	return _value_action_selector_summary(args)


func _value_action_selector_summary(args: Dictionary) -> Dictionary:
	return {
		"target_path": str(args.get("target_path", "")),
		"setting_path": str(args.get("setting_path", "")),
		"query": str(args.get("query", "")),
		"tab": str(args.get("tab", ""))
	}


func _is_settings_row_candidate(row: Dictionary) -> bool:
	var path := str(row.get("path", row.get("node_path", ""))).strip_edges()
	var text := _label_text_hint(row)
	if path.is_empty() and text.is_empty():
		return false
	var lower_path := path.to_lower()
	var control_class := str(row.get("class", "")).strip_edges()
	if lower_path.ends_with("/filter") or lower_path.ends_with("/value"):
		return false
	if control_class in ["AcceptDialog", "Window", "PopupPanel"]:
		return false
	if bool(row.get("editable_text", false)):
		return true
	if control_class in ["HBoxContainer", "VBoxContainer", "GridContainer", "CheckBox", "CheckButton", "OptionButton", "SpinBox", "EditorSpinSlider", "LineEdit", "TextEdit", "CodeEdit", "ColorPickerButton"]:
		return true
	if path.contains("/") and (path.contains("Settings") or path.contains("General") or path.contains("Interface")):
		return true
	return false


func _is_settings_search_result_candidate(row: Dictionary) -> bool:
	if not _is_settings_row_candidate(row):
		return false
	var control_class := str(row.get("class", "")).strip_edges()
	if bool(row.get("editable_text", false)) or control_class in ["LineEdit", "TextEdit", "CodeEdit"]:
		return false
	var path := str(row.get("path", row.get("node_path", ""))).strip_edges()
	var lower_path := path.to_lower()
	if lower_path.contains("/filter") or lower_path.ends_with("/value"):
		return false
	return true


func _build_row_model(row: Dictionary, surface: String, row_id_override: String) -> Dictionary:
	var model: Dictionary = {
		"surface": surface,
		"row_id": row_id_override,
		"row_control_path": str(row.get("path", row.get("node_path", ""))).strip_edges(),
		"label_control_path": str(row.get("path", "")),
		"value_control_path": _value_control_path_hint(row),
		"control_class": str(row.get("class", "")),
		"label": _label_text_hint(row),
		"setting_path": _setting_path_hint(row),
		"category_path": _category_path_hint(row),
		"section": _section_hint(row),
		"value_text": _value_text_hint(row),
		"value_editor_type": _value_editor_type_hint(row),
		"visible": bool(row.get("visible", true)),
		"enabled": not bool(row.get("disabled", false)) and bool(row.get("enabled", true)),
		"editable_text": bool(row.get("editable_text", false)),
		"confidence": "low",
		"evidence": _row_model_evidence(row)
	}
	if str(model.get("row_id", "")).is_empty():
		model["row_id"] = _row_model_id(model)
	model["confidence"] = _row_model_confidence(model)
	return model


func _label_text_hint(row: Dictionary) -> String:
	for key in ["label_text", "text", "title", "name"]:
		var value := str(row.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _value_editor_type_hint(row: Dictionary) -> String:
	var control_class := str(row.get("class", "")).strip_edges()
	if bool(row.get("editable_text", false)):
		return "text"
	if control_class in ["CheckBox", "CheckButton"]:
		return "bool"
	if control_class in ["OptionButton"]:
		return "enum"
	if control_class in ["SpinBox", "EditorSpinSlider", "HSlider", "VSlider"]:
		return "number"
	if control_class in ["ColorPickerButton", "ColorPicker"]:
		return "color"
	if control_class in ["LineEdit", "TextEdit", "CodeEdit"]:
		return "text"
	if not str(row.get("value_text", row.get("value", ""))).strip_edges().is_empty():
		return "display_text"
	return "unknown"


func _value_control_path_hint(row: Dictionary) -> String:
	var path := str(row.get("path", row.get("node_path", ""))).strip_edges()
	if _value_editor_type_hint(row) != "unknown":
		return path
	return ""


func _category_path_hint(row: Dictionary) -> String:
	var parent_path := str(row.get("parent_path", "")).strip_edges()
	if not parent_path.is_empty():
		return parent_path
	return _section_hint(row)


func _row_model_evidence(row: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key in ["path", "parent_path", "node_path", "class", "text", "title", "name", "editable_text", "actionable", "rect", "child_count"]:
		if row.has(key):
			keys.append(key)
	return keys


func _row_model_id(model: Dictionary) -> String:
	var setting_path := str(model.get("setting_path", "")).strip_edges()
	if not setting_path.is_empty():
		return setting_path
	var row_path := str(model.get("row_control_path", "")).strip_edges()
	if not row_path.is_empty():
		return row_path
	return str(model.get("label", "")).strip_edges()


func _row_model_confidence(model: Dictionary) -> String:
	if not str(model.get("setting_path", "")).is_empty() and str(model.get("value_editor_type", "unknown")) != "unknown":
		return "high"
	if not str(model.get("label", "")).is_empty() and not str(model.get("row_control_path", "")).is_empty():
		return "medium"
	return "low"


func _row_model_quality(rows: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {"high": 0, "medium": 0, "low": 0}
	for row in rows:
		var confidence := str(row.get("confidence", "low"))
		if not counts.has(confidence):
			confidence = "low"
		counts[confidence] = int(counts[confidence]) + 1
	return {
		"row_count": rows.size(),
		"confidence_counts": counts
	}
