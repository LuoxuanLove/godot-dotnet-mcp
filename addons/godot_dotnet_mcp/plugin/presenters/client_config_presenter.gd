extends RefCounted


func build_desktop_client_models(
	settings: Dictionary,
	_current_cli_scope: String,
	runtime_process: Dictionary,
	client_install_statuses: Dictionary,
	localization,
	config_service
) -> Array[Dictionary]:
	var transport = _build_client_transport_model(settings, runtime_process)
	return [
		_build_client_ui_model("claude_desktop", {
			"id": "claude_desktop",
			"name_key": "config_client_claude_desktop",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("claude_desktop", transport), transport, localization),
			"path": config_service.get_claude_config_path(),
			"content": _build_desktop_client_config_content(transport, config_service),
			"writeable": true
		}, client_install_statuses, localization),
		_build_client_ui_model("cursor", {
			"id": "cursor",
			"name_key": "config_client_cursor",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("cursor", transport), transport, localization),
			"path": config_service.get_cursor_config_path(),
			"content": _build_desktop_client_config_content(transport, config_service),
			"writeable": true
		}, client_install_statuses, localization),
		_build_client_ui_model("trae", {
			"id": "trae",
			"name_key": "config_client_trae",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("trae", transport), transport, localization),
			"path": config_service.get_trae_config_path(),
			"content": _build_desktop_client_config_content(transport, config_service),
			"writeable": true
		}, client_install_statuses, localization),
		_build_client_ui_model("codex_desktop", {
			"id": "codex_desktop",
			"name_key": "config_client_codex_desktop",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("codex_desktop", transport), transport, localization),
			"path": "",
			"content": "",
			"writeable": false
		}, client_install_statuses, localization),
		_build_client_ui_model("opencode_desktop", {
			"id": "opencode_desktop",
			"name_key": "config_client_opencode_desktop",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("opencode_desktop", transport), transport, localization),
			"path": config_service.get_opencode_config_path(),
			"content": "",
			"writeable": false
		}, client_install_statuses, localization),
		_build_client_ui_model("windsurf", {
			"id": "windsurf",
			"name_key": "config_client_windsurf",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("windsurf", transport), transport, localization),
			"path": config_service.get_windsurf_config_path(),
			"content": _build_desktop_client_config_content(transport, config_service),
			"writeable": true
		}, client_install_statuses, localization),
		_build_client_ui_model("cline", {
			"id": "cline",
			"name_key": "config_client_cline",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("cline", transport), transport, localization),
			"path": config_service.get_cline_config_path(),
			"content": _build_desktop_client_config_content(transport, config_service),
			"writeable": true
		}, client_install_statuses, localization),
		_build_client_ui_model("roo_code", {
			"id": "roo_code",
			"name_key": "config_client_roo_code",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("roo_code", transport), transport, localization),
			"path": config_service.get_roo_config_path(),
			"content": _build_desktop_client_config_content(transport, config_service),
			"writeable": true
		}, client_install_statuses, localization),
		_build_client_ui_model("cherry_studio", {
			"id": "cherry_studio",
			"name_key": "config_client_cherry_studio",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("cherry_studio", transport), transport, localization),
			"path": config_service.get_cherry_studio_config_hint_path(),
			"content": _build_desktop_client_config_content(transport, config_service),
			"writeable": false
		}, client_install_statuses, localization)
	]


