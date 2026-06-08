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
			"description": "SETTINGS DIALOG: High-level settings-like editor dialog workflow entry. Use it to open Project Settings or Editor Settings, wait until the target dialog is visible, summarize search fields and candidate setting rows, list and activate settings tabs, list and focus visible category tree items, list conservative row models, resolve unique visible rows, read, focus, set, or verify current visible row values, focus a returned result, run a trusted locate/read/set/verify/capture task, capture the visible settings surface with popup/window bounds preferred over full-editor screenshots, and close the surface. This tool orchestrates editor UI controls and popups; value writes are limited to uniquely matched visible rows and verified after the UI action.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["open", "status", "search", "list_tabs", "activate_tab", "list_categories", "focus_category", "list_rows", "resolve_row", "read_value", "focus_value", "set_value", "verify_value", "focus_result", "run_task", "capture", "close"],
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
						"description": "Optional setting path or path fragment. search writes this text into the settings filter; list_rows/read_value/focus_value/set_value/verify_value only filter currently observed visible rows."
					},
					"tab": {
						"type": "string",
						"description": "Optional tab title or category hint. open/activate_tab use it as the requested tab title when tab_index is not provided; search/list_rows/read_value/focus_value/set_value/verify_value use it as a query term."
					},
					"tab_index": {
						"type": "integer",
						"description": "Optional tab index for activate_tab"
					},
					"category": {
						"type": "string",
						"description": "Category text or category path for list_categories/focus_category"
					},
					"category_path": {
						"type": "string",
						"description": "Category path returned by list_categories for focus_category"
					},
					"category_index": {
						"type": "integer",
						"description": "Category item index returned by list_categories for focus_category"
					},
					"target_path": {
						"type": "string",
						"description": "Control path returned by status/search/list_rows for focus_result, a row/value control path used by resolve_row/read_value/focus_value/set_value/verify_value, or a tree/category control path used by focus_category"
					},
					"value": {
						"description": "New value for set_value. Text and number rows accept string/number values; bool rows require a boolean value."
					},
					"expected_value": {
						"description": "Expected value for verify_value. Text and number rows accept string/number values, bool rows require a boolean value, and enum rows accept a string text or dictionary with text/selected."
					},
					"include_raw_controls": {
						"type": "boolean",
						"description": "Include raw observed control rows in list_rows for diagnostics (default false)"
					},
					"require_confidence": {
						"type": "string",
						"enum": ["low", "medium", "high"],
						"description": "Minimum row model confidence accepted by read_value/focus_value/set_value/verify_value (default medium)"
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
						"description": "Capture settings surface evidence after open/search/focus when supported, preferring visible popup/window bounds before broader editor screenshots"
					},
					"capture_policy": {
						"type": "string",
						"enum": ["none", "final", "on_failure", "always"],
						"description": "Capture policy for run_task: none disables evidence capture, final attempts capture on successful completion, on_failure attempts capture only for failed tasks, and always attempts capture for both success and failure. Use require_capture=true when missing capture evidence should fail the task."
					},
					"require_capture": {
						"type": "boolean",
						"description": "When true, run_task fails if final evidence capture cannot use any backend"
					},
					"path": {
						"type": "string",
						"description": "Optional output path for the settings surface capture"
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
		"list_tabs":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _list_tabs(surface, args)
		"activate_tab":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _activate_tab(surface, args)
		"list_categories":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _list_categories(surface, args)
		"focus_category":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _focus_category(surface, args)
		"list_rows":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _list_rows(surface, args)
		"resolve_row":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _resolve_row(surface, args)
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
		"set_value":
			return bridge.error("set_value requires asynchronous execution")
		"run_task":
			return bridge.error("run_task requires asynchronous execution")
		"verify_value":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return _verify_value(surface, args)
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
		"set_value":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return await _set_value(surface, args)
		"run_task":
			var surface := _resolve_surface(args)
			if surface.is_empty():
				return bridge.error("surface is required")
			return await _run_task(surface, args)
		_:
			return execute(tool_name, args)


func _resolve_surface(args: Dictionary) -> String:
	var surface := str(args.get("surface", "project_settings")).strip_edges()
	if SURFACES.has(surface):
		return surface
	return ""


func _status(surface: String, args: Dictionary) -> Dictionary:
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), [])
	return bridge.success(observation, "Settings surface status observed")


func _search(surface: String, args: Dictionary) -> Dictionary:
	var query_values: Array[String] = _search_terms(args)
	var search_text := _primary_search_text(query_values)
	var search_write: Dictionary = {}
	if not search_text.is_empty():
		search_write = await _write_search_field(surface, args, search_text)
		if not bool(search_write.get("success", false)):
			return search_write
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), query_values)
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
		var observation: Dictionary = _observe(surface, _deep_observation_args(args), query_values)
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
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), query_values)
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


func _list_tabs(surface: String, args: Dictionary) -> Dictionary:
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), [])
	var tabs_payload: Dictionary = _settings_tabs_payload(surface, observation)
	tabs_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
		"step": "list_tabs",
		"tab_count": int(tabs_payload.get("tab_count", 0)),
		"success": true
	})
	if bool(args.get("include_raw_controls", false)):
		tabs_payload["raw_controls"] = observation.get("all_controls", [])
	if bool(args.get("capture", false)):
		_attach_capture(tabs_payload, args)
	return bridge.success(tabs_payload, "Settings tabs listed")


func _activate_tab(surface: String, args: Dictionary) -> Dictionary:
	var requested_title := str(args.get("tab", "")).strip_edges()
	var requested_index := int(args.get("tab_index", -1))
	if requested_title.is_empty() and requested_index < 0:
		return bridge.error("tab or tab_index is required for activate_tab")
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), [])
	if not bool(observation.get("dialog_found", false)):
		return bridge.error("Settings surface is not visible for activate_tab: %s" % surface, observation)
	var tabs_payload: Dictionary = _settings_tabs_payload(surface, observation)
	var tab_container_path := str(tabs_payload.get("tab_container_path", "")).strip_edges()
	if tab_container_path.is_empty():
		return bridge.error("No tab container found for settings surface: %s" % surface, tabs_payload)
	var tab_resolution := _resolve_settings_tab(tabs_payload.get("tabs", []), requested_title, requested_index)
	if not bool(tab_resolution.get("success", false)):
		var error_payload := tabs_payload.duplicate(true)
		error_payload["resolution"] = tab_resolution
		error_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "activate_tab",
			"tab": requested_title,
			"tab_index": requested_index,
			"success": false,
			"reason": str(tab_resolution.get("reason", "tab_not_found"))
		})
		return bridge.error(str(tab_resolution.get("message", "No settings tab matched activate_tab.")), error_payload)
	var selected_tab: Dictionary = tab_resolution.get("tab", {})
	var activate_result: Dictionary = bridge.call_atomic("editor_ui_control", {
		"action": "activate_ui",
		"target_path": tab_container_path,
		"tab_title": str(selected_tab.get("title", "")),
		"tab_index": int(selected_tab.get("index", -1)),
		"path": str(args.get("path", "")).strip_edges()
	})
	if not bool(activate_result.get("success", false)):
		return activate_result
	var payload: Dictionary = activate_result.get("data", {}).duplicate(true)
	payload["surface"] = surface
	payload["tab_container_path"] = tab_container_path
	payload["requested_tab"] = requested_title
	payload["requested_tab_index"] = requested_index
	payload["selected_tab"] = selected_tab
	payload["tabs"] = tabs_payload.get("tabs", [])
	payload["tab_count"] = int(tabs_payload.get("tab_count", 0))
	payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
		"step": "activate_tab",
		"tab": requested_title,
		"tab_index": requested_index,
		"target_path": tab_container_path,
		"success": true
	})
	if bool(args.get("capture", false)):
		_attach_capture(payload, args)
	return bridge.success(payload, "Settings tab activated")


func _list_categories(surface: String, args: Dictionary) -> Dictionary:
	var query_values: Array[String] = _category_terms(args)
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), [])
	var categories: Array[Dictionary] = _settings_categories(observation.get("all_controls", []), surface, query_values, _result_limit(args))
	var payload: Dictionary = {
		"surface": surface,
		"dialog_found": bool(observation.get("dialog_found", false)),
		"dialog_path": str(observation.get("dialog_path", "")),
		"primary_popup_path": str(observation.get("primary_popup_path", "")),
		"tree_control_path": _first_category_tree_path(categories),
		"categories": categories,
		"category_count": categories.size(),
		"model_quality": _category_model_quality(categories),
		"workflow": _workflow_with_step(observation.get("workflow", []), {
			"step": "list_categories",
			"queries": query_values,
			"category_count": categories.size(),
			"success": true
		})
	}
	if bool(args.get("include_raw_controls", false)):
		payload["raw_controls"] = observation.get("all_controls", [])
	if bool(args.get("capture", false)):
		_attach_capture(payload, args)
	return bridge.success(payload, "Settings categories listed")


