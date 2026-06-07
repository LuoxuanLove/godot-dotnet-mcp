@tool
extends RefCounted
class_name ClientCapabilityMatrix

const SUPPORTED_CLIENT_IDS := [
	"claude_desktop",
	"claude_code",
	"cursor",
	"trae",
	"codex_desktop",
	"codex",
	"gemini",
	"opencode_desktop",
	"opencode",
	"windsurf",
	"cline",
	"roo_code",
	"qwen",
	"cherry_studio"
]

const SUPPORT_LEVEL_BY_CLIENT := {
	"claude_desktop": "full_write",
	"claude_code": "auto_add",
	"cursor": "full_write",
	"trae": "full_write",
	"codex_desktop": "launch_path",
	"codex": "auto_add",
	"gemini": "auto_add",
	"opencode_desktop": "manual_guidance",
	"opencode": "full_write",
	"windsurf": "full_write",
	"cline": "full_write",
	"roo_code": "full_write",
	"qwen": "auto_add",
	"cherry_studio": "manual_guidance"
}

const CLI_CLIENT_IDS := ["claude_code", "codex", "gemini", "opencode", "qwen"]


static func get_supported_client_ids() -> PackedStringArray:
	return PackedStringArray(SUPPORTED_CLIENT_IDS)


static func get_support_level(client_id: String) -> String:
	return _normalize_support_level(str(SUPPORT_LEVEL_BY_CLIENT.get(client_id, "copy_guidance")))


static func build_for_client(
	client_id: String,
	launch_supported: bool,
	path_pick_supported: bool,
	path_clear_supported: bool,
	config_path_available: bool
) -> Dictionary:
	return build_client_capability(
		client_id,
		get_support_level(client_id),
		launch_supported,
		path_pick_supported,
		path_clear_supported,
		config_path_available
	)


static func build_client_capability(
	client_id: String,
	support_level: String,
	launch_supported: bool,
	path_pick_supported: bool,
	path_clear_supported: bool,
	config_path_available: bool
) -> Dictionary:
	var normalized_support_level := _normalize_support_level(support_level)
	var actions: Array[String] = ["copy_config"]
	match normalized_support_level:
		"full_write":
			actions.append("write_config")
			actions.append("remove_config")
		"auto_add":
			actions.append("auto_add")
			actions.append("remove_config")
		"manual_guidance":
			actions.append("open_config_dir")
	if launch_supported:
		actions.append("open_terminal" if _is_cli_client(client_id) else "open_app")
	if path_pick_supported:
		actions.append("pick_path")
	if path_clear_supported:
		actions.append("clear_path")
	if config_path_available:
		actions.append("open_config_dir")
		actions.append("open_config_file")
	return {
		"support_level": normalized_support_level,
		"kind": normalized_support_level,
		"actions": _deduplicate_strings(actions),
		"notes": ["config_client_capability_%s" % normalized_support_level]
	}


static func _normalize_support_level(support_level: String) -> String:
	match support_level:
		"full_write", "auto_add", "manual_guidance", "launch_path", "copy_guidance":
			return support_level
		_:
			return "copy_guidance"


static func _is_cli_client(client_id: String) -> bool:
	return CLI_CLIENT_IDS.has(client_id)


static func _deduplicate_strings(values: Array[String]) -> Array[String]:
	var deduplicated: Array[String] = []
	for value in values:
		if not deduplicated.has(value):
			deduplicated.append(value)
	return deduplicated
