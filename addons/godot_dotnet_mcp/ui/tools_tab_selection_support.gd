@tool
extends RefCounted


static func empty_state() -> Dictionary:
	return {
		"kind": "",
		"key": "",
		"category": "",
		"tool_name": ""
	}


static func build_state_from_metadata(metadata) -> Dictionary:
	var state := empty_state()
	if metadata is Dictionary:
		var metadata_dict := metadata as Dictionary
		state["kind"] = str(metadata_dict.get("kind", ""))
		state["key"] = str(metadata_dict.get("key", ""))
		state["category"] = str(metadata_dict.get("category", ""))
		state["tool_name"] = str(metadata_dict.get("tool_name", ""))
	return state


static func has_selection(state: Dictionary) -> bool:
	return not str(state.get("kind", "")).is_empty() and not str(state.get("key", "")).is_empty()


static func build_preview_key(state: Dictionary) -> String:
	return "%s|%s|%s" % [
		str(state.get("kind", "")),
		str(state.get("key", "")),
		str(state.get("tool_name", ""))
	]


static func metadata_matches_state(metadata, state: Dictionary) -> bool:
	if not (metadata is Dictionary):
		return false
	var metadata_dict := metadata as Dictionary
	return str(metadata_dict.get("kind", "")) == str(state.get("kind", "")) and str(metadata_dict.get("key", "")) == str(state.get("key", ""))