func _focus_category(surface: String, args: Dictionary) -> Dictionary:
	var query_values: Array[String] = _category_terms(args)
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), [])
	if not bool(observation.get("dialog_found", false)):
		var missing_payload := observation.duplicate(true)
		missing_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "focus_category",
			"success": false,
			"reason": "surface_not_visible"
		})
		return bridge.error("Settings surface is not visible for focus_category: %s" % surface, missing_payload)
	var categories: Array[Dictionary] = _settings_categories(observation.get("all_controls", []), surface, [], _category_resolution_limit(args))
	var resolution: Dictionary = _resolve_category(categories, args, query_values)
	if not bool(resolution.get("success", false)):
		var error_payload := observation.duplicate(true)
		error_payload["categories"] = categories
		error_payload["resolution"] = resolution
		error_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "focus_category",
			"success": false,
			"reason": str(resolution.get("reason", "category_not_found"))
		})
		return bridge.error(str(resolution.get("message", "No unique settings category matched focus_category.")), error_payload)
	var category: Dictionary = resolution.get("category", {})
	var focus_result: Dictionary = bridge.call_atomic("editor_ui_control", {
		"action": "select_tree_item",
		"target_path": str(category.get("tree_control_path", "")),
		"item_path": str(category.get("category_path", "")),
		"item_index": int(category.get("index", -1))
	})
	if not bool(focus_result.get("success", false)):
		return focus_result
	var payload: Dictionary = focus_result.get("data", {}).duplicate(true)
	payload["surface"] = surface
	payload["focused_category"] = category
	payload["resolution"] = resolution.get("resolution", {})
	payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
		"step": "focus_category",
		"category_path": str(category.get("category_path", "")),
		"success": true
	})
	if bool(args.get("capture", false)):
		_attach_capture(payload, args)
	return bridge.success(payload, "Settings category focused")


func _read_value(surface: String, args: Dictionary) -> Dictionary:
	var query_values: Array[String] = _search_terms(args)
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), query_values)
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


func _resolve_row(surface: String, args: Dictionary) -> Dictionary:
	var query_values: Array[String] = _search_terms(args)
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), query_values)
	if not bool(observation.get("dialog_found", false)):
		var missing_payload := _resolve_row_observation_payload(observation)
		missing_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "resolve_row",
			"success": false,
			"reason": "surface_not_visible"
		})
		return bridge.error("Settings surface is not visible for resolve_row: %s" % surface, missing_payload)
	if bool(observation.get("control_truncated", false)) and str(args.get("target_path", "")).strip_edges().is_empty():
		var truncated_payload := _resolve_row_observation_payload(observation)
		truncated_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "resolve_row",
			"success": false,
			"reason": "control_enumeration_truncated"
		})
		return bridge.error("Settings controls were truncated; pass target_path or increase limit before resolve_row.", truncated_payload)
	var all_controls: Array = observation.get("all_controls", [])
	var row_resolution: Dictionary = _resolve_row_for_value_read(all_controls, surface, args, query_values, "resolve_row", true)
	if not bool(row_resolution.get("success", false)):
		var error_payload := _resolve_row_observation_payload(observation)
		error_payload["resolution"] = row_resolution
		error_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "resolve_row",
			"success": false,
			"reason": str(row_resolution.get("reason", "row_not_found"))
		})
		return bridge.error(str(row_resolution.get("message", "No unique settings row matched resolve_row.")), error_payload)
	var row: Dictionary = row_resolution.get("row", {})
	var value_control: Dictionary = _value_control_for_row(row, all_controls)
	var resolved_value_path := str(row.get("value_control_path", "")).strip_edges()
	if resolved_value_path.is_empty() and not value_control.is_empty():
		resolved_value_path = str(value_control.get("path", value_control.get("node_path", ""))).strip_edges()
	var payload: Dictionary = {
		"surface": surface,
		"dialog_found": bool(observation.get("dialog_found", false)),
		"dialog_path": str(observation.get("dialog_path", "")),
		"primary_popup_path": str(observation.get("primary_popup_path", "")),
		"row": row,
		"row_id": str(row.get("row_id", "")),
		"row_control_path": str(row.get("row_control_path", "")),
		"label_control_path": str(row.get("label_control_path", "")),
		"value_control_path": resolved_value_path,
		"value_control": _resolve_row_control_payload(value_control),
		"setting_path": str(row.get("setting_path", "")),
		"confidence": str(row.get("confidence", "low")),
		"resolution": row_resolution.get("resolution", {}),
		"verification": {
			"unique_row": true,
			"require_confidence": _required_confidence(args),
			"row_confidence": str(row.get("confidence", "low"))
		},
		"workflow": _workflow_with_step(observation.get("workflow", []), {
			"step": "resolve_row",
			"target_path": str(args.get("target_path", "")),
			"setting_path": str(args.get("setting_path", "")),
			"queries": query_values,
			"success": true
		})
	}
	if bool(args.get("capture", false)):
		_attach_capture(payload, args)
	return bridge.success(payload, "Settings row resolved")


func _focus_value(surface: String, args: Dictionary) -> Dictionary:
	var query_values: Array[String] = _search_terms(args)
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), query_values)
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
	var focus_control: Dictionary = _focusable_value_control_for_row(row, all_controls)
	var value_path := str(focus_control.get("path", focus_control.get("node_path", focus_control.get("row_control_path", "")))).strip_edges()
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
	payload["value_control"] = focus_control
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


func _set_value(surface: String, args: Dictionary) -> Dictionary:
	if not args.has("value"):
		return bridge.error("value is required for set_value")
	if bool(args.get("include_hidden", false)):
		return bridge.error("set_value refuses hidden-control writes; use visible rows only.", {
			"reason": "hidden_write_refused",
			"include_hidden": true,
			"surface": surface
		})
	if _required_confidence(args) == "low":
		return bridge.error("set_value refuses low-confidence writes.", {
			"reason": "low_confidence_write_refused",
			"require_confidence": "low",
			"surface": surface
		})
	var query_values: Array[String] = _search_terms(args)
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), query_values)
	if not bool(observation.get("dialog_found", false)):
		var missing_payload := observation.duplicate(true)
		missing_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "set_value",
			"success": false,
			"reason": "surface_not_visible"
		})
		return bridge.error("Settings surface is not visible for set_value: %s" % surface, missing_payload)
	if bool(observation.get("control_truncated", false)) and str(args.get("target_path", "")).strip_edges().is_empty():
		var truncated_payload := observation.duplicate(true)
		truncated_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "set_value",
			"success": false,
			"reason": "control_enumeration_truncated"
		})
		return bridge.error("Settings controls were truncated; pass target_path or increase limit before set_value.", truncated_payload)
	var all_controls: Array = observation.get("all_controls", [])
	var row_resolution: Dictionary = _resolve_row_for_value_action(all_controls, surface, args, query_values, "set_value")
	if not bool(row_resolution.get("success", false)):
		var error_payload := observation.duplicate(true)
		error_payload["resolution"] = row_resolution
		error_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "set_value",
			"success": false,
			"reason": str(row_resolution.get("reason", "row_not_found"))
		})
		return bridge.error(str(row_resolution.get("message", "No unique settings row matched set_value.")), error_payload)
	var row: Dictionary = row_resolution.get("row", {})
	var before_value: Dictionary = _read_row_value(row, all_controls)
	var write_result: Dictionary = _write_row_value(row, before_value, args.get("value"), all_controls)
	if not bool(write_result.get("success", false)):
		var write_payload := observation.duplicate(true)
		write_payload["row"] = row
		write_payload["before"] = before_value
		write_payload["write"] = write_result
		write_payload["resolution"] = row_resolution.get("resolution", {})
		write_payload["workflow"] = _workflow_with_step(observation.get("workflow", []), {
			"step": "set_value",
			"success": false,
			"reason": str(write_result.get("reason", "write_failed"))
		})
		return bridge.error(str(write_result.get("message", "Settings row value write failed.")), write_payload)
	await _wait_one_frame()
	var verification_observation: Dictionary = _observe(surface, _deep_observation_args(args), query_values)
	var after_value: Dictionary = {}
	var verification: Dictionary = {
		"success": false,
		"reason": "verification_unavailable"
	}
	if bool(verification_observation.get("dialog_found", false)):
		var verify_resolution: Dictionary = _resolve_row_for_value_action(verification_observation.get("all_controls", []), surface, args, query_values, "set_value")
		if bool(verify_resolution.get("success", false)):
			after_value = _read_row_value(verify_resolution.get("row", {}), verification_observation.get("all_controls", []))
			verification = _verify_written_value(after_value, write_result.get("data", {}).get("expected_value"), str(write_result.get("data", {}).get("value_editor_type", before_value.get("value_editor_type", "unknown"))))
		else:
			verification = {
				"success": false,
				"reason": str(verify_resolution.get("reason", "row_not_found")),
				"resolution": verify_resolution
			}
	var workflow := _workflow_with_step(observation.get("workflow", []), {
		"step": "set_value",
		"target_path": str(args.get("target_path", "")),
		"setting_path": str(args.get("setting_path", "")),
		"queries": query_values,
		"write_action": str(write_result.get("data", {}).get("write_action", "")),
		"success": bool(verification.get("success", false))
	})
	var payload: Dictionary = {
		"surface": surface,
		"dialog_found": bool(verification_observation.get("dialog_found", false)),
		"dialog_path": str(verification_observation.get("dialog_path", observation.get("dialog_path", ""))),
		"primary_popup_path": str(verification_observation.get("primary_popup_path", observation.get("primary_popup_path", ""))),
		"row": row,
		"resolution": row_resolution.get("resolution", {}),
		"before": before_value,
		"after": after_value,
		"write": write_result.get("data", {}),
		"verification": verification,
		"workflow": workflow
	}
	if bool(args.get("capture", false)):
		_attach_capture(payload, args)
	if bool(verification.get("success", false)):
		return bridge.success(payload, "Settings row value set")
	return bridge.error("Settings row value write could not be verified.", payload)


