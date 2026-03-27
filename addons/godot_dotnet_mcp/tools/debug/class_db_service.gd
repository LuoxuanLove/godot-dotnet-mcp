@tool
extends "res://addons/godot_dotnet_mcp/tools/debug/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	match action:
		"get_class_list":
			return _get_class_list()
		"get_class_info":
			return _get_class_info(str(args.get("class_name", "")))
		"get_class_methods":
			return _get_class_methods(str(args.get("class_name", "")), bool(args.get("include_inherited", false)))
		"get_class_properties":
			return _get_class_properties(str(args.get("class_name", "")), bool(args.get("include_inherited", false)))
		"get_class_signals":
			return _get_class_signals(str(args.get("class_name", "")), bool(args.get("include_inherited", false)))
		"get_inheriters":
			return _get_inheriters(str(args.get("class_name", "")))
		"class_exists":
			return _class_exists(str(args.get("class_name", "")))
		_:
			return _error("Unknown action: %s" % action)


func _get_class_list() -> Dictionary:
	var classes = ClassDB.get_class_list()
	var class_array: Array[String] = []
	for c in classes:
		class_array.append(str(c))
	class_array.sort()
	return _success({
		"count": class_array.size(),
		"classes": class_array
	})


func _get_class_info(cls_name: String) -> Dictionary:
	if cls_name.is_empty():
		return _error("Class name is required")
	if not ClassDB.class_exists(cls_name):
		return _error("Class not found: %s" % cls_name)
	return _success({
		"name": cls_name,
		"parent": str(ClassDB.get_parent_class(cls_name)),
		"can_instantiate": ClassDB.can_instantiate(cls_name),
		"is_class": ClassDB.is_parent_class(cls_name, "Object"),
		"method_count": ClassDB.class_get_method_list(cls_name, true).size(),
		"property_count": ClassDB.class_get_property_list(cls_name, true).size(),
		"signal_count": ClassDB.class_get_signal_list(cls_name, true).size()
	})


func _get_class_methods(cls_name: String, include_inherited: bool) -> Dictionary:
	if cls_name.is_empty():
		return _error("Class name is required")
	if not ClassDB.class_exists(cls_name):
		return _error("Class not found: %s" % cls_name)
	var methods_list = ClassDB.class_get_method_list(cls_name, not include_inherited)
	var methods: Array[Dictionary] = []
	for method in methods_list:
		methods.append({
			"name": str(method.name),
			"args": method.args.size(),
			"return_type": method.get("return", {}).get("type", 0),
			"flags": method.flags
		})
	return _success({
		"class": cls_name,
		"include_inherited": include_inherited,
		"count": methods.size(),
		"methods": methods
	})


func _get_class_properties(cls_name: String, include_inherited: bool) -> Dictionary:
	if cls_name.is_empty():
		return _error("Class name is required")
	if not ClassDB.class_exists(cls_name):
		return _error("Class not found: %s" % cls_name)
	var props_list = ClassDB.class_get_property_list(cls_name, not include_inherited)
	var properties: Array[Dictionary] = []
	for prop in props_list:
		properties.append({
			"name": str(prop.name),
			"type": prop.type,
			"hint": prop.hint,
			"usage": prop.usage
		})
	return _success({
		"class": cls_name,
		"include_inherited": include_inherited,
		"count": properties.size(),
		"properties": properties
	})


func _get_class_signals(cls_name: String, include_inherited: bool) -> Dictionary:
	if cls_name.is_empty():
		return _error("Class name is required")
	if not ClassDB.class_exists(cls_name):
		return _error("Class not found: %s" % cls_name)
	var signals_list = ClassDB.class_get_signal_list(cls_name, not include_inherited)
	var signals_arr: Array[Dictionary] = []
	for sig in signals_list:
		signals_arr.append({
			"name": str(sig.name),
			"args": sig.args.size()
		})
	return _success({
		"class": cls_name,
		"include_inherited": include_inherited,
		"count": signals_arr.size(),
		"signals": signals_arr
	})


func _get_inheriters(cls_name: String) -> Dictionary:
	if cls_name.is_empty():
		return _error("Class name is required")
	if not ClassDB.class_exists(cls_name):
		return _error("Class not found: %s" % cls_name)
	var inheriters = ClassDB.get_inheriters_from_class(cls_name)
	var inheriter_array: Array[String] = []
	for c in inheriters:
		inheriter_array.append(str(c))
	inheriter_array.sort()
	return _success({
		"class": cls_name,
		"count": inheriter_array.size(),
		"inheriters": inheriter_array
	})


func _class_exists(cls_name: String) -> Dictionary:
	if cls_name.is_empty():
		return _error("Class name is required")
	return _success({
		"class": cls_name,
		"exists": ClassDB.class_exists(cls_name)
	})
