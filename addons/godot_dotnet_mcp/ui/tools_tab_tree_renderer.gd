@tool
extends RefCounted

const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")
const TreeCollapseState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tree_collapse_state.gd")
const ToolsTabContextMenuSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_context_menu_support.gd")
const ToolsTabModelSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_model_support.gd")
const ToolsTabSearchService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_search_service.gd")

const TREE_TEXT_COLUMN := 0
const TREE_CHECK_COLUMN := 1
const SYSTEM_CATEGORY := "system"

var _tool_tree: Tree = null
var _model: Dictionary = {}
var _filtered_tools_by_category: Dictionary = {}
var _localization = null
var _search_query := ""


func render_tool_tree(tool_tree: Tree, model: Dictionary, filtered_tools_by_category: Dictionary, search_query: String) -> void:
	_tool_tree = tool_tree
	_model = model
	_filtered_tools_by_category = filtered_tools_by_category
	_localization = model.get("localization")
	_search_query = search_query

	_tool_tree.clear()
	_tool_tree.set_column_clip_content(TREE_TEXT_COLUMN, true)
	_tool_tree.set_column_clip_content(TREE_CHECK_COLUMN, true)

	var root = _tool_tree.create_item()
	if root == null:
		return

	for domain_entry in _build_domain_entries():
		_create_domain_item(root, domain_entry)


func _build_domain_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var tools_by_category: Dictionary = _model.get("tools_by_category", {})
	var covered_categories: Dictionary = {}

	for domain_def_variant in _model.get("domain_defs", []):
		if not (domain_def_variant is Dictionary):
			continue
		var domain_def := domain_def_variant as Dictionary
		var visible_categories: Array[String] = []
		for category_variant in domain_def.get("categories", []):
			var category := str(category_variant)
			if not tools_by_category.has(category):
				continue
			covered_categories[category] = true
			if not ToolsTabSearchService.category_matches_search(_model, category, _filtered_tools_by_category, _search_query):
				continue
			visible_categories.append(category)
		if visible_categories.is_empty():
			continue
		entries.append({
			"key": str(domain_def.get("key", "")),
			"label_key": str(domain_def.get("label", "domain_other")),
			"categories": visible_categories
		})

	var other_categories: Array[String] = []
	var category_keys: Array = tools_by_category.keys()
	category_keys.sort()
	for category_variant in category_keys:
		var category := str(category_variant)
		if covered_categories.has(category):
			continue
		if not ToolsTabSearchService.category_matches_search(_model, category, _filtered_tools_by_category, _search_query):
			continue
		other_categories.append(category)

	if not other_categories.is_empty():
		entries.append({
			"key": "other",
			"label_key": "domain_other",
			"categories": other_categories
		})

	return entries


func _create_domain_item(parent: TreeItem, domain_entry: Dictionary) -> void:
	var domain_key = str(domain_entry.get("key", ""))
	var label_key = str(domain_entry.get("label_key", "domain_other"))
	var categories: Array = domain_entry.get("categories", [])
	var settings: Dictionary = _model.get("settings", {})
	var counts = ToolsTabModelSupport.count_categories(_model, _filtered_tools_by_category, categories)
	var item = _tool_tree.create_item(parent)
	if item == null:
		return

	_configure_item_toggle(item, ToolsTabModelSupport.is_domain_fully_enabled(_model, _filtered_tools_by_category, categories))
	var domain_label = _resolve_domain_label(domain_key, label_key)
	var domain_text = _build_count_text(domain_label, int(counts.get("enabled", 0)), int(counts.get("total", 0)))
	var domain_tooltip = ToolsTabModelSupport.get_group_tooltip(_localization, label_key)
	_configure_item_text(item, domain_text, ToolsTabContextMenuSupport.build_tree_node_metadata("domain", domain_key, domain_label, domain_key, {
		"label_key": label_key
	}), domain_tooltip)
	item.collapsed = TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_DOMAIN, domain_key)

	for category_variant in categories:
		_create_category_item(item, str(category_variant))


