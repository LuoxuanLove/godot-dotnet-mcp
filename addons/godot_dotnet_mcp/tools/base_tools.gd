@tool
extends RefCounted
class_name MCPBaseTool

## Base class for all MCP tool executors

const TypeUtils = preload("res://addons/godot_dotnet_mcp/tools/mcp_type_utils.gd")
const NodeUtils = preload("res://addons/godot_dotnet_mcp/tools/mcp_node_utils.gd")
const ScriptParser = preload("res://addons/godot_dotnet_mcp/tools/mcp_script_parser.gd")
const FileUtils = preload("res://addons/godot_dotnet_mcp/tools/mcp_file_utils.gd")
const JsonUtils = preload("res://addons/godot_dotnet_mcp/tools/mcp_json_utils.gd")

var _type_utils := TypeUtils.new()
var _node_utils := NodeUtils.new()
var _script_parser := ScriptParser.new()
var _file_utils := FileUtils.new()
var _json_utils := JsonUtils.new()
var _context: Dictionary = {}
var _editor_interface_override = null
var _scene_root_override = null
var _selection_override = null
var _filesystem_override = null
var _undo_redo_override = null


func configure_context(context = null) -> void:
	if context == null:
		dispose_context()
		return
	if context is Dictionary:
		_context = (context as Dictionary).duplicate(true)
	else:
		_context = {}
	_editor_interface_override = _context.get("editor_interface", null)
	_scene_root_override = _context.get("scene_root", null)
	_selection_override = _context.get("selection", null)
	_filesystem_override = _context.get("filesystem", null)
	_undo_redo_override = _context.get("undo_redo", null)


func dispose_context() -> void:
	_context = {}
	_editor_interface_override = null
	_scene_root_override = null
	_selection_override = null
	_filesystem_override = null
	_undo_redo_override = null


func get_tools() -> Array[Dictionary]:
	return []


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	return _error("Tool not implemented: %s" % tool_name)


func _success(data = null, message: String = "") -> Dictionary:
	return {
		"success": true,
		"data": data,
		"message": message
	}


func _error(message: String, data = null, hints: Array = []) -> Dictionary:
	var result = {
		"success": false,
		"error": message
	}
	if data != null:
		result["data"] = data
	if not hints.is_empty():
		result["hints"] = hints
	return result


func _get_property_info(node: Node, property_name: String) -> Dictionary:
	return _type_utils.get_property_info(node, property_name)


func _parse_range_hint(hint_string: String, is_int: bool = false) -> Dictionary:
	return _type_utils.parse_range_hint(hint_string, is_int)


func _type_to_string(type: int) -> String:
	return _type_utils.type_to_string(type)


func _validate_value_type(value, expected_type: int, prop_info: Dictionary = {}) -> Dictionary:
	return _type_utils.validate_value_type(value, expected_type, prop_info)


func _normalize_res_path(path: String) -> String:
	return _file_utils.normalize_res_path(path)


func _read_text_file(path: String) -> Dictionary:
	return _file_utils.read_text_file(path)


func _detect_script_language(path: String) -> String:
	return _script_parser.detect_script_language(path)


func _parse_script_metadata(path: String) -> Dictionary:
	return _script_parser.parse_script_metadata(path)


func _parse_csharp_metadata(path: String, content: String) -> Dictionary:
	return _script_parser.parse_csharp_metadata(path, content)


func _parse_gdscript_metadata(path: String, content: String) -> Dictionary:
	return _script_parser.parse_gdscript_metadata(path, content)


func _get_editor_interface():
	if _editor_interface_override != null:
		return _editor_interface_override
	if not Engine.is_editor_hint():
		return null
	return _node_utils.get_editor_interface()


func _get_edited_scene_root():
	if _scene_root_override != null:
		return _scene_root_override
	if not Engine.is_editor_hint():
		return null
	return _node_utils.get_edited_scene_root()


func _get_selection():
	if _selection_override != null:
		return _selection_override
	if not Engine.is_editor_hint():
		return null
	return _node_utils.get_selection()


func _get_filesystem():
	if _filesystem_override != null:
		return _filesystem_override
	if not Engine.is_editor_hint():
		return null
	return _node_utils.get_filesystem()


func _get_undo_redo():
	if _undo_redo_override != null:
		return _undo_redo_override
	var editor_interface = _get_editor_interface()
	if editor_interface != null and editor_interface.has_method("get_editor_undo_redo"):
		return editor_interface.get_editor_undo_redo()
	return null


func _get_scene_path(node: Node) -> String:
	return _node_utils.get_scene_path(node)


func _node_to_dict(node: Node, include_children: bool = false, max_depth: int = 3) -> Dictionary:
	return _node_utils.node_to_dict(node, include_children, max_depth)


func _find_node_by_path(path: String) -> Node:
	var root = _scene_root_override
	if root == null:
		root = _node_utils.get_edited_scene_root()
	if root == null:
		return null

	var normalized_path = _node_utils.normalize_node_path(path, root)
	if normalized_path.is_empty() or normalized_path == ".":
		return root
	if normalized_path.begins_with("/"):
		var absolute_node = root.get_node_or_null(NodePath(normalized_path))
		if absolute_node != null:
			return absolute_node
	return root.get_node_or_null(NodePath(normalized_path))


func _normalize_node_path(path: String, root: Node = null) -> String:
	return _node_utils.normalize_node_path(path, root)


func _parse_json_like_value(value):
	return _json_utils.parse_json_like_value(value)


func _normalize_input_value(value, reference = null):
	return _json_utils.normalize_input_value(value, reference)


func _get_nested_value(data, dotted_key: String) -> Dictionary:
	return _json_utils.get_nested_value(data, dotted_key)


func _set_nested_value(data, dotted_key: String, value):
	return _json_utils.set_nested_value(data, dotted_key, value)


func _find_nodes_by_name(name_pattern: String, parent: Node = null) -> Array[Node]:
	return _node_utils.find_nodes_by_name(name_pattern, parent)


func _find_nodes_by_type(type_name: String, parent: Node = null) -> Array[Node]:
	return _node_utils.find_nodes_by_type(type_name, parent)


func _serialize_value(value) -> Variant:
	return _type_utils.serialize_value(value)


func _deserialize_value(value, reference):
	return _type_utils.deserialize_value(value, reference)