func build_cli_client_models(
	settings: Dictionary,
	current_cli_scope: String,
	runtime_process: Dictionary,
	client_install_statuses: Dictionary,
	localization,
	config_service
) -> Array[Dictionary]:
	var transport = _build_client_transport_model(settings, runtime_process)
	return [
		_build_client_ui_model("claude_code", {
			"id": "claude_code",
			"name_key": "config_client_claude_code",
			"cli_scope": current_cli_scope,
			"summary_text": _build_client_summary_text(_get_cli_summary_key("claude_code", transport), transport, localization),
			"content": _build_claude_code_cli_content(current_cli_scope, transport, config_service),
			"primary_action_label_key": "config_client_action_add",
			"launch_action_label_key": "config_client_action_open_terminal"
		}, client_install_statuses, localization),
		_build_client_ui_model("codex", {
			"id": "codex",
			"name_key": "config_client_codex",
			"cli_scope": current_cli_scope,
			"summary_text": _build_client_summary_text(_get_cli_summary_key("codex", transport), transport, localization),
			"content": _build_codex_cli_content(transport, config_service),
			"primary_action_label_key": "config_client_action_add",
			"launch_action_label_key": "config_client_action_open_terminal"
		}, client_install_statuses, localization),
		_build_client_ui_model("gemini", {
			"id": "gemini",
			"name_key": "config_client_gemini",
			"cli_scope": current_cli_scope,
			"summary_text": _build_client_summary_text(_get_cli_summary_key("gemini", transport), transport, localization),
			"path": config_service.get_gemini_config_path(current_cli_scope),
			"content": _build_gemini_cli_content(current_cli_scope, transport, config_service),
			"primary_action_label_key": "config_client_action_add",
			"launch_action_label_key": "config_client_action_open_terminal"
		}, client_install_statuses, localization),
		_build_client_ui_model("opencode", {
			"id": "opencode",
			"name_key": "config_client_opencode",
			"summary_text": _build_client_summary_text(_get_cli_summary_key("opencode", transport), transport, localization),
			"path": config_service.get_opencode_config_path(),
			"content": _build_opencode_cli_content(transport, config_service),
			"writeable": true,
			"launch_action_label_key": "config_client_action_open_terminal"
		}, client_install_statuses, localization),
		_build_client_ui_model("qwen", {
			"id": "qwen",
			"name_key": "config_client_qwen",
			"cli_scope": current_cli_scope,
			"summary_text": _build_client_summary_text(_get_cli_summary_key("qwen", transport), transport, localization),
			"path": config_service.get_qwen_config_path(current_cli_scope),
			"content": _build_qwen_cli_content(current_cli_scope, transport, config_service),
			"primary_action_label_key": "config_client_action_add",
			"launch_action_label_key": "config_client_action_open_terminal"
		}, client_install_statuses, localization)
	]


func build_client_transport_model(settings: Dictionary, runtime_process: Dictionary) -> Dictionary:
	return _build_client_transport_model(settings, runtime_process)


func get_client_install_message_text(client_id: String, status: String, localization) -> String:
	return _get_client_install_message_text(client_id, status, localization)


func build_config_connection_mode(settings: Dictionary, runtime_process: Dictionary, localization) -> Dictionary:
	var transport = _build_client_transport_model(settings, runtime_process)
	var description = localization.get_text(str(transport.get("mode_label_key", "")))
	if str(transport.get("mode", "")) == "stdio":
		var command = str(runtime_process.get("client_command", "")).strip_edges()
		return {
			"mode": "stdio",
			"label": localization.get_text("config_mode_local_stdio_title"),
			"description": "%s\n%s" % [localization.get_text("config_mode_local_stdio_desc"), command],
			"validate_enabled": not command.is_empty()
		}
	var endpoint = "http://%s:%d/mcp" % [str(transport.get("host", "127.0.0.1")), int(transport.get("port", 3000))]
	return {
		"mode": "http",
		"label": description,
		"description": "%s\n%s" % [localization.get_text("config_mode_http_fallback_desc"), endpoint],
		"validate_enabled": true
	}


func build_config_platform_models(desktop_clients: Array[Dictionary], cli_clients: Array[Dictionary]) -> Array[Dictionary]:
	var platforms: Array[Dictionary] = []
	for client in desktop_clients:
		platforms.append({
			"id": str(client.get("id", "")),
			"name_key": str(client.get("name_key", "")),
			"group": "desktop",
			"display_name_key": "config_platform_desktop_prefix"
		})
	for client in cli_clients:
		platforms.append({
			"id": str(client.get("id", "")),
			"name_key": str(client.get("name_key", "")),
			"group": "cli",
			"display_name_key": "config_platform_cli_prefix"
		})
	return platforms


func resolve_current_config_platform(current_platform: String, platforms: Array[Dictionary]) -> String:
	if platforms.is_empty():
		return ""

	for platform in platforms:
		var platform_id = str(platform.get("id", ""))
		if platform_id == current_platform:
			return platform_id

	return str(platforms[0].get("id", ""))