func _create_category_item(parent: TreeItem, category: String) -> void:
	var settings: Dictionary = _model.get("settings", {})
	var counts = ToolsTabModelSupport.count_category(_model, _filtered_tools_by_category, category)
	var item = _tool_tree.create_item(parent)
	if item == null:
		return

	_configure_item_toggle(item, ToolsTabModelSupport.is_category_fully_enabled(_model, _filtered_tools_by_category, category))
	var label_key = ToolsTabModelSupport.get_category_label_key(category)
	var load_error_messages = ToolsTabModelSupport.get_category_load_error_messages(_model, category)
	var category_label = ToolsTabModelSupport.get_category_label(_localization, category)
	var category_text = _build_count_text(category_label, int(counts.get("enabled", 0)), int(counts.get("total", 0)))
	if not load_error_messages.is_empty():
		category_text += " %s" % _localization.get_text("tools_load_error_suffix")
	var category_tooltip = ToolsTabModelSupport.get_group_tooltip(_localization, label_key)
	if not load_error_messages.is_empty():
		if not category_tooltip.is_empty():
			category_tooltip += "\n\n"
		category_tooltip += "\n".join(load_error_messages)
	_configure_item_text(item, category_text, ToolsTabContextMenuSupport.build_tree_node_metadata("category", category, category_label, category, {
		"label_key": label_key
	}), category_tooltip)
	if not load_error_messages.is_empty():
		item.set_custom_color(TREE_TEXT_COLUMN, Color(0.9, 0.35, 0.35))
	item.collapsed = TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_CATEGORY, category)

	for tool_def in ToolsTabModelSupport.get_filtered_tool_definitions(_filtered_tools_by_category, category):
		_create_tool_item(item, category, tool_def)


func _create_tool_item(parent: TreeItem, category: String, tool_def: Dictionary) -> void:
	var tool_name = str(tool_def.get("name", ""))
	var full_name = "%s_%s" % [category, tool_name]
	var item = _tool_tree.create_item(parent)
	if item == null:
		return

	_configure_tool_row(item, full_name, category, tool_name, tool_def)
	if category != SYSTEM_CATEGORY:
		return
	if not SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.has(full_name):
		return

	var settings: Dictionary = _model.get("settings", {})
	item.collapsed = TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_TOOL, full_name)
	var visited := {full_name: true}
	_create_atomic_tool_children(item, full_name, visited)


func _configure_tool_row(item: TreeItem, full_name: String, category: String, tool_name: String, tool_def: Dictionary) -> void:
	_configure_item_toggle(item, not _model.get("settings", {}).get("disabled_tools", []).has(full_name))
	var tool_display_name = ToolsTabModelSupport.get_tool_display_name(_localization, full_name, tool_name)
	_configure_item_text(item, tool_display_name, ToolsTabContextMenuSupport.build_tree_node_metadata("tool", full_name, tool_display_name, full_name, {
		"category": category,
		"tool_name": tool_name,
		"source": str(tool_def.get("source", "builtin")),
		"script_path": str(tool_def.get("script_path", "")),
		"runtime_domain": str(tool_def.get("runtime_domain", "")),
		"runtime_version": int(tool_def.get("runtime_version", 0)),
		"runtime_state": str(tool_def.get("state", "")),
		"pending_reload": bool(tool_def.get("pending_reload", false)),
		"last_error": tool_def.get("last_error", null),
		"discovery_source": str(tool_def.get("discovery_source", "")),
		"last_refresh_reason": str(tool_def.get("last_refresh_reason", ""))
	}), ToolsTabModelSupport.get_tool_description(_localization, full_name, tool_def))