func _verify_value(surface: String, args: Dictionary) -> Dictionary:
	if not args.has("expected_value"):
		return bridge.error("expected_value is required for verify_value")
	var read_result: Dictionary = _read_value(surface, args)
	if not bool(read_result.get("success", false)):
		return read_result
	var payload: Dictionary = read_result.get("data", {}).duplicate(true)
	var verification: Dictionary = _verify_expected_value(payload, args.get("expected_value"))
	verification["unique_row"] = true
	verification["require_confidence"] = _required_confidence(args)
	verification["row_confidence"] = str(payload.get("row", {}).get("confidence", payload.get("confidence", "low")))
	verification["value_source"] = str(payload.get("value_source", ""))
	payload["verification"] = verification
	payload["workflow"] = _workflow_with_step(payload.get("workflow", []), {
		"step": "verify_value",
		"target_path": str(args.get("target_path", "")),
		"setting_path": str(args.get("setting_path", "")),
		"expected_value": args.get("expected_value"),
		"success": bool(verification.get("success", false))
	})
	if bool(verification.get("success", false)):
		return bridge.success(payload, "Settings row value verified")
	return bridge.error("Settings row value did not match expected_value.", payload)


func _run_task(surface: String, args: Dictionary) -> Dictionary:
	var mode := _task_mode(args)
	var payload := _task_base_payload(surface, args, mode)
	var capture_policy := _task_capture_policy(args)
	var task_args := args.duplicate(true)
	task_args["capture"] = false
	if _task_requires_capture(task_args) and capture_policy == "none":
		return _finish_task_failure(payload, task_args, "preflight", "capture_policy_refused", "run_task requires capture evidence, but capture_policy=none disables evidence capture.", "none")
	if bool(task_args.get("include_hidden", false)) and args.has("value"):
		return _finish_task_failure(payload, task_args, "preflight", "hidden_write_refused", "run_task refuses hidden-control writes.", capture_policy)
	if args.has("value") and str(task_args.get("require_confidence", "medium")).strip_edges().to_lower() == "low":
		return _finish_task_failure(payload, task_args, "preflight", "low_confidence_write_refused", "run_task refuses low-confidence writes.", capture_policy)
	if args.has("value") and args.get("value") == null:
		return _finish_task_failure(payload, task_args, "preflight", "null_value_refused", "run_task requires a non-null value for writes.", capture_policy)
	if not _has_row_selector(args):
		return _finish_task_failure(payload, task_args, "preflight", "row_selector_required", "run_task requires target_path, setting_path, or query.", capture_policy)

	var open_result: Dictionary = await _open(surface, task_args)
	_record_task_step(payload, "open", open_result)
	_merge_task_surface_context(payload, open_result.get("data", {}))
	if not bool(open_result.get("success", false)):
		return _finish_task_failure(payload, task_args, "open", _result_reason(open_result, "open_failed"), str(open_result.get("message", "Settings surface could not be opened.")), capture_policy, open_result)

	if _has_category_selector(args):
		var category_result: Dictionary = _focus_category(surface, task_args)
		_record_task_step(payload, "focus_category", category_result)
		_merge_task_surface_context(payload, category_result.get("data", {}))
		if not bool(category_result.get("success", false)):
			return _finish_task_failure(payload, task_args, "focus_category", _result_reason(category_result, "category_not_found"), str(category_result.get("message", "Settings category could not be focused.")), capture_policy, category_result)

	if _should_search_for_task(args):
		var search_result: Dictionary = await _search(surface, task_args)
		_record_task_step(payload, "search", search_result)
		_merge_task_surface_context(payload, search_result.get("data", {}))
		if not bool(search_result.get("success", false)):
			return _finish_task_failure(payload, task_args, "search", _result_reason(search_result, "search_failed"), str(search_result.get("message", "Settings search failed.")), capture_policy, search_result)

	var resolve_result: Dictionary = _resolve_row(surface, task_args)
	_record_task_step(payload, "resolve_row", resolve_result)
	_merge_task_surface_context(payload, resolve_result.get("data", {}))
	if not bool(resolve_result.get("success", false)):
		return _finish_task_failure(payload, task_args, "resolve_row", _result_reason(resolve_result, "row_not_found"), str(resolve_result.get("message", "Settings row could not be resolved.")), capture_policy, resolve_result)
	_merge_task_row(payload, resolve_result.get("data", {}))

	var read_result: Dictionary = _read_value(surface, task_args)
	_record_task_step(payload, "read_before", read_result)
	_merge_task_surface_context(payload, read_result.get("data", {}))
	if not bool(read_result.get("success", false)):
		return _finish_task_failure(payload, task_args, "read_before", _result_reason(read_result, "read_failed"), str(read_result.get("message", "Settings row value could not be read.")), capture_policy, read_result)
	payload["before"] = read_result.get("data", {})

	if args.has("value"):
		if _task_requires_capture(task_args):
			var capture_probe_result := _probe_task_capture(payload, task_args)
			_record_task_step(payload, "capture_preflight", capture_probe_result)
			if not bool(capture_probe_result.get("success", false)):
				return _finish_task_failure(payload, task_args, "capture", "capture_required", "run_task required capture evidence before writing, but no capture backend succeeded.", "none", capture_probe_result)
		var set_result: Dictionary = await _set_value(surface, task_args)
		_record_task_step(payload, "set_value", set_result)
		_merge_task_surface_context(payload, set_result.get("data", {}))
		_merge_task_write(payload, set_result.get("data", {}))
		if not bool(set_result.get("success", false)):
			return _finish_task_failure(payload, task_args, "set_value", _result_reason(set_result, "write_failed"), str(set_result.get("message", "Settings row value could not be set.")), capture_policy, set_result)

	var expected_source := ""
	var verify_args := task_args.duplicate(true)
	if args.has("expected_value"):
		expected_source = "expected_value"
	elif args.has("value"):
		expected_source = "value"
		verify_args["expected_value"] = args.get("value")
	if not expected_source.is_empty():
		var verify_result: Dictionary = _verify_value(surface, verify_args)
		_record_task_step(payload, "verify_after", verify_result)
		_merge_task_surface_context(payload, verify_result.get("data", {}))
		payload["verification"] = verify_result.get("data", {}).get("verification", {})
		if payload["verification"] is Dictionary:
			(payload["verification"] as Dictionary)["performed"] = true
			(payload["verification"] as Dictionary)["expected_source"] = expected_source
		if not bool(verify_result.get("success", false)):
			payload["write_attempted"] = args.has("value")
			payload["write_verified"] = false
			if payload.get("after", {}) is Dictionary and (payload.get("after", {}) as Dictionary).is_empty():
				payload["after"] = verify_result.get("data", {})
			return _finish_task_failure(payload, task_args, "verify_after", _result_reason(verify_result, "value_mismatch"), str(verify_result.get("message", "Settings row value did not match the expected value.")), capture_policy, verify_result)
		if not args.has("value"):
			payload["after"] = verify_result.get("data", {})
	else:
		payload["verification"] = {"performed": false, "reason": "not_requested"}

	return _finish_task_success(payload, task_args, capture_policy)


func _task_mode(args: Dictionary) -> String:
	if args.has("value") and args.has("expected_value"):
		return "set_and_verify"
	if args.has("value"):
		return "set"
	if args.has("expected_value"):
		return "verify"
	return "read"