func _build_client_transport_model(settings: Dictionary, runtime_process: Dictionary) -> Dictionary:
	var launch_available = bool(runtime_process.get("client_launch_available", false))
	var executable_path = str(runtime_process.get("client_executable_path", "")).strip_edges()
	var arguments = runtime_process.get("client_arguments", [])
	var argument_list: Array = []
	if arguments is Array:
		argument_list.assign(arguments)
	elif arguments is PackedStringArray:
		argument_list.assign(Array(arguments))

	if launch_available and not executable_path.is_empty():
		return {
			"mode": "stdio",
			"command": executable_path,
			"args": argument_list,
			"mode_label_key": "config_transport_local_stdio"
		}

	return {
		"mode": "http",
		"host": str(settings.get("host", "127.0.0.1")),
		"port": int(settings.get("port", 3000)),
		"mode_label_key": "config_transport_http_fallback"
	}


func _build_client_summary_text(base_key: String, transport: Dictionary, localization) -> String:
	var base_text = localization.get_text(base_key)
	var transport_text = localization.get_text(str(transport.get("mode_label_key", "")))
	if transport_text.is_empty() or transport_text == str(transport.get("mode_label_key", "")):
		return base_text
	return "%s\n%s" % [base_text, transport_text]


func _build_desktop_client_config_content(transport: Dictionary, config_service) -> String:
	if str(transport.get("mode", "")) == "stdio":
		return config_service.get_command_config(
			str(transport.get("command", "")),
			Array(transport.get("args", []))
		)
	return config_service.get_url_config(str(transport.get("host", "127.0.0.1")), int(transport.get("port", 3000)))


func _build_gemini_client_config_content(transport: Dictionary, config_service) -> String:
	if str(transport.get("mode", "")) == "stdio":
		return config_service.get_command_config(
			str(transport.get("command", "")),
			Array(transport.get("args", []))
		)
	return config_service.get_http_url_config(str(transport.get("host", "127.0.0.1")), int(transport.get("port", 3000)))


func _build_gemini_cli_content(current_cli_scope: String, transport: Dictionary, config_service) -> String:
	if str(transport.get("mode", "")) == "stdio":
		return config_service.get_command_config(
			str(transport.get("command", "")),
			Array(transport.get("args", []))
		)
	return config_service.get_gemini_command(
		current_cli_scope,
		str(transport.get("host", "127.0.0.1")),
		int(transport.get("port", 3000))
	)


func _build_claude_code_cli_content(current_cli_scope: String, transport: Dictionary, config_service) -> String:
	if str(transport.get("mode", "")) == "stdio":
		return config_service.get_claude_code_stdio_command(
			current_cli_scope,
			str(transport.get("command", "")),
			Array(transport.get("args", []))
		)
	return config_service.get_claude_code_command(
		current_cli_scope,
		str(transport.get("host", "127.0.0.1")),
		int(transport.get("port", 3000))
	)


func _build_codex_cli_content(transport: Dictionary, config_service) -> String:
	if str(transport.get("mode", "")) == "stdio":
		return config_service.get_codex_stdio_command(
			str(transport.get("command", "")),
			Array(transport.get("args", []))
		)
	return config_service.get_codex_command(
		str(transport.get("host", "127.0.0.1")),
		int(transport.get("port", 3000))
	)


func _build_opencode_cli_content(transport: Dictionary, config_service) -> String:
	if str(transport.get("mode", "")) == "stdio":
		return config_service.get_opencode_local_config(
			str(transport.get("command", "")),
			Array(transport.get("args", []))
		)
	return config_service.get_opencode_remote_config(
		str(transport.get("host", "127.0.0.1")),
		int(transport.get("port", 3000))
	)


func _build_qwen_cli_content(current_cli_scope: String, transport: Dictionary, config_service) -> String:
	if str(transport.get("mode", "")) == "stdio":
		return config_service.get_command_config(
			str(transport.get("command", "")),
			Array(transport.get("args", []))
		)
	return config_service.get_qwen_command(
		current_cli_scope,
		str(transport.get("host", "127.0.0.1")),
		int(transport.get("port", 3000))
	)


func _get_cli_summary_key(client_id: String, transport: Dictionary) -> String:
	if str(transport.get("mode", "")) == "stdio":
		match client_id:
			"claude_code":
				return "config_client_claude_code_stdio_desc"
			"codex":
				return "config_client_codex_stdio_desc"
			"gemini":
				return "config_client_gemini_stdio_desc"
			"opencode":
				return "config_client_opencode_stdio_desc"
			"qwen":
				return "config_client_qwen_stdio_desc"
	return "config_client_%s_desc" % client_id


