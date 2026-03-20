@tool
extends RefCounted

## System layer dispatcher for built-in system tools.

const _BASE = "res://addons/godot_dotnet_mcp/tools/system/"

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
			MCPDebugBuffer.record("warning", "system", "Failed to load impl: %s" % impl_name)
			continue
		var impl = script.new()
		if impl == null:
			MCPDebugBuffer.record("warning", "system", "Failed to instantiate impl: %s" % impl_name)
			continue
		impl.bridge = _bridge
		if impl.has_method("configure_runtime"):
			impl.configure_runtime(_runtime_context)
		_impls.append(impl)

	MCPDebugBuffer.record("debug", "system", "Initialized: %d impls loaded" % _impls.size())


func get_tools() -> Array[Dictionary]:
	var tools: Array[Dictionary] = []
	for impl in _impls:
		tools.append_array(impl.get_tools())
	return tools


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	for impl in _impls:
		if impl.handles(tool_name):
			return impl.execute(tool_name, args)
	MCPDebugBuffer.record("warning", "system", "No handler for tool: %s" % tool_name)
	if _bridge != null:
		return _bridge.error("Unknown tool: %s" % tool_name)
	return {"success": false, "error": "Unknown tool: %s" % tool_name}


func tick(delta: float) -> void:
	for impl in _impls:
		if impl != null and impl.has_method("tick"):
			impl.tick(delta)


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate(true)
	MCPDebugBuffer.record("info", "system",
		"executor configure_runtime tool_loader=%s" % str(_runtime_context.get("tool_loader", null) != null))
	if _bridge != null and _bridge.has_method("configure_runtime"):
		_bridge.configure_runtime(_runtime_context)
	for impl in _impls:
		if impl != null and impl.has_method("configure_runtime"):
			impl.configure_runtime(_runtime_context)