func _task_base_payload(surface: String, args: Dictionary, mode: String) -> Dictionary:
	return {
		"surface": surface,
		"task_action": "run_task",
		"mode": mode,
		"selectors": _task_selectors(args),
		"opened": false,
		"dialog_found": false,
		"dialog_path": "",
		"primary_popup_path": "",
		"row": {},
		"row_id": "",
		"row_control_path": "",
		"value_control_path": "",
		"resolution": {},
		"before": {},
		"write": {},
		"after": {},
		"verification": {},
		"capture": {},
		"capture_surface": surface,
		"capture_path": "",
		"capture_backend": "none",
		"capture_target_path": "",
		"capture_fallback_reasons": [],
		"capture_error": "",
		"write_attempted": args.has("value"),
		"write_verified": false,
		"steps": {},
		"workflow": []
	}


func _task_selectors(args: Dictionary) -> Dictionary:
	var selectors := {}
	for key in ["tab", "tab_index", "category", "category_path", "category_index", "query", "setting_path", "target_path"]:
		if args.has(key):
			selectors[key] = args.get(key)
	return selectors


func _has_row_selector(args: Dictionary) -> bool:
	return not str(args.get("target_path", "")).strip_edges().is_empty() or not str(args.get("setting_path", "")).strip_edges().is_empty() or not str(args.get("query", "")).strip_edges().is_empty()


func _has_category_selector(args: Dictionary) -> bool:
	return not str(args.get("category", "")).strip_edges().is_empty() or not str(args.get("category_path", "")).strip_edges().is_empty() or int(args.get("category_index", -1)) >= 0


func _should_search_for_task(args: Dictionary) -> bool:
	if not str(args.get("target_path", "")).strip_edges().is_empty():
		return false
	return not str(args.get("query", "")).strip_edges().is_empty() or not str(args.get("setting_path", "")).strip_edges().is_empty()


func _task_capture_policy(args: Dictionary) -> String:
	var policy := str(args.get("capture_policy", "final")).strip_edges().to_lower()
	if ["none", "final", "on_failure", "always"].has(policy):
		return policy
	return "final"


func _task_requires_capture(args: Dictionary) -> bool:
	return bool(args.get("require_capture", false))


func _record_task_step(payload: Dictionary, step_name: String, result: Dictionary) -> void:
	var step_payload: Dictionary = {
		"success": bool(result.get("success", false)),
		"message": str(result.get("message", "")),
		"data": _task_step_summary(result.get("data", {}))
	}
	if result.has("error"):
		step_payload["error"] = result.get("error")
	if not bool(result.get("success", false)):
		step_payload["reason"] = _result_reason(result, "failed")
	payload.get("steps", {})[step_name] = step_payload
	_append_task_workflow(payload, step_name, result)


func _task_step_summary(data) -> Dictionary:
	var summary := {}
	if not (data is Dictionary):
		return summary
	var dict := data as Dictionary
	for key in [
		"surface",
		"opened",
		"already_open",
		"dialog_found",
		"dialog_path",
		"primary_popup_path",
		"selected_tab",
		"focused_category",
		"row",
		"row_id",
		"row_control_path",
		"value_control_path",
		"setting_path",
		"resolution",
		"before",
		"write",
		"after",
		"verification",
		"capture_surface",
		"capture_backend",
		"capture_target_path",
		"capture_path",
		"capture_fallback_reasons",
		"capture_error"
	]:
		if dict.has(key):
			summary[key] = dict.get(key)
	return summary


func _task_result_summary(result: Dictionary) -> Dictionary:
	var summary: Dictionary = {
		"success": bool(result.get("success", false)),
		"message": str(result.get("message", ""))
	}
	if result.has("error"):
		summary["error"] = result.get("error")
	if result.has("data"):
		summary["data"] = _task_step_summary(result.get("data", {}))
	return summary


func _append_task_workflow(payload: Dictionary, step_name: String, result: Dictionary) -> void:
	var workflow: Array = payload.get("workflow", [])
	workflow.append({
		"step": "run_task.%s" % step_name,
		"success": bool(result.get("success", false)),
		"reason": _result_reason(result, "") if not bool(result.get("success", false)) else ""
	})
	payload["workflow"] = workflow


func _merge_task_surface_context(payload: Dictionary, data) -> void:
	if not (data is Dictionary):
		return
	var dict := data as Dictionary
	for key in ["opened", "already_open", "dialog_found", "dialog_path", "primary_popup_path"]:
		if dict.has(key):
			payload[key] = dict.get(key)


func _merge_task_row(payload: Dictionary, data) -> void:
	if not (data is Dictionary):
		return
	var dict := data as Dictionary
	for key in ["row", "row_id", "row_control_path", "value_control_path", "resolution"]:
		if dict.has(key):
			payload[key] = dict.get(key)


func _merge_task_write(payload: Dictionary, data) -> void:
	if not (data is Dictionary):
		return
	var dict := data as Dictionary
	for key in ["before", "write", "after", "verification"]:
		if dict.has(key):
			payload[key] = dict.get(key)
	payload["write_attempted"] = true
	payload["write_verified"] = bool(dict.get("verification", {}).get("success", false))


func _probe_task_capture(payload: Dictionary, args: Dictionary) -> Dictionary:
	var capture_payload := {
		"surface": str(payload.get("surface", "")),
		"dialog_found": bool(payload.get("dialog_found", false)),
		"dialog_path": str(payload.get("dialog_path", "")),
		"primary_popup_path": str(payload.get("primary_popup_path", ""))
	}
	_attach_capture(capture_payload, args)
	payload["capture_preflight"] = _task_step_summary(capture_payload)
	_copy_task_capture_fields(payload, capture_payload)
	if str(capture_payload.get("capture_backend", "none")) == "none":
		return bridge.error("Settings task capture preflight failed.", capture_payload)
	return bridge.success(capture_payload, "Settings task capture evidence is available")


func _copy_task_capture_fields(payload: Dictionary, capture_payload: Dictionary) -> void:
	for key in ["capture", "capture_surface", "capture_path", "capture_backend", "capture_target_path", "capture_fallback_reasons", "capture_error"]:
		if capture_payload.has(key):
			payload[key] = capture_payload.get(key)


func _finish_task_success(payload: Dictionary, args: Dictionary, capture_policy: String) -> Dictionary:
	payload["write_verified"] = bool(payload.get("verification", {}).get("success", false)) if bool(payload.get("write_attempted", false)) else false
	if _should_capture_task(capture_policy, false):
		_attach_capture(payload, args)
	if bool(args.get("require_capture", false)) and str(payload.get("capture_backend", "none")) == "none":
		return _finish_task_failure(payload, args, "capture", "capture_required", "run_task required capture evidence, but no capture backend succeeded.", "none")
	return bridge.success(payload, "Settings task completed")


func _finish_task_failure(payload: Dictionary, args: Dictionary, failed_step: String, reason: String, message: String, capture_policy: String, failure_result: Dictionary = {}) -> Dictionary:
	payload["failed_step"] = failed_step
	payload["reason"] = reason
	if not failure_result.is_empty():
		payload["failure_result"] = _task_result_summary(failure_result)
	if failed_step != "preflight" and _should_capture_task(capture_policy, true):
		_attach_capture(payload, args)
	if _task_requires_capture(args) and failed_step != "preflight" and str(payload.get("capture_backend", "none")) == "none" and reason != "capture_required":
		payload["failed_step"] = "capture"
		payload["reason"] = "capture_required"
		message = "run_task required capture evidence, but no capture backend succeeded."
	return bridge.error(message, payload)


func _should_capture_task(capture_policy: String, failed: bool) -> bool:
	match capture_policy:
		"none":
			return false
		"on_failure":
			return failed
		"always":
			return true
		"final":
			return not failed
		_:
			return not failed


func _result_reason(result: Dictionary, default_reason: String) -> String:
	var data = result.get("data", {})
	if data is Dictionary:
		var dict := data as Dictionary
		var workflow = dict.get("workflow", [])
		if workflow is Array and not (workflow as Array).is_empty():
			var last = (workflow as Array)[(workflow as Array).size() - 1]
			if last is Dictionary and not str((last as Dictionary).get("reason", "")).strip_edges().is_empty():
				return str((last as Dictionary).get("reason", ""))
		var verification = dict.get("verification", {})
		if verification is Dictionary and not str((verification as Dictionary).get("reason", "")).strip_edges().is_empty():
			return str((verification as Dictionary).get("reason", ""))
		var resolution = dict.get("resolution", {})
		if resolution is Dictionary and not str((resolution as Dictionary).get("reason", "")).strip_edges().is_empty():
			return str((resolution as Dictionary).get("reason", ""))
		var write = dict.get("write", {})
		if write is Dictionary and not str((write as Dictionary).get("reason", "")).strip_edges().is_empty():
			return str((write as Dictionary).get("reason", ""))
	return default_reason