func _get_desktop_summary_key(client_id: String, transport: Dictionary) -> String:
	if str(transport.get("mode", "")) == "stdio":
		match client_id:
			"claude_desktop":
				return "config_client_claude_desktop_stdio_desc"
			"cursor":
				return "config_client_cursor_stdio_desc"
			"trae":
				return "config_client_trae_stdio_desc"
			"windsurf":
				return "config_client_windsurf_stdio_desc"
			"cline":
				return "config_client_cline_stdio_desc"
			"roo_code":
				return "config_client_roo_code_stdio_desc"
			"cherry_studio":
				return "config_client_cherry_studio_stdio_desc"
			"gemini":
				return "config_client_gemini_stdio_desc"
	return "config_client_%s_desc" % client_id


func _build_client_ui_model(client_id: String, client: Dictionary, client_install_statuses: Dictionary, localization) -> Dictionary:
	var model = client.duplicate(true)
	var detection: Dictionary = client_install_statuses.get(client_id, {})
	model["path_label_text"] = localization.get_text("config_client_write_path_label")
	if detection.is_empty():
		return model

	var status = str(detection.get("status", ""))
	if not status.is_empty():
		model["install_status_text"] = _build_client_install_status_text(client_id, model, detection, localization)
		model["install_message_text"] = _get_client_install_message_text(client_id, status, localization)
	if bool(detection.get("manual_path_invalid", false)):
		model["install_message_text"] = localization.get_text("config_client_manual_path_invalid_msg")

	var runtime_status = str(detection.get("runtime_status", {}).get("status", ""))
	if not runtime_status.is_empty():
		model["runtime_status_text"] = _get_client_runtime_status_text(runtime_status, localization)

	var entry_status = str(detection.get("config_entry_status", {}).get("status", ""))
	if not entry_status.is_empty():
		model["entry_status_text"] = _get_client_entry_status_text(entry_status, localization)

	var config_path = str(detection.get("config_path", "")).strip_edges()
	if not config_path.is_empty():
		model["path"] = config_path

	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	var using_manual_path = bool(detection.get("using_manual_path", false))
	var has_manual_path = bool(detection.get("has_manual_path", false))
	model["path_source_text"] = _get_client_path_source_text(
		str(detection.get("detected_via", "")),
		using_manual_path,
		not executable_path.is_empty(),
		localization
	)
	if not executable_path.is_empty():
		if client_id == "codex" or client_id == "claude_code" or client_id == "gemini" or client_id == "opencode" or client_id == "qwen":
			model["detail_label_text"] = localization.get_text("config_client_cli_entry_label")
			model["explanation_text"] = localization.get_text("config_client_cli_detected_explainer")
		else:
			model["detail_label_text"] = localization.get_text("config_client_program_entry_label")
			model["explanation_text"] = localization.get_text("config_client_desktop_path_explainer")
		model["detail_value"] = executable_path
	elif client_id == "codex" or client_id == "claude_code" or client_id == "gemini" or client_id == "opencode" or client_id == "qwen":
		model["detail_label_text"] = localization.get_text("config_client_cli_path_label")
		model["detail_value"] = executable_path
		model["explanation_text"] = localization.get_text("config_client_cli_missing_explainer")
	elif client_id == "claude_desktop" or client_id == "cursor" or client_id == "trae" or client_id == "windsurf" or client_id == "cline" or client_id == "roo_code" or client_id == "cherry_studio":
		model["explanation_text"] = localization.get_text("config_client_desktop_write_only_explainer")
	else:
		model["explanation_text"] = localization.get_text("config_client_pick_path_explainer")

	if using_manual_path:
		model["explanation_text"] = localization.get_text("config_client_custom_path_explainer")

	model["launch_supported"] = bool(detection.get("launch_supported", false))
	model["launch_enabled"] = bool(detection.get("launch_supported", false))
	if client_id == "cursor" or client_id == "trae" or client_id == "windsurf":
		model["launch_action_label_key"] = "config_client_action_open_project"
	elif client_id == "claude_code" or client_id == "codex" or client_id == "gemini" or client_id == "opencode" or client_id == "qwen":
		model["launch_action_label_key"] = "config_client_action_open_terminal"
	elif client_id == "claude_desktop" or client_id == "codex_desktop" or client_id == "opencode_desktop" or client_id == "cherry_studio":
		model["launch_action_label_key"] = "config_client_action_open_app"

	model["path_pick_supported"] = bool(detection.get("path_pick_supported", false))
	model["path_pick_enabled"] = bool(detection.get("path_pick_supported", false))
	model["path_pick_action_label_key"] = "config_client_action_reselect_path" if has_manual_path else (
		"config_client_action_choose_cli_path" if client_id == "codex" or client_id == "claude_code" or client_id == "gemini" or client_id == "opencode" or client_id == "qwen" else "config_client_action_choose_program_path"
	)
	model["path_clear_supported"] = bool(detection.get("path_clear_supported", false))
	model["path_clear_enabled"] = bool(detection.get("path_clear_supported", false))
	if not config_path.is_empty():
		model["open_config_dir_supported"] = true
		model["open_config_dir_enabled"] = not config_path.get_base_dir().is_empty()
		model["open_config_file_supported"] = true
		model["open_config_file_enabled"] = FileAccess.file_exists(config_path)

	match client_id:
		"claude_desktop", "cursor", "trae", "opencode", "windsurf", "cline", "roo_code":
			model["writeable"] = bool(detection.get("write_supported", false))
			model["remove_supported"] = bool(detection.get("write_supported", false))
			model["remove_enabled"] = entry_status == "present"
		"claude_code":
			model["primary_action_enabled"] = bool(detection.get("auto_add_supported", false))
			model["primary_action_label_key"] = "tool_action_remove_name" if entry_status == "present" else "config_client_action_add"
			if not bool(detection.get("auto_add_supported", false)):
				model["primary_action_disabled_reason"] = _get_client_install_message_text(client_id, status, localization)
		"codex":
			model["primary_action_enabled"] = bool(detection.get("auto_add_supported", false))
			model["primary_action_label_key"] = "tool_action_remove_name" if entry_status == "present" else "config_client_action_add"
			if not bool(detection.get("auto_add_supported", false)):
				model["primary_action_disabled_reason"] = _get_client_install_message_text(client_id, status, localization)
		"gemini":
			model["primary_action_enabled"] = bool(detection.get("auto_add_supported", false))
			model["primary_action_label_key"] = "tool_action_remove_name" if entry_status == "present" else "config_client_action_add"
			if not bool(detection.get("auto_add_supported", false)):
				model["primary_action_disabled_reason"] = _get_client_install_message_text(client_id, status, localization)
		"qwen":
			model["primary_action_enabled"] = bool(detection.get("auto_add_supported", false))
			model["primary_action_label_key"] = "tool_action_remove_name" if entry_status == "present" else "config_client_action_add"
			if not bool(detection.get("auto_add_supported", false)):
				model["primary_action_disabled_reason"] = _get_client_install_message_text(client_id, status, localization)
		"claude_code", "opencode":
			model["writeable"] = false

	var capability := _build_client_capability_model(client_id, model, detection)
	model["capability"] = capability
	model["guidance_text"] = _append_guidance_text(
		str(model.get("guidance_text", "")),
		_build_client_capability_summary_text(capability, localization)
	)
	return model


