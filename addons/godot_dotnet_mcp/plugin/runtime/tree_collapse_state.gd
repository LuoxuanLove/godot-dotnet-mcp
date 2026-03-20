@tool
extends RefCounted
class_name TreeCollapseState

const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")

const COLLAPSED_NODES_KEY := "collapsed_nodes"
const KIND_ROOT := "root"
const KIND_DOMAIN := "domain"
const KIND_CATEGORY := "category"
const KIND_TOOL := "tool"
const KIND_ATOMIC := "atomic"
const EXPANDABLE_KINDS := [KIND_ROOT, KIND_DOMAIN, KIND_CATEGORY, KIND_TOOL, KIND_ATOMIC]


static func normalize_settings(settings: Dictionary, all_categories: Array, default_domains: Array, default_system_tools: Array) -> void:
	var existing := settings.get(COLLAPSED_NODES_KEY, {})
	var normalized := {}
	if existing is Dictionary:
		normalized = (existing as Dictionary).duplicate(true)
	normalized[KIND_ROOT] = _normalize_key_list(normalized.get(KIND_ROOT, []))
	normalized[KIND_DOMAIN] = _normalize_key_list(normalized.get(KIND_DOMAIN, settings.get("collapsed_domains", default_domains)))
	normalized[KIND_CATEGORY] = _normalize_key_list(normalized.get(KIND_CATEGORY, settings.get("collapsed_categories", all_categories)))
	normalized[KIND_TOOL] = _normalize_key_list(normalized.get(KIND_TOOL, settings.get("collapsed_system_tools", default_system_tools)))
	normalized[KIND_ATOMIC] = _normalize_key_list(normalized.get(KIND_ATOMIC, SystemTreeCatalog.get_default_collapsed_atomic_tools()))
	for key in normalized.keys():
		if key in EXPANDABLE_KINDS:
			continue
		var value = normalized.get(key, [])
		normalized[key] = _normalize_key_list(value)
	settings.erase("collapsed_categories")
	settings.erase("collapsed_domains")
	settings.erase("collapsed_system_tools")
	settings[COLLAPSED_NODES_KEY] = normalized


static func is_node_collapsed(settings: Dictionary, kind: String, key: String) -> bool:
	if key.is_empty():
		return false
	var collapsed_nodes = settings.get(COLLAPSED_NODES_KEY, {})
	if not (collapsed_nodes is Dictionary):
		return false
	var kind_entries = (collapsed_nodes as Dictionary).get(kind, [])
	if not (kind_entries is Array):
		return false
	return (kind_entries as Array).has(key)


static func set_node_collapsed(settings: Dictionary, kind: String, key: String, collapsed: bool) -> void:
	if key.is_empty():
		return
	var collapsed_nodes = settings.get(COLLAPSED_NODES_KEY, {})
	if not (collapsed_nodes is Dictionary):
		collapsed_nodes = {}
	var collapsed_nodes_dict := collapsed_nodes as Dictionary
	var kind_entries = collapsed_nodes_dict.get(kind, [])
	if not (kind_entries is Array):
		kind_entries = []
	var entries: Array[String] = []
	for value in kind_entries:
		var value_text = str(value)
		if value_text.is_empty() or entries.has(value_text):
			continue
		entries.append(value_text)
	if collapsed:
		if not entries.has(key):
			entries.append(key)
	else:
		entries.erase(key)
	entries.sort()
	collapsed_nodes_dict[kind] = entries
	settings[COLLAPSED_NODES_KEY] = collapsed_nodes_dict


static func get_collapsed_nodes(settings: Dictionary) -> Dictionary:
	var collapsed_nodes = settings.get(COLLAPSED_NODES_KEY, {})
	if not (collapsed_nodes is Dictionary):
		return {}
	return (collapsed_nodes as Dictionary).duplicate(true)


static func _normalize_key_list(raw_value) -> Array[String]:
	var values: Array[String] = []
	if raw_value is Array:
		for item in raw_value:
			var value := str(item)
			if value.is_empty() or values.has(value):
				continue
			values.append(value)
	values.sort()
	return values