func _capture(surface: String, args: Dictionary) -> Dictionary:
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), _search_terms(args))
	_attach_capture(observation, args)
	return bridge.success(observation, "Settings surface captured")


func _close(surface: String, args: Dictionary) -> Dictionary:
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), [])
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
	var current: Dictionary = _observe(surface, _deep_observation_args(args), [])
	if bool(current.get("dialog_found", false)):
		current["opened"] = true
		current["already_open"] = true
		return _finish_open(surface, args, current, "Settings surface already open")
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
					var observation: Dictionary = _observe(surface, _deep_observation_args(args), _search_terms(args))
					observation["opened"] = true
					observation["workflow"] = _merge_workflow(attempts, observation.get("workflow", []))
					observation["verification"] = wait_result.get("data", {})
					return _finish_open(surface, args, observation, "Settings surface opened")
				return bridge.error("Timed out waiting for settings surface: %s" % surface, {"surface": surface, "opened": false, "workflow": attempts, "verification": wait_result.get("data", {})})
	return bridge.error("Failed to open settings surface: %s" % surface, {"surface": surface, "opened": false, "workflow": attempts})


func _finish_open(surface: String, args: Dictionary, payload: Dictionary, message: String) -> Dictionary:
	var output := payload.duplicate(true)
	if _has_tab_selector(args):
		var activation_args := args.duplicate(true)
		activation_args["capture"] = false
		activation_args.erase("path")
		var activation_result := _activate_tab(surface, activation_args)
		if not bool(activation_result.get("success", false)):
			return activation_result
		var activation_payload: Dictionary = activation_result.get("data", {})
		var selected_tab: Dictionary = activation_payload.get("selected_tab", {})
		output["tab_activation"] = activation_payload
		output["current_tab"] = str(selected_tab.get("title", output.get("current_tab", "")))
		output["current_tab_index"] = int(selected_tab.get("index", output.get("current_tab_index", -1)))
		output["workflow"] = _workflow_with_step(output.get("workflow", []), {
			"step": "open_activate_tab",
			"tab": str(args.get("tab", "")),
			"tab_index": int(args.get("tab_index", -1)),
			"success": true
		})
	if bool(args.get("capture", false)):
		_attach_capture(output, args)
	return bridge.success(output, message)


func _has_tab_selector(args: Dictionary) -> bool:
	return not str(args.get("tab", "")).strip_edges().is_empty() or int(args.get("tab_index", -1)) >= 0


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


func _category_terms(args: Dictionary) -> Array[String]:
	var values: Array[String] = []
	for key in ["category_path", "category", "query"]:
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
	var observation: Dictionary = _observe(surface, _deep_observation_args(args), [])
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