func _build_client_capability_model(client_id: String, model: Dictionary, detection: Dictionary) -> Dictionary:
	var entry_status := str(detection.get("config_entry_status", {}).get("status", ""))
	var config_path := str(detection.get("config_path", model.get("path", ""))).strip_edges()
	var write_supported := bool(detection.get("write_supported", false))
	var auto_add_supported := bool(detection.get("auto_add_supported", false))
	var launch_supported := bool(detection.get("launch_supported", false))
	var path_pick_supported := bool(detection.get("path_pick_supported", false))
	var path_clear_supported := bool(detection.get("path_clear_supported", false))
	var visible_write_supported := bool(model.get("writeable", false)) or bool(model.get("remove_supported", false))
	var has_manual_config_guidance := _has_manual_config_guidance(client_id, config_path, entry_status)
	var kind := "copy_guidance"
	if auto_add_supported:
		kind = "auto_add"
	elif write_supported and visible_write_supported:
		kind = "full_write"
	elif has_manual_config_guidance:
		kind = "manual_guidance"
	elif launch_supported or path_pick_supported or path_clear_supported:
		kind = "launch_path"

	return {
		"kind": kind,
		"client_id": client_id,
		"write_supported": write_supported,
		"auto_add_supported": auto_add_supported,
		"launch_supported": launch_supported,
		"path_pick_supported": path_pick_supported,
		"path_clear_supported": path_clear_supported,
		"config_path": config_path,
		"entry_status": entry_status,
		"one_click_supported": write_supported or auto_add_supported
	}