func _create_atomic_tool_children(parent: TreeItem, system_full_name: String, visited: Dictionary = {}) -> void:
	for entry in SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.get(system_full_name, []):
		var atomic_full_name: String
		var actions: Array = []
		if entry is Dictionary:
			atomic_full_name = str(entry.get("tool", ""))
			actions = entry.get("actions", [])
		else:
			atomic_full_name = str(entry)

		if atomic_full_name.is_empty() or visited.has(atomic_full_name):
			continue
		var atomic_tool_def = ToolsTabModelSupport.get_tool_def_by_full_name(_model, atomic_full_name)
		if atomic_tool_def.is_empty():
			continue
		if not ToolsTabSearchService.matches_atomic_tool_search(_model, atomic_full_name, atomic_tool_def, _search_query):
			continue
		var category = ToolsTabModelSupport.extract_category_from_full_name(_model, atomic_full_name)
		var tool_name = str(atomic_tool_def.get("name", ""))
		if category.is_empty() or tool_name.is_empty():
			continue

		var item = _tool_tree.create_item(parent)
		if item == null:
			continue

		var atomic_display_name = ToolsTabModelSupport.get_tool_display_name(_localization, atomic_full_name, tool_name)
		_configure_info_row(item, atomic_display_name, ToolsTabContextMenuSupport.build_tree_node_metadata("atomic", atomic_full_name, atomic_display_name, atomic_full_name, {
			"category": category,
			"tool_name": tool_name
		}), TreeCollapseState.is_node_collapsed(_model.get("settings", {}), TreeCollapseState.KIND_ATOMIC, atomic_full_name))

		if category == SYSTEM_CATEGORY:
			var next_visited = visited.duplicate()
			next_visited[atomic_full_name] = true
			_create_atomic_tool_children(item, atomic_full_name, next_visited)

		for action_name in actions:
			var action_item = _tool_tree.create_item(item)
			if action_item != null:
				_configure_action_item(action_item, str(action_name), atomic_full_name)


func _configure_info_row(item: TreeItem, text: String, metadata: Dictionary, collapsed: bool) -> void:
	item.set_text(TREE_TEXT_COLUMN, text)
	item.set_selectable(TREE_TEXT_COLUMN, true)
	item.set_metadata(TREE_TEXT_COLUMN, metadata)
	item.set_custom_color(TREE_TEXT_COLUMN, Color(0.6, 0.6, 0.6))
	item.collapsed = collapsed


func _configure_action_item(item: TreeItem, action_name: String, parent_tool: String) -> void:
	var action_display_name := ToolsTabModelSupport.get_action_display_name(_localization, parent_tool, action_name)
	item.set_text(TREE_TEXT_COLUMN, action_display_name)
	item.set_selectable(TREE_TEXT_COLUMN, true)
	item.set_metadata(TREE_TEXT_COLUMN, ToolsTabContextMenuSupport.build_tree_node_metadata("action", parent_tool + "." + action_name, action_display_name, action_name, {
		"action": action_name,
		"tool": parent_tool,
		"parent_tool": parent_tool,
		"description_key": SystemTreeCatalog.get_action_desc_key(parent_tool, action_name)
	}))
	item.set_custom_color(TREE_TEXT_COLUMN, Color(0.45, 0.45, 0.45))


func _configure_item_toggle(item: TreeItem, checked: bool) -> void:
	item.set_cell_mode(TREE_CHECK_COLUMN, TreeItem.CELL_MODE_CHECK)
	item.set_editable(TREE_CHECK_COLUMN, true)
	item.set_selectable(TREE_CHECK_COLUMN, false)
	item.set_checked(TREE_CHECK_COLUMN, checked)


func _configure_item_text(item: TreeItem, text: String, metadata: Dictionary, tooltip: String = "") -> void:
	item.set_text(TREE_TEXT_COLUMN, text)
	item.set_selectable(TREE_TEXT_COLUMN, true)
	item.set_metadata(TREE_TEXT_COLUMN, metadata)
	if not tooltip.is_empty():
		item.set_tooltip_text(TREE_TEXT_COLUMN, tooltip)


func _build_count_text(label: String, enabled: int, total: int) -> String:
	var text = "%s    %d/%d" % [label, enabled, total]
	if enabled > 0 and enabled < total:
		text += " %s" % _localization.get_text("tools_partial_suffix")
	return text


func _resolve_domain_label(domain_key: String, label_key: String) -> String:
	if _localization == null:
		return ToolsTabModelSupport.humanize_identifier(domain_key)
	var translated = _localization.get_text(label_key)
	if translated != label_key:
		return translated
	return ToolsTabModelSupport.humanize_identifier(domain_key)
