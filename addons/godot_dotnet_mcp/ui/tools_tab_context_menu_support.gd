@tool
extends RefCounted


static func build_tree_node_metadata(kind: String, key: String, localized_name: String = "", english_id: String = "", extra: Dictionary = {}) -> Dictionary:
	var metadata := {
		"kind": kind,
		"key": key,
		"english_id": english_id if not english_id.is_empty() else key
	}
	if not localized_name.is_empty():
		metadata["localized_name"] = localized_name
	for extra_key in extra.keys():
		metadata[str(extra_key)] = extra[extra_key]
	return metadata


static func build_context_menu_entries(localization, metadata: Dictionary, has_children: bool, ids: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		{
			"type": "item",
			"id": int(ids.get("copy_localized_name", 0)),
			"label": localization.get_text("tool_ctx_copy_localized_name"),
			"disabled": false
		},
		{
			"type": "item",
			"id": int(ids.get("copy_english_id", 0)),
			"label": localization.get_text("tool_ctx_copy_english_id"),
			"disabled": false
		},
		{"type": "separator"},
		{
			"type": "item",
			"id": int(ids.get("expand_all", 0)),
			"label": localization.get_text("btn_expand_all"),
			"disabled": not has_children
		},
		{
			"type": "item",
			"id": int(ids.get("collapse_all", 0)),
			"label": localization.get_text("btn_collapse_all"),
			"disabled": not has_children
		}
	]
	if str(metadata.get("kind", "")) == "tool":
		entries.append({"type": "separator"})
		entries.append({
			"type": "item",
			"id": int(ids.get("copy_schema", 0)),
			"label": localization.get_text("tool_ctx_copy_schema_json"),
			"disabled": false
		})
		if is_user_tool_metadata(metadata, str(ids.get("user_tool_root", ""))):
			entries.append({
				"type": "item",
				"id": int(ids.get("delete_tool", 0)),
				"label": localization.get_text("btn_delete_user_tool"),
				"disabled": false
			})
	return entries


static func get_context_menu_localized_name(metadata: Dictionary) -> String:
	var localized_name := str(metadata.get("localized_name", ""))
	if not localized_name.is_empty():
		return localized_name
	return str(metadata.get("key", ""))


static func get_context_menu_english_id(metadata: Dictionary) -> String:
	var english_id := str(metadata.get("english_id", ""))
	if not english_id.is_empty():
		return english_id
	return str(metadata.get("key", ""))


static func is_user_tool_metadata(meta: Dictionary, user_tool_custom_root: String) -> bool:
	if str(meta.get("category", "")) != "user":
		return false
	var script_path = str(meta.get("script_path", ""))
	return str(meta.get("source", "")) == "user_tool" and script_path.begins_with(user_tool_custom_root + "/")


static func get_context_menu_user_tool_script_path(metadata: Dictionary, user_tool_custom_root: String) -> String:
	var direct_path = str(metadata.get("script_path", ""))
	if direct_path.begins_with(user_tool_custom_root + "/"):
		return direct_path
	return ""