func _resolve_row_observation_payload(observation: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	for key in ["surface", "title", "opened", "dialog_found", "dialog_path", "primary_popup_path", "search_field_path", "current_tab", "result_count", "visible_popup_count", "observed_control_count", "total_control_count", "control_limit", "control_truncated"]:
		if observation.has(key):
			payload[key] = observation.get(key)
	payload["workflow"] = _merge_workflow(observation.get("workflow", []), [])
	return payload


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


func _resolve_row_haystack_matches(row: Dictionary, queries: Array[String]) -> bool:
	var setting_hint := _setting_path_hint(row)
	var parts: Array[String] = [
		str(row.get("path", "")),
		str(row.get("node_path", "")),
		str(row.get("name", "")),
		str(row.get("title", "")),
		str(row.get("class", "")),
		str(row.get("tooltip", "")),
		str(row.get("parent_path", "")),
		str(row.get("setting_path", "")),
		str(row.get("path_hint", "")),
		setting_hint,
		" ".join(_setting_path_aliases(setting_hint))
	]
	if _value_editor_type_hint(row) == "unknown":
		parts.append(str(row.get("label_text", row.get("text", ""))))
	var haystack := " ".join(parts).to_lower()
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
	var output_path := str(args.get("path", "")).strip_edges()
	var surface := str(payload.get("surface", "")).strip_edges()
	payload["capture_surface"] = surface

	var fallback_reasons: Array[String] = []
	var primary_popup_path := str(payload.get("primary_popup_path", "")).strip_edges()
	var dialog_path := str(payload.get("dialog_path", "")).strip_edges()
	if primary_popup_path.is_empty() and dialog_path.is_empty() and SURFACES.has(surface):
		_apply_capture_surface_context(payload, _observe(surface, _deep_observation_args(args), _search_terms(args)))
		primary_popup_path = str(payload.get("primary_popup_path", "")).strip_edges()
		dialog_path = str(payload.get("dialog_path", "")).strip_edges()
	if not primary_popup_path.is_empty():
		var popup_result := _call_capture_backend("editor_popup", "capture_popup", primary_popup_path, output_path)
		if _apply_capture_result(payload, popup_result, "popup", primary_popup_path, fallback_reasons):
			return
		fallback_reasons.append("popup_capture_failed")

	if not dialog_path.is_empty():
		var control_result := _call_capture_backend("editor_ui_control", "capture_control", dialog_path, output_path)
		if _apply_capture_result(payload, control_result, "control", dialog_path, fallback_reasons):
			return
		fallback_reasons.append("control_capture_failed")

	var editor_result := _call_capture_backend("editor_screenshot", "capture", "", output_path)
	if _apply_capture_result(payload, editor_result, "editor", "", fallback_reasons):
		return

	payload["capture"] = {}
	payload["capture_path"] = ""
	payload["capture_backend"] = "none"
	payload["capture_target_path"] = ""
	payload["capture_fallback_reasons"] = fallback_reasons
	payload["capture_error"] = str(editor_result.get("message", editor_result.get("error", "")))


func _apply_capture_surface_context(payload: Dictionary, observation: Dictionary) -> void:
	for key in ["dialog_found", "dialog_path", "primary_popup_path", "visible_popup_count", "observed_control_count", "total_control_count", "control_limit", "control_truncated"]:
		if observation.has(key):
			payload[key] = observation.get(key)


func _call_capture_backend(tool_name: String, action: String, target_path: String, output_path: String) -> Dictionary:
	var capture_args := {"action": action}
	if not target_path.is_empty():
		capture_args["target_path"] = target_path
	if not output_path.is_empty():
		capture_args["path"] = output_path
	return bridge.call_atomic(tool_name, capture_args)


func _apply_capture_result(payload: Dictionary, capture_result: Dictionary, backend: String, target_path: String, fallback_reasons: Array[String]) -> bool:
	if not bool(capture_result.get("success", false)):
		return false
	payload["capture"] = capture_result.get("data", {})
	payload["capture_path"] = str(capture_result.get("data", {}).get("path", ""))
	payload["capture_backend"] = backend
	payload["capture_target_path"] = target_path
	if not fallback_reasons.is_empty():
		payload["capture_fallback_reasons"] = fallback_reasons.duplicate()
	return true


func _observation_limit(args: Dictionary) -> int:
	return max(1, int(args.get("limit", 100)))


func _deep_observation_args(args: Dictionary) -> Dictionary:
	var observed_args := args.duplicate(true)
	observed_args["limit"] = max(_observation_limit(args), 500)
	return observed_args


func _category_resolution_limit(args: Dictionary) -> int:
	return max(_result_limit(args), 500)


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
	var payload := _settings_tabs_payload("", {"all_controls": rows, "dialog_path": "", "primary_popup_path": ""})
	for tab in payload.get("tabs", []):
		if tab is Dictionary and bool((tab as Dictionary).get("current", false)):
			return str((tab as Dictionary).get("title", ""))
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


func _settings_tabs_payload(surface: String, observation: Dictionary) -> Dictionary:
	var controls: Array = observation.get("all_controls", [])
	var tab_containers: Array[Dictionary] = []
	for row in controls:
		if not (row is Dictionary):
			continue
		var dict := row as Dictionary
		if not dict.has("tabs"):
			continue
		var tabs: Array = dict.get("tabs", [])
		if tabs.is_empty():
			continue
		tab_containers.append(dict.duplicate(true))
	var selected_container := _select_settings_tab_container(tab_containers)
	var tabs: Array[Dictionary] = []
	if not selected_container.is_empty():
		for tab in selected_container.get("tabs", []):
			if tab is Dictionary:
				tabs.append((tab as Dictionary).duplicate(true))
	return {
		"surface": surface,
		"dialog_found": bool(observation.get("dialog_found", false)),
		"dialog_path": str(observation.get("dialog_path", "")),
		"primary_popup_path": str(observation.get("primary_popup_path", "")),
		"tab_container_path": str(selected_container.get("path", "")),
		"tab_container_class": str(selected_container.get("class", "")),
		"current_tab": _current_tab_title(tabs),
		"current_tab_index": int(selected_container.get("current_tab_index", -1)),
		"tabs": tabs,
		"tab_count": tabs.size()
	}


func _select_settings_tab_container(tab_containers: Array[Dictionary]) -> Dictionary:
	if tab_containers.is_empty():
		return {}
	var best := tab_containers[0]
	for candidate in tab_containers:
		if int(candidate.get("tab_count", 0)) > int(best.get("tab_count", 0)):
			best = candidate
	return best.duplicate(true)


func _current_tab_title(tabs: Array[Dictionary]) -> String:
	for tab in tabs:
		if bool(tab.get("current", false)):
			return str(tab.get("title", ""))
	return ""


func _resolve_settings_tab(tabs: Array, requested_title: String, requested_index: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for tab in tabs:
		if not (tab is Dictionary):
			continue
		var dict := (tab as Dictionary).duplicate(true)
		if requested_index >= 0 and int(dict.get("index", -1)) == requested_index:
			candidates.append(dict)
			continue
		if not requested_title.is_empty() and _tab_title_matches(dict, requested_title):
			candidates.append(dict)
	if candidates.is_empty():
		return {
			"success": false,
			"reason": "tab_not_found",
			"message": "No settings tab matched the requested selector.",
			"candidate_count": 0,
			"candidates": []
		}
	if candidates.size() > 1:
		return {
			"success": false,
			"reason": "ambiguous_tab",
			"message": "Multiple settings tabs matched the requested selector.",
			"candidate_count": candidates.size(),
			"candidates": candidates
		}
	return {
		"success": true,
		"tab": candidates[0],
		"candidate_count": 1
	}


func _tab_title_matches(tab: Dictionary, requested_title: String) -> bool:
	var query := requested_title.strip_edges().to_lower()
	if query.is_empty():
		return false
	for key in ["title", "control_name"]:
		var value := str(tab.get(key, "")).strip_edges().to_lower()
		if value == query:
			return true
		if value.contains(query):
			return true
	return false


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


func _settings_row_models(rows: Array, surface: String, query_values: Array[String], limit: int, include_value_hints: bool = true) -> Array[Dictionary]:
	var models: Array[Dictionary] = []
	for row in rows:
		if not (row is Dictionary):
			continue
		var dict := row as Dictionary
		if not _is_settings_row_candidate(dict):
			continue
		var matched := _haystack_matches(dict, query_values) if include_value_hints else _resolve_row_haystack_matches(dict, query_values)
		if not query_values.is_empty() and not matched:
			continue
		models.append(_build_row_model(dict, surface, ""))
		if models.size() >= limit:
			break
	return models


func _resolve_row_for_value_read(rows: Array, surface: String, args: Dictionary, query_values: Array[String], action_name: String = "read_value", sanitize_for_resolve: bool = false) -> Dictionary:
	return _resolve_row_for_value_action(rows, surface, args, query_values, action_name, sanitize_for_resolve)


func _resolve_row_for_value_action(rows: Array, surface: String, args: Dictionary, query_values: Array[String], action_name: String, sanitize_for_resolve: bool = false) -> Dictionary:
	var target_path := str(args.get("target_path", "")).strip_edges()
	var required := _required_confidence(args)
	var candidates: Array[Dictionary] = []
	for model in _settings_row_models(rows, surface, query_values, max(1, rows.size()), not sanitize_for_resolve):
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
			"candidates": _resolve_row_models(candidates) if sanitize_for_resolve else candidates
		}
	var resolved_row := _resolve_row_model(candidates[0]) if sanitize_for_resolve else candidates[0]
	return {
		"success": true,
		"row": resolved_row,
		"resolution": {
			"candidate_count": 1,
			"selector": _value_action_selector_summary(args),
			"require_confidence": required
		}
	}


func _resolve_row_models(rows: Array[Dictionary]) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	for row in rows:
		sanitized.append(_resolve_row_model(row))
	return sanitized


func _resolve_row_model(row: Dictionary) -> Dictionary:
	var model: Dictionary = {
		"surface": str(row.get("surface", "")),
		"row_id": _resolve_row_safe_id(row),
		"row_control_path": str(row.get("row_control_path", "")),
		"label_control_path": str(row.get("label_control_path", "")),
		"value_control_path": str(row.get("value_control_path", "")),
		"control_class": str(row.get("control_class", "")),
		"setting_path": str(row.get("setting_path", "")),
		"category_path": str(row.get("category_path", "")),
		"section": str(row.get("section", "")),
		"visible": bool(row.get("visible", true)),
		"enabled": bool(row.get("enabled", true)),
		"editable_text": bool(row.get("editable_text", false)),
		"confidence": str(row.get("confidence", "low")),
		"evidence": _safe_string_array(row.get("evidence", []))
	}
	return model


func _resolve_row_control_payload(control: Dictionary) -> Dictionary:
	if control.is_empty():
		return {}
	return {
		"path": str(control.get("path", control.get("node_path", ""))),
		"node_path": str(control.get("node_path", control.get("path", ""))),
		"parent_path": str(control.get("parent_path", "")),
		"class": str(control.get("class", "")),
		"visible": bool(control.get("visible", true)),
		"enabled": not bool(control.get("disabled", false)) and bool(control.get("enabled", true)),
		"editable_text": bool(control.get("editable_text", false)),
		"actionable": bool(control.get("actionable", false)),
		"child_count": int(control.get("child_count", 0))
	}


func _resolve_row_safe_id(row: Dictionary) -> String:
	var setting_path := str(row.get("setting_path", "")).strip_edges()
	if not setting_path.is_empty():
		return setting_path
	var row_path := str(row.get("row_control_path", "")).strip_edges()
	if not row_path.is_empty():
		return row_path
	return ""


func _safe_string_array(values) -> Array[String]:
	var strings: Array[String] = []
	if not (values is Array):
		return strings
	for value in values:
		var text := str(value).strip_edges()
		if not text.is_empty():
			strings.append(text)
	return strings


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


func _write_row_value(row: Dictionary, before_value: Dictionary, requested_value, rows: Array) -> Dictionary:
	var value_control: Dictionary = _value_control_for_row(row, rows)
	if value_control.is_empty():
		return {
			"success": false,
			"reason": "value_control_not_found",
			"message": "No writable value control was found for the settings row."
		}
	var editor_type := str(before_value.get("value_editor_type", row.get("value_editor_type", "unknown")))
	if editor_type == "unknown":
		editor_type = _value_editor_type_hint(value_control)
	var value_path := str(before_value.get("value_control_path", value_control.get("path", value_control.get("node_path", "")))).strip_edges()
	if value_path.is_empty():
		return {
			"success": false,
			"reason": "value_control_not_found",
			"message": "The settings row value control does not expose a path."
		}
	match editor_type:
		"text":
			var text_value := str(requested_value)
			var set_text_result: Dictionary = bridge.call_atomic("editor_ui_control", {
				"action": "set_text",
				"target_path": value_path,
				"text": text_value
			})
			return _wrap_write_result(set_text_result, editor_type, value_path, "set_text", text_value)
		"number":
			var numeric_result := _coerce_number_value(requested_value)
			if not bool(numeric_result.get("success", false)):
				return numeric_result
			var number_value = numeric_result.get("value")
			var set_value_result: Dictionary = bridge.call_atomic("editor_ui_control", {
				"action": "set_value",
				"target_path": value_path,
				"value": number_value
			})
			return _wrap_write_result(set_value_result, editor_type, value_path, "set_value", number_value)
		"bool":
			if not (requested_value is bool):
				return {
					"success": false,
					"reason": "invalid_value_type",
					"message": "Bool settings rows require a boolean value."
				}
			var before_bool = before_value.get("value")
			if not (before_bool is bool):
				return {
					"success": false,
					"reason": "bool_state_unavailable",
					"message": "The bool settings row does not expose an explicit current pressed state."
				}
			if bool(before_bool) == bool(requested_value):
				return {
					"success": true,
					"data": {
						"value_editor_type": editor_type,
						"value_control_path": value_path,
						"write_action": "noop",
						"expected_value": requested_value,
						"already_set": true
					}
				}
			var activate_result: Dictionary = bridge.call_atomic("editor_ui_control", {
				"action": "activate_control",
				"target_path": value_path
			})
			return _wrap_write_result(activate_result, editor_type, value_path, "activate_control", requested_value)
		_:
			return {
				"success": false,
				"reason": "unsupported_value_editor_type",
				"message": "set_value does not support settings value editor type: %s" % editor_type,
				"data": {
					"value_editor_type": editor_type,
					"value_control_path": value_path
				}
			}


func _wrap_write_result(result: Dictionary, editor_type: String, value_path: String, write_action: String, expected_value) -> Dictionary:
	if bool(result.get("success", false)):
		var data: Dictionary = result.get("data", {}).duplicate(true)
		data["value_editor_type"] = editor_type
		data["value_control_path"] = value_path
		data["write_action"] = write_action
		data["expected_value"] = expected_value
		return {"success": true, "data": data}
	return {
		"success": false,
		"reason": "write_failed",
		"message": str(result.get("message", result.get("error", "Settings row value write failed."))),
		"data": result.get("data", {})
	}


func _coerce_number_value(value) -> Dictionary:
	if value is int or value is float:
		return {"success": true, "value": value}
	var text := str(value).strip_edges()
	if text.is_valid_float():
		return {"success": true, "value": text.to_float()}
	return {
		"success": false,
		"reason": "invalid_value_type",
		"message": "Number settings rows require a numeric value."
	}


func _verify_written_value(after_value: Dictionary, expected_value, editor_type: String) -> Dictionary:
	var actual_value = after_value.get("value")
	match editor_type:
		"number":
			var expected_number := _coerce_number_value(expected_value)
			if bool(expected_number.get("success", false)) and (actual_value is int or actual_value is float):
				var delta := abs(float(actual_value) - float(expected_number.get("value")))
				return {
					"success": delta <= 0.00001,
					"expected_value": expected_number.get("value"),
					"actual_value": actual_value,
					"reason": "matched" if delta <= 0.00001 else "value_mismatch"
				}
		"bool":
			if actual_value is bool and expected_value is bool:
				return {
					"success": bool(actual_value) == bool(expected_value),
					"expected_value": expected_value,
					"actual_value": actual_value,
					"reason": "matched" if bool(actual_value) == bool(expected_value) else "value_mismatch"
				}
		_:
			var expected_text := str(expected_value)
			var actual_text := str(actual_value)
			return {
				"success": actual_text == expected_text,
				"expected_value": expected_text,
				"actual_value": actual_text,
				"reason": "matched" if actual_text == expected_text else "value_mismatch"
			}
	return {
		"success": false,
		"expected_value": expected_value,
		"actual_value": actual_value,
		"reason": "value_mismatch"
	}


func _wait_one_frame() -> void:
	var main_loop = Engine.get_main_loop()
	if main_loop != null:
		await main_loop.process_frame


func _value_control_for_row(row: Dictionary, rows: Array) -> Dictionary:
	var value_path := str(row.get("value_control_path", "")).strip_edges()
	if not value_path.is_empty() and value_path != str(row.get("row_control_path", "")):
		for candidate in rows:
			if candidate is Dictionary:
				var candidate_path := str((candidate as Dictionary).get("path", (candidate as Dictionary).get("node_path", ""))).strip_edges()
				if candidate_path == value_path:
					return (candidate as Dictionary).duplicate(true)
	var row_editor_type := str(row.get("value_editor_type", "unknown"))
	if row_editor_type == "unknown":
		row_editor_type = _value_editor_type_hint(row)
	if row_editor_type in ["text", "bool", "number", "enum", "color"]:
		return row.duplicate(true)
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


func _focusable_value_control_for_row(row: Dictionary, rows: Array) -> Dictionary:
	var value_control := _value_control_for_row(row, rows)
	if value_control.is_empty():
		return {}
	var editor_type := str(value_control.get("value_editor_type", "unknown"))
	if editor_type == "unknown":
		editor_type = _value_editor_type_hint(value_control)
	if editor_type in ["text", "bool", "number", "enum", "color"]:
		return value_control
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


func _verify_expected_value(value_payload: Dictionary, expected_value) -> Dictionary:
	var editor_type := str(value_payload.get("value_editor_type", "unknown"))
	var actual_value = value_payload.get("value")
	match editor_type:
		"number":
			return _verify_number_value(actual_value, expected_value)
		"bool":
			return _verify_bool_value(actual_value, expected_value)
		"enum":
			return _verify_enum_value(actual_value, expected_value)
		_:
			return _verify_text_value(actual_value, expected_value)


func _verify_number_value(actual_value, expected_value) -> Dictionary:
	var actual_number := _coerce_number_value(actual_value)
	var expected_number := _coerce_number_value(expected_value)
	var success := bool(actual_number.get("success", false)) and bool(expected_number.get("success", false))
	if success:
		var delta := abs(float(actual_number.get("value")) - float(expected_number.get("value")))
		success = delta <= 0.00001
		return {
			"success": success,
			"reason": "matched" if success else "value_mismatch",
			"expected_value": expected_number.get("value"),
			"actual_value": actual_number.get("value"),
			"actual_type": "number"
		}
	return {
		"success": false,
		"reason": "type_mismatch",
		"expected_value": expected_value,
		"actual_value": actual_value,
		"actual_type": "number"
	}


func _verify_bool_value(actual_value, expected_value) -> Dictionary:
	if actual_value is bool and expected_value is bool:
		var success := bool(actual_value) == bool(expected_value)
		return {
			"success": success,
			"reason": "matched" if success else "value_mismatch",
			"expected_value": expected_value,
			"actual_value": actual_value,
			"actual_type": "bool"
		}
	return {
		"success": false,
		"reason": "type_mismatch",
		"expected_value": expected_value,
		"actual_value": actual_value,
		"actual_type": "bool"
	}


func _verify_enum_value(actual_value, expected_value) -> Dictionary:
	var actual_text := ""
	var actual_selected: Variant = null
	if actual_value is Dictionary:
		actual_text = str((actual_value as Dictionary).get("text", ""))
		actual_selected = (actual_value as Dictionary).get("selected", null)
	else:
		actual_text = str(actual_value)
	var expected_text := ""
	var expected_selected: Variant = null
	var expects_text := false
	var expects_selected := false
	if expected_value is Dictionary:
		var expected_dict := expected_value as Dictionary
		if expected_dict.has("text"):
			expected_text = str(expected_dict.get("text", ""))
			expects_text = true
		if expected_dict.has("selected"):
			expected_selected = expected_dict.get("selected", null)
			expects_selected = true
	else:
		expected_text = str(expected_value)
		expects_text = true
	var text_matches := (not expects_text) or actual_text == expected_text
	var selected_matches := (not expects_selected) or _values_equal_exact(actual_selected, expected_selected)
	var success := text_matches and selected_matches and (expects_text or expects_selected)
	return {
		"success": success,
		"reason": "matched" if success else "value_mismatch",
		"expected_value": expected_value,
		"actual_value": actual_value,
		"actual_type": "enum"
	}


func _verify_text_value(actual_value, expected_value) -> Dictionary:
	var actual_text := str(actual_value)
	var expected_text := str(expected_value)
	var success := actual_text == expected_text
	return {
		"success": success,
		"reason": "matched" if success else "value_mismatch",
		"expected_value": expected_text,
		"actual_value": actual_text,
		"actual_type": "text"
	}


func _values_equal_exact(left, right) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return float(left) == float(right)
	return left == right


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
	if control_class in ["HBoxContainer", "VBoxContainer", "GridContainer", "CheckBox", "CheckButton", "OptionButton", "SpinBox", "EditorSpinSlider", "Slider", "HSlider", "VSlider", "LineEdit", "TextEdit", "CodeEdit", "ColorPickerButton"]:
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


func _settings_categories(rows: Array, surface: String, query_values: Array[String], limit: int) -> Array[Dictionary]:
	var categories: Array[Dictionary] = []
	for tree_row in _settings_category_tree_rows(rows):
		var tree_path := str(tree_row.get("path", tree_row.get("node_path", ""))).strip_edges()
		if tree_path.is_empty():
			continue
		var list_result: Dictionary = bridge.call_atomic("editor_ui_control", {
			"action": "list_tree_items",
			"target_path": tree_path,
			"text_query": _primary_search_text(query_values),
			"include_hidden": false,
			"limit": limit
		})
		if not bool(list_result.get("success", false)):
			continue
		var items: Array = list_result.get("data", {}).get("items", [])
		for item in items:
			if not (item is Dictionary):
				continue
			var model := _build_category_model(item as Dictionary, tree_row, surface)
			if not query_values.is_empty() and not _category_matches(model, query_values):
				continue
			categories.append(model)
			if categories.size() >= limit:
				return categories
	return categories


func _settings_category_tree_rows(rows: Array) -> Array[Dictionary]:
	var trees: Array[Dictionary] = []
	for row in rows:
		if not (row is Dictionary):
			continue
		var dict := row as Dictionary
		if str(dict.get("class", "")).strip_edges() != "Tree":
			continue
		if not bool(dict.get("visible", true)):
			continue
		if _is_settings_category_tree_row(dict, rows):
			trees.append(dict.duplicate(true))
	return trees


func _is_settings_category_tree_row(row: Dictionary, rows: Array) -> bool:
	var hints: Array[String] = [
		str(row.get("path", row.get("node_path", ""))),
		str(row.get("name", "")),
		str(row.get("text", "")),
		str(row.get("title", "")),
		str(row.get("tooltip", "")),
		str(row.get("tooltip_text", "")),
		str(row.get("accessible_name", ""))
	]
	for hint in hints:
		var normalized := hint.strip_edges().to_lower()
		if normalized.is_empty():
			continue
		if normalized.contains("category") or normalized.contains("categories"):
			return true
	if _has_sectioned_inspector_context(row, rows):
		return true
	return false


func _has_sectioned_inspector_context(row: Dictionary, rows: Array) -> bool:
	var path := str(row.get("path", row.get("node_path", ""))).strip_edges()
	var parent_path := str(row.get("parent_path", "")).strip_edges()
	if path.is_empty():
		return false
	if _is_under_editor_inspector(path, rows):
		return false
	var sectioned_root := _nearest_sectioned_inspector_path(path, parent_path, rows)
	if sectioned_root.is_empty():
		return false
	return _sectioned_inspector_has_editor_inspector(sectioned_root, rows)


func _nearest_sectioned_inspector_path(path: String, parent_path: String, rows: Array) -> String:
	var candidate_paths: Array[String] = [path, parent_path]
	for row in rows:
		if not (row is Dictionary):
			continue
		var dict := row as Dictionary
		var row_path := str(dict.get("path", dict.get("node_path", ""))).strip_edges()
		if row_path.is_empty():
			continue
		if not (path == row_path or path.begins_with("%s/" % row_path) or parent_path == row_path or parent_path.begins_with("%s/" % row_path)):
			continue
		candidate_paths.append(row_path)
	candidate_paths.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for candidate in candidate_paths:
		if _path_or_row_mentions_sectioned_inspector(candidate, rows):
			return candidate
	return ""


func _path_or_row_mentions_sectioned_inspector(path: String, rows: Array) -> bool:
	var normalized := path.to_lower()
	if normalized.ends_with("/sectionedinspector") or normalized.ends_with("/sectioned_inspector") or normalized == "sectionedinspector" or normalized == "sectioned_inspector":
		return true
	for row in rows:
		if not (row is Dictionary):
			continue
		var dict := row as Dictionary
		var row_path := str(dict.get("path", dict.get("node_path", ""))).strip_edges()
		if row_path != path:
			continue
		var hints := " ".join([
			str(dict.get("class", "")),
			str(dict.get("name", "")),
			str(dict.get("title", "")),
			str(dict.get("text", ""))
		]).to_lower()
		if hints.contains("sectionedinspector") or hints.contains("sectioned_inspector"):
			return true
	return false


func _sectioned_inspector_has_editor_inspector(sectioned_root: String, rows: Array) -> bool:
	for row in rows:
		if not (row is Dictionary):
			continue
		var dict := row as Dictionary
		var row_path := str(dict.get("path", dict.get("node_path", ""))).strip_edges()
		if row_path.is_empty() or not (row_path == sectioned_root or row_path.begins_with("%s/" % sectioned_root)):
			continue
		var hints := " ".join([
			str(dict.get("class", "")),
			str(dict.get("name", "")),
			str(dict.get("title", "")),
			str(dict.get("text", ""))
		]).to_lower()
		if hints.contains("editorinspector") or hints.contains("editor_inspector"):
			return true
	return false


func _is_under_editor_inspector(path: String, rows: Array) -> bool:
	for row in rows:
		if not (row is Dictionary):
			continue
		var dict := row as Dictionary
		var row_path := str(dict.get("path", dict.get("node_path", ""))).strip_edges()
		if row_path.is_empty() or not path.begins_with("%s/" % row_path):
			continue
		var hints := " ".join([
			str(dict.get("class", "")),
			str(dict.get("name", "")),
			str(dict.get("title", "")),
			str(dict.get("text", ""))
		]).to_lower()
		if hints.contains("editorinspector") or hints.contains("editor_inspector"):
			return true
	return false


func _build_category_model(item: Dictionary, tree_row: Dictionary, surface: String) -> Dictionary:
	var category_path := str(item.get("item_path", item.get("text", ""))).strip_edges()
	var label := str(item.get("text", "")).strip_edges()
	var model := {
		"surface": surface,
		"category_id": category_path if not category_path.is_empty() else label,
		"label": label,
		"category_path": category_path,
		"target_path": str(tree_row.get("path", tree_row.get("node_path", ""))).strip_edges(),
		"tree_control_path": str(item.get("tree_control_path", tree_row.get("path", ""))).strip_edges(),
		"parent_path": str(tree_row.get("parent_path", "")),
		"control_class": str(tree_row.get("class", "")),
		"index": int(item.get("index", -1)),
		"depth": int(item.get("depth", 0)),
		"visible": bool(item.get("visible", true)),
		"enabled": not bool(tree_row.get("disabled", false)) and bool(tree_row.get("enabled", true)),
		"selected": bool(item.get("selected", false)),
		"collapsed": bool(item.get("collapsed", false)),
		"child_count": int(item.get("child_count", 0)),
		"source": "tree_item",
		"confidence": "low",
		"evidence": _category_model_evidence(item, tree_row)
	}
	model["confidence"] = _category_model_confidence(model)
	return model


func _category_matches(model: Dictionary, query_values: Array[String]) -> bool:
	var haystack := " ".join([
		str(model.get("label", "")),
		str(model.get("category_path", "")),
		str(model.get("target_path", "")),
		str(model.get("tree_control_path", ""))
	]).to_lower()
	for query in query_values:
		if haystack.contains(query.to_lower()):
			return true
	return false


func _resolve_category(categories: Array[Dictionary], args: Dictionary, query_values: Array[String]) -> Dictionary:
	var target_path := str(args.get("target_path", "")).strip_edges()
	var category_path := str(args.get("category_path", "")).strip_edges().to_lower()
	var category_text := str(args.get("category", "")).strip_edges().to_lower()
	var category_index := int(args.get("category_index", -1))
	var candidates: Array[Dictionary] = []
	for category in categories:
		if not target_path.is_empty() and str(category.get("target_path", "")) != target_path and str(category.get("tree_control_path", "")) != target_path:
			continue
		if category_index >= 0 and int(category.get("index", -1)) != category_index:
			continue
		if not category_path.is_empty() and str(category.get("category_path", "")).strip_edges().to_lower() != category_path:
			continue
		if not category_text.is_empty() and str(category.get("label", "")).strip_edges().to_lower() != category_text and str(category.get("category_path", "")).strip_edges().to_lower() != category_text:
			continue
		if category_path.is_empty() and category_text.is_empty() and category_index < 0 and query_values.is_empty():
			continue
		if category_path.is_empty() and category_text.is_empty() and category_index < 0 and not query_values.is_empty() and not _category_matches(category, query_values):
			continue
		candidates.append(category)
	if candidates.is_empty():
		return {
			"success": false,
			"reason": "category_not_found",
			"message": "No settings category matched focus_category with the requested selector.",
			"candidate_count": 0,
			"selector": _category_selector_summary(args)
		}
	if candidates.size() > 1:
		return {
			"success": false,
			"reason": "ambiguous_category",
			"message": "Multiple settings categories matched focus_category; pass category_path or category_index.",
			"candidate_count": candidates.size(),
			"candidates": candidates,
			"selector": _category_selector_summary(args)
		}
	return {
		"success": true,
		"category": candidates[0],
		"resolution": {
			"candidate_count": 1,
			"selector": _category_selector_summary(args)
		}
	}


func _category_selector_summary(args: Dictionary) -> Dictionary:
	return {
		"target_path": str(args.get("target_path", "")),
		"category_path": str(args.get("category_path", "")),
		"category": str(args.get("category", "")),
		"category_index": int(args.get("category_index", -1)),
		"query": str(args.get("query", ""))
	}


func _first_category_tree_path(categories: Array[Dictionary]) -> String:
	for category in categories:
		var path := str(category.get("tree_control_path", "")).strip_edges()
		if not path.is_empty():
			return path
	return ""


func _category_model_evidence(item: Dictionary, tree_row: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key in ["index", "text", "item_path", "depth", "selected", "collapsed", "child_count"]:
		if item.has(key):
			keys.append("item.%s" % key)
	for key in ["path", "parent_path", "class", "visible", "rect"]:
		if tree_row.has(key):
			keys.append("tree.%s" % key)
	return keys


func _category_model_confidence(model: Dictionary) -> String:
	if not str(model.get("category_path", "")).is_empty() and int(model.get("index", -1)) >= 0:
		return "high"
	if not str(model.get("label", "")).is_empty():
		return "medium"
	return "low"


func _category_model_quality(categories: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {"high": 0, "medium": 0, "low": 0}
	for category in categories:
		var confidence := str(category.get("confidence", "low"))
		if not counts.has(confidence):
			confidence = "low"
		counts[confidence] = int(counts[confidence]) + 1
	return {
		"category_count": categories.size(),
		"confidence_counts": counts
	}


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
	if control_class in ["SpinBox", "EditorSpinSlider", "Slider", "HSlider", "VSlider"]:
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