func _has_manual_config_guidance(client_id: String, config_path: String, entry_status: String) -> bool:
	return not config_path.is_empty() or not entry_status.is_empty() or client_id == "cherry_studio" or client_id == "opencode_desktop"


func _build_client_capability_summary_text(capability: Dictionary, localization) -> String:
	var kind := str(capability.get("kind", "copy_guidance"))
	var summary_key := "config_client_capability_%s" % kind
	var summary: String = localization.get_text(summary_key)
	if summary == summary_key:
		return ""
	return "%s: %s" % [localization.get_text("config_client_capability_summary_label"), summary]


func _append_guidance_text(existing_text: String, additional_text: String) -> String:
	var existing := existing_text.strip_edges()
	var additional := additional_text.strip_edges()
	if additional.is_empty():
		return existing
	if existing.is_empty():
		return additional
	return "%s\n%s" % [existing, additional]


func _build_client_install_status_text(client_id: String, model: Dictionary, detection: Dictionary, localization) -> String:
	var entry_status = str(detection.get("config_entry_status", {}).get("status", ""))
	var config_path = str(detection.get("config_path", model.get("path", ""))).strip_edges()
	if entry_status == "present":
		if client_id == "claude_code":
			var cli_scope = str(model.get("cli_scope", "user"))
			var scope_key = "scope_project" if cli_scope == "project" else "scope_user"
			return "%s\n%s" % [
				localization.get_text("config_client_entry_present"),
				localization.get_text(scope_key)
			]
		if not config_path.is_empty():
			return "%s\n%s" % [
				localization.get_text("config_client_entry_present"),
				config_path
			]
		return localization.get_text("config_client_entry_present")
	return _get_client_install_status_text(str(detection.get("status", "")), localization)


func _get_client_install_status_text(status: String, localization) -> String:
	match status:
		"ready":
			return localization.get_text("config_client_status_ready")
		"config_only":
			return localization.get_text("config_client_status_config_only")
		"missing":
			return localization.get_text("config_client_status_missing")
		_:
			return localization.get_text("config_client_status_error")


func _get_client_runtime_status_text(status: String, localization) -> String:
	match status:
		"running":
			return localization.get_text("config_client_runtime_running")
		"not_running":
			return localization.get_text("config_client_runtime_not_running")
		_:
			return localization.get_text("config_client_runtime_unknown")


func _get_client_entry_status_text(status: String, localization) -> String:
	match status:
		"present":
			return localization.get_text("config_client_entry_present")
		"missing_file":
			return localization.get_text("config_client_entry_missing_file")
		"empty":
			return localization.get_text("config_client_entry_empty")
		"missing_server":
			return localization.get_text("config_client_entry_missing_server")
		"invalid_json":
			return localization.get_text("config_client_entry_invalid_json")
		"incompatible_root", "incompatible_mcp_servers":
			return localization.get_text("config_client_entry_incompatible")
		"deferred":
			return localization.get_text("config_client_entry_deferred")
		_:
			return localization.get_text("config_client_status_error")


func _get_client_install_message_text(client_id: String, status: String, localization) -> String:
	var key := "config_client_%s_%s_msg" % [client_id, status]
	var localized = localization.get_text(key)
	if localized == key:
		return ""
	return localized


func _get_client_path_source_text(detected_via: String, using_manual_path: bool, has_detected_path: bool, localization) -> String:
	if using_manual_path:
		return localization.get_text("config_client_path_source_manual")
	if detected_via == "windows_store":
		return localization.get_text("config_client_path_source_store")
	if has_detected_path:
		return localization.get_text("config_client_path_source_auto")
	if not detected_via.is_empty():
		return localization.get_text("config_client_path_source_auto")
	return localization.get_text("config_client_path_source_missing")
