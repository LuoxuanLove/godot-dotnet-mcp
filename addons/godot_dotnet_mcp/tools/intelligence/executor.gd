@tool
extends RefCounted

## Intelligence layer dispatcher — 15 built-in tools + user custom tools (user_* prefix).

const _BASE = "res://addons/godot_dotnet_mcp/tools/intelligence/"
const _CUSTOM_TOOLS_DIR = "res://addons/godot_dotnet_mcp/custom_tools/"

var _bridge
var _impls: Array = []
var _runtime_context: Dictionary = {}


func _init() -> void:
	var bridge_script = ResourceLoader.load(_BASE + "atomic_bridge.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	if bridge_script == null:
		return
	_bridge = bridge_script.new()

	for impl_name in ["impl_project", "impl_scene", "impl_script", "impl_index"]:
		var path = _BASE + impl_name + ".gd"
		var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var can_inst = script != null and (script as Script).can_instantiate()
		if not can_inst:
			MCPDebugBuffer.record("warning", "intelligence",
				"Failed to load impl: %s" % impl_name)
			if script != null:
				(script as Script).reload()
			continue
		var impl = script.new()
		if impl == null:
			MCPDebugBuffer.record("warning", "intelligence",
				"Failed to instantiate impl: %s" % impl_name)
			continue
		impl.bridge = _bridge
		if impl.has_method("configure_runtime"):
			impl.configure_runtime(_runtime_context)
		_impls.append(impl)

	_load_custom_tools()
	MCPDebugBuffer.record("debug", "intelligence",
		"Initialized: %d impls loaded" % _impls.size())


func _load_custom_tools() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_CUSTOM_TOOLS_DIR)):
		return
	var files = DirAccess.get_files_at(_CUSTOM_TOOLS_DIR)
	if files == null:
		return
	for file_name in files:
		if not str(file_name).ends_with(".gd"):
			continue
		var path = _CUSTOM_TOOLS_DIR + str(file_name)
		var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if script == null or not (script as Script).can_instantiate():
			continue
		var impl = (script as Script).new()
		if impl == null:
			continue
		if not impl.has_method("handles") or not impl.has_method("get_tools") or not impl.has_method("execute"):
			push_warning("[MCP Intelligence] Skipping custom tool %s: missing handles/get_tools/execute" % file_name)
			MCPDebugBuffer.record("warning", "intelligence",
				"Skipping %s: missing handles/get_tools/execute interface" % file_name)
			continue
		# Validate user_* prefix on all declared tools
		var tool_names_ok := true
		for t in impl.get_tools():
			if not str(t.get("name", "")).begins_with("user_"):
				push_warning("[MCP Intelligence] Skipping custom tool %s: tool name must start with 'user_'" % file_name)
				MCPDebugBuffer.record("warning", "intelligence",
					"Skipping %s: tool name must start with 'user_'" % file_name)
				tool_names_ok = false
				break
		if not tool_names_ok:
			continue
		impl.bridge = _bridge
		if impl.has_method("configure_runtime"):
			impl.configure_runtime(_runtime_context)
		impl.set_meta("is_user_tool", true)
		impl.set_meta("script_path", path)
		_impls.append(impl)
		MCPDebugBuffer.record("info", "intelligence", "Custom tool loaded: %s" % file_name)


func get_tools() -> Array[Dictionary]:
	var tools: Array[Dictionary] = []
	for impl in _impls:
		if impl.has_meta("is_user_tool"):
			var script_path = str(impl.get_meta("script_path", ""))
			for t in impl.get_tools():
				var tool_copy: Dictionary = (t as Dictionary).duplicate(true)
				tool_copy["source"] = "user_tool"
				tool_copy["script_path"] = script_path
				tools.append(tool_copy)
		else:
			tools.append_array(impl.get_tools())
	return tools


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	for impl in _impls:
		if impl.handles(tool_name):
			return impl.execute(tool_name, args)
	MCPDebugBuffer.record("warning", "intelligence", "No handler for tool: %s" % tool_name)
	if _bridge != null:
		return _bridge.error("Unknown tool: %s" % tool_name)
	return {"success": false, "error": "Unknown tool: %s" % tool_name}


func tick(delta: float) -> void:
	for impl in _impls:
		if impl != null and impl.has_method("tick"):
			impl.tick(delta)


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate(true)
	MCPDebugBuffer.record("info", "intelligence",
		"executor configure_runtime tool_loader=%s" % str(_runtime_context.get("tool_loader", null) != null))
	if _bridge != null and _bridge.has_method("configure_runtime"):
		_bridge.configure_runtime(_runtime_context)
	for impl in _impls:
		if impl != null and impl.has_method("configure_runtime"):
			impl.configure_runtime(_runtime_context)
