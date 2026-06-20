@tool
extends VBoxContainer

signal tool_toggled(tool_name: String, enabled: bool)
signal delete_user_tool_requested(script_path: String)
signal category_toggled(category: String, enabled: bool)
signal domain_toggled(domain_key: String, enabled: bool)
signal tree_collapse_changed(kind: String, key: String, collapsed: bool)
signal tool_view_changed(view_id: String)

const ToolPresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")
const TreeCollapseState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tree_collapse_state.gd")

const CATEGORY_LABEL_KEYS := {
	"scene": "cat_scene",
	"node": "cat_node",
	"script": "cat_script",
	"resource": "cat_resource",
	"filesystem": "cat_filesystem",
	"project": "cat_project",
	"editor": "cat_editor",
	"plugin_runtime": "cat_plugin_runtime",
	"runtime": "cat_runtime",
	"plugin_evolution": "cat_plugin_evolution",
	"plugin_developer": "cat_plugin_developer",
	"debug": "cat_debug",
	"dap": "cat_dap",
	"animation": "cat_animation",
	"signal": "cat_signal",
	"group": "cat_group",
	"material": "cat_material",
	"shader": "cat_shader",
	"lighting": "cat_lighting",
	"particle": "cat_particle",
	"tilemap": "cat_tilemap",
	"geometry": "cat_geometry",
	"physics": "cat_physics",
	"navigation": "cat_navigation",
	"audio": "cat_audio",
	"ui": "cat_ui",
	"user": "cat_user",
	"system": "cat_system"
}

const TREE_TEXT_COLUMN := 0
const TREE_CHECK_COLUMN := 1
const SYSTEM_CATEGORY := "system"
const USER_TOOL_CUSTOM_ROOT := "res://addons/godot_dotnet_mcp/custom_tools"
const TREE_TEXT_MIN_WIDTH := 180.0
const TREE_TEXT_MAX_WIDTH := 300.0
const TREE_CHECK_MIN_WIDTH := 32.0
const TREE_CHECK_MAX_WIDTH := 40.0
const TREE_HORIZONTAL_CHROME_WIDTH := 56.0
const MAX_PROTOCOL_ICON_SRC_LENGTH := 8192
const MAX_PROTOCOL_ICON_BASE64_LENGTH := 6144
const MAX_PROTOCOL_ICON_DECODED_BYTES := 4096
const MAX_ICON_TEXTURE_CACHE_ENTRIES := 64
const VIEW_AGENT_TOOLS := "agent_tools"
const VIEW_INTERNAL_EXECUTORS := "internal_executors"
const VIEW_DIAGNOSTICS := "tool_diagnostics"

@onready var _header_card: PanelContainer = %HeaderCard
@onready var _tool_count_label: Label = %ToolCountLabel
@onready var _view_mode_row: HBoxContainer = %ViewModeRow
@onready var _agent_tools_button: Button = %AgentToolsButton
@onready var _internal_executors_button: Button = %InternalExecutorsButton
@onready var _diagnostics_button: Button = %DiagnosticsButton
@onready var _search_edit: LineEdit = %ToolSearchEdit
@onready var _content_split: VSplitContainer = %ContentSplit
@onready var _tool_tree: Tree = %ToolTree
@onready var _tool_list_panel: PanelContainer = %ToolListPanel
@onready var _tool_preview_panel: PanelContainer = %ToolPreviewPanel
@onready var _tool_preview_title: Label = %ToolPreviewTitle
@onready var _tool_preview_text: TextEdit = %ToolPreviewText

const _CTX_COPY_LOCALIZED_NAME := 0
const _CTX_COPY_ENGLISH_ID := 1
const _CTX_COPY_INPUT_SCHEMA := 2
const _CTX_COPY_OUTPUT_SCHEMA := 3
const _CTX_DELETE_TOOL := 4
const _CTX_EXPAND_ALL := 10
const _CTX_COLLAPSE_ALL := 11

var _tree_syncing := false
var _current_scale := -1.0
var _localization = null
var _context_menu: PopupMenu = null
var _context_menu_metadata: Dictionary = {}
var _context_menu_target: TreeItem = null
var _current_model: Dictionary = {}
var _selected_tree_kind := ""
var _selected_tree_key := ""
var _selected_tool_category := ""
var _selected_tool_name := ""
var _selected_tree_metadata: Dictionary = {}
var _selection_sync_queued := false
var _last_tree_signature := ""
var _last_preview_key := ""
var _icon_texture_cache: Dictionary = {}
var _icon_texture_cache_order: Array[String] = []
var _active_tools_view := VIEW_AGENT_TOOLS
var _view_buttons: Dictionary = {}


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_search_edit.text_changed.connect(_on_search_text_changed)
	_view_buttons = {
		VIEW_AGENT_TOOLS: _agent_tools_button,
		VIEW_INTERNAL_EXECUTORS: _internal_executors_button,
		VIEW_DIAGNOSTICS: _diagnostics_button
	}
	_agent_tools_button.pressed.connect(_on_tool_view_button_pressed.bind(VIEW_AGENT_TOOLS))
	_internal_executors_button.pressed.connect(_on_tool_view_button_pressed.bind(VIEW_INTERNAL_EXECUTORS))
	_diagnostics_button.pressed.connect(_on_tool_view_button_pressed.bind(VIEW_DIAGNOSTICS))
	_tool_tree.item_collapsed.connect(_on_tree_item_collapsed)
	_tool_tree.gui_input.connect(_on_tree_gui_input)
	_tool_tree.theme_type_variation = "TreeSecondary"
	_tool_tree.set_allow_reselect(true)
	_tool_preview_text.editable = false
	_tool_preview_text.selecting_enabled = true
	_tool_preview_text.context_menu_enabled = true
	_tool_preview_text.set_line_wrapping_mode(TextEdit.LINE_WRAPPING_BOUNDARY)
	_tool_preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var top_pane = _content_split.get_node("TopPane") as Control
	var bottom_pane = _content_split.get_node("BottomPane") as Control
	var tool_list_panel = _content_split.get_node("TopPane/ToolListOuterMargin/ToolListPanel") as Control
	top_pane.clip_contents = true
	bottom_pane.clip_contents = true
	tool_list_panel.clip_contents = true
	_tool_preview_panel.clip_contents = true
	_context_menu = PopupMenu.new()
	add_child(_context_menu)
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	resized.connect(_on_resized)

func apply_model(model: Dictionary) -> void:
	var localization = model.get("localization")
	_localization = localization
	_current_model = model
	var editor_scale = float(model.get("editor_scale", 1.0))

	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)
	else:
		_apply_responsive_layout()

	_apply_localized_copy(localization, model)

	var model_view := _resolve_tool_view_id(str(model.get("current_tools_view", _active_tools_view)))
	if model_view != _active_tools_view:
		_active_tools_view = model_view
		_update_tool_view_buttons()

	var tree_signature = _build_tree_signature(model)
	_refresh_tree_state(model, tree_signature)


func _render_tool_tree(model: Dictionary) -> void:
	_tree_syncing = true
	_tool_tree.clear()
	_tool_tree.set_column_clip_content(TREE_TEXT_COLUMN, true)
	_tool_tree.set_column_clip_content(TREE_CHECK_COLUMN, true)
	var root = _tool_tree.create_item()
	if root == null:
		_tree_syncing = false
		return
	if _has_presentation_tree(model):
		for node in _active_tool_presentation().get("toolTree", []):
			if node is Dictionary:
				_create_presentation_node(root, model, node as Dictionary)
		_tree_syncing = false
		return
	if not _is_agent_tools_view():
		_tree_syncing = false
		return

	_create_root_group_item(root, model, SYSTEM_CATEGORY)
	_create_root_group_item(root, model, "user")

	_tree_syncing = false


func _has_presentation_tree(model: Dictionary) -> bool:
	var presentation := _active_tool_presentation()
	var tree = presentation.get("toolTree", [])
	if tree is Array and not (tree as Array).is_empty():
		return true
	if not _is_agent_tools_view():
		return false
	return model.get("toolTree", []) is Array and not (model.get("toolTree", []) as Array).is_empty()


func _create_presentation_node(parent: TreeItem, model: Dictionary, node: Dictionary) -> TreeItem:
	var filtered_node := _filter_presentation_node(model, node)
	if filtered_node.is_empty():
		return null
	var kind := str(filtered_node.get("kind", ""))
	var key := str(filtered_node.get("key", filtered_node.get("id", "")))
	var item = _tool_tree.create_item(parent)
	if item == null:
		return null
	var display_name := _get_presentation_node_display_name(filtered_node)
	var metadata := _build_presentation_node_metadata(filtered_node, display_name)
	match kind:
		"domain", "category", "executor_domain", "executor_category":
			_configure_item_toggle(item, _is_presentation_group_enabled(filtered_node))
			var text := "%s    %d/%d" % [display_name, int(filtered_node.get("enabledCount", 0)), int(filtered_node.get("totalCount", 0))]
			_configure_item_text(item, text, metadata, _get_group_tooltip(_localization, str(filtered_node.get("labelKey", ""))))
		"tool_group", "diagnostic_node":
			var text := "%s    %d/%d" % [display_name, int(filtered_node.get("enabledCount", filtered_node.get("toolCount", 0))), int(filtered_node.get("totalCount", filtered_node.get("toolCount", 0)))]
			_configure_info_row(item, text, metadata, TreeCollapseState.is_node_collapsed(model.get("settings", {}), _presentation_collapse_kind(kind), key))
		"tool", "public_tool", "executor_tool":
			_configure_item_toggle(item, not _current_model.get("settings", {}).get("disabled_tools", []).has(key))
			_configure_item_text(item, display_name, metadata, _get_tool_description(_localization, key, _get_tool_metadata(key)))
			if str(filtered_node.get("callability", "")) == "not_callable":
				item.set_editable(TREE_CHECK_COLUMN, false)
				item.set_custom_color(TREE_TEXT_COLUMN, _get_dim_text_color())
		"atomic":
			_configure_info_row(item, display_name, metadata, TreeCollapseState.is_node_collapsed(model.get("settings", {}), TreeCollapseState.KIND_ATOMIC, key))
		"action":
			_configure_item_text(item, display_name, metadata)
			item.set_custom_color(TREE_TEXT_COLUMN, _get_dim_text_color())
		_:
			_configure_item_text(item, display_name, metadata)
	var children: Array = filtered_node.get("children", [])
	if not children.is_empty() and kind != "atomic":
		item.collapsed = TreeCollapseState.is_node_collapsed(model.get("settings", {}), _presentation_collapse_kind(kind), key)
	for child in children:
		if child is Dictionary:
			_create_presentation_node(item, model, child as Dictionary)
	return item


func _filter_presentation_node(model: Dictionary, node: Dictionary) -> Dictionary:
	var query := _get_search_query()
	if query.is_empty():
		return node
	var filtered := node.duplicate(true)
	var children: Array = []
	for child in node.get("children", []):
		if not (child is Dictionary):
			continue
		var filtered_child := _filter_presentation_node(model, child as Dictionary)
		if not filtered_child.is_empty():
			children.append(filtered_child)
	if query.is_empty() or _presentation_node_matches_search(model, node, query) or not children.is_empty():
		filtered["children"] = children if not query.is_empty() else node.get("children", [])
		return filtered
	return {}


func _presentation_node_matches_search(model: Dictionary, node: Dictionary, query: String) -> bool:
	var display_name := _get_presentation_node_display_name(node).to_lower()
	if display_name.contains(query) or str(node.get("key", "")).to_lower().contains(query):
		return true
	var kind := str(node.get("kind", ""))
	if _is_tool_like_presentation_kind(kind) or kind == "atomic":
		var full_name := str(node.get("fullName", node.get("key", "")))
		var metadata := _get_tool_metadata(full_name, node)
		if _get_tool_description(model.get("localization"), full_name, metadata).to_lower().contains(query):
			return true
		if str(metadata.get("title", "")).to_lower().contains(query):
			return true
		var annotations = metadata.get("annotations", {})
		if annotations is Dictionary and str((annotations as Dictionary).get("title", "")).to_lower().contains(query):
			return true
	return false


func _get_presentation_node_display_name(node: Dictionary) -> String:
	var kind := str(node.get("kind", ""))
	match kind:
		"domain":
			return _localization.get_text(str(node.get("labelKey", "domain_other")))
		"category":
			return _get_category_label(_localization, str(node.get("category", node.get("key", ""))))
		"tool_group", "executor_domain", "executor_category", "diagnostic_node":
			return _get_labeled_presentation_name(node)
		"tool", "public_tool", "executor_tool", "legacy_tool", "atomic":
			var full_name := str(node.get("fullName", node.get("key", "")))
			return _get_tool_display_name(_localization, full_name, str(node.get("toolName", node.get("tool_name", ""))))
		"action":
			return _get_action_display_name_from_metadata(node, str(node.get("parentTool", node.get("parent_tool", ""))), str(node.get("actionName", node.get("action", ""))))
	return str(node.get("key", node.get("id", "")))


func _build_presentation_node_metadata(node: Dictionary, display_name: String) -> Dictionary:
	var kind := str(node.get("kind", ""))
	var key := str(node.get("key", node.get("id", "")))
	var normalized_kind := _normalize_presentation_kind(kind)
	var extra := {
		"presentation_kind": kind,
		"label_key": str(node.get("labelKey", "")),
		"category": str(node.get("category", "")),
		"tool_name": str(node.get("toolName", node.get("tool_name", ""))),
		"full_name": str(node.get("fullName", node.get("key", ""))),
		"description": str(node.get("description", "")),
		"title": str(node.get("title", "")),
		"icons": _duplicate_array(node.get("icons", [])),
		"annotations": _duplicate_dictionary(node.get("annotations", {})),
		"inputSchema": _duplicate_dictionary(node.get("inputSchema", {})),
		"outputSchema": _duplicate_dictionary(node.get("outputSchema", {})),
		"enabled": bool(node.get("enabled", true)),
		"treeChildren": _duplicate_array(node.get("treeChildren", [])),
		"source": str(node.get("source", "")),
		"script_path": str(node.get("script_path", node.get("scriptPath", ""))),
		"domain_script_path": str(node.get("domain_script_path", node.get("domainScriptPath", ""))),
		"load_state": str(node.get("loadState", node.get("load_state", ""))),
		"group_path": node.get("groupPath", [])
	}
	if kind == "action":
		extra["action"] = str(node.get("actionName", node.get("action", "")))
		extra["tool"] = str(node.get("parentTool", node.get("parent_tool", "")))
		extra["parent_tool"] = str(node.get("parentTool", node.get("parent_tool", "")))
		extra["description_key"] = str(node.get("descriptionKey", ""))
	return _build_tree_node_metadata(normalized_kind, key, display_name, key, extra)


func _is_presentation_group_enabled(node: Dictionary) -> bool:
	var total := int(node.get("totalCount", 0))
	return total > 0 and int(node.get("enabledCount", 0)) == total


func _presentation_collapse_kind(kind: String) -> String:
	match kind:
		"domain":
			return TreeCollapseState.KIND_DOMAIN
		"category":
			return TreeCollapseState.KIND_CATEGORY
		"tool", "public_tool", "executor_tool":
			return TreeCollapseState.KIND_TOOL
		"atomic":
			return TreeCollapseState.KIND_ATOMIC
		"tool_group":
			return TreeCollapseState.KIND_CATEGORY
		"executor_domain":
			return TreeCollapseState.KIND_DOMAIN
		"executor_category", "diagnostic_node":
			return TreeCollapseState.KIND_CATEGORY
	return kind


func _create_root_group_item(parent: TreeItem, model: Dictionary, category: String) -> void:
	var settings: Dictionary = model.get("settings", {})
	var counts = _count_category(model, category)
	var item = _tool_tree.create_item(parent)
	if item == null:
		return
	var root_label = _get_category_label(model.get("localization"), category)
	var root_text = "%s    %d/%d" % [root_label, counts["enabled"], counts["total"]]
	if counts["enabled"] > 0 and counts["enabled"] < counts["total"]:
		root_text += " %s" % model.get("localization").get_text("tools_partial_suffix")
	var root_tooltip = _get_group_tooltip(model.get("localization"), _get_category_label_key(category))
	_configure_info_row(item, root_text, _build_tree_node_metadata(TreeCollapseState.KIND_ROOT, category, root_label, category, {
		"category": category,
		"label_key": _get_category_label_key(category)
	}), TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_ROOT, category))
	if not root_tooltip.is_empty():
		item.set_tooltip_text(TREE_TEXT_COLUMN, root_tooltip)
	for tool_def in _get_filtered_tool_definitions(model, category):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		_create_tool_item(item, model, category, tool_def)


func _apply_localized_copy(localization, model: Dictionary) -> void:
	var counts = _count_visible_tools(model)
	_tool_count_label.text = localization.get_text("tools_enabled") % [counts["enabled"], counts["total"]]
	_search_edit.placeholder_text = localization.get_text("tool_search_placeholder")
	_agent_tools_button.text = localization.get_text("tools_view_agent_tools")
	_internal_executors_button.text = localization.get_text("tools_view_internal_executors")
	_diagnostics_button.text = localization.get_text("tools_view_diagnostics")
	_refresh_view_button_tooltips()
	_update_tool_view_buttons()


func _refresh_tree_state(model: Dictionary, tree_signature: String) -> void:
	if tree_signature != _last_tree_signature:
		_last_tree_signature = tree_signature
		_render_tool_tree(model)
		_refresh_preview()
		if _has_tree_selection():
			_queue_selection_sync()
		return

	_refresh_preview()


func _configure_info_row(item: TreeItem, text: String, metadata: Dictionary, collapsed: bool) -> void:
	item.set_text(TREE_TEXT_COLUMN, text)
	item.set_selectable(TREE_TEXT_COLUMN, true)
	item.set_metadata(TREE_TEXT_COLUMN, metadata)
	_apply_protocol_icon(item, metadata)
	item.set_custom_color(TREE_TEXT_COLUMN, _get_muted_text_color())
	item.collapsed = collapsed


func _configure_action_item(item: TreeItem, action_name: String, parent_tool: String) -> void:
	var action_display_name := _get_action_display_name(parent_tool, action_name)
	item.set_text(TREE_TEXT_COLUMN, action_display_name)
	item.set_selectable(TREE_TEXT_COLUMN, true)
	item.set_metadata(TREE_TEXT_COLUMN, _build_tree_node_metadata("action", parent_tool + "." + action_name, action_display_name, action_name, {
		"action": action_name,
		"tool": parent_tool,
		"parent_tool": parent_tool,
		"description_key": ToolPresentationService.get_action_desc_key(parent_tool, action_name)
	}))
	item.set_custom_color(TREE_TEXT_COLUMN, _get_dim_text_color())


func _configure_item_toggle(item: TreeItem, checked: bool) -> void:
	item.set_cell_mode(TREE_CHECK_COLUMN, TreeItem.CELL_MODE_CHECK)
	item.set_editable(TREE_CHECK_COLUMN, _is_agent_tools_view())
	item.set_selectable(TREE_CHECK_COLUMN, false)
	item.set_checked(TREE_CHECK_COLUMN, checked)


func _configure_item_text(item: TreeItem, text: String, metadata: Dictionary, tooltip: String = "") -> void:
	item.set_text(TREE_TEXT_COLUMN, text)
	item.set_selectable(TREE_TEXT_COLUMN, true)
	item.set_metadata(TREE_TEXT_COLUMN, metadata)
	_apply_protocol_icon(item, metadata)
	if not tooltip.is_empty():
		item.set_tooltip_text(TREE_TEXT_COLUMN, tooltip)


func _apply_protocol_icon(item: TreeItem, metadata: Dictionary) -> void:
	var icon_src := _metadata_icon_src(metadata)
	if icon_src.is_empty():
		return
	var texture := _texture_from_icon_src(icon_src)
	if texture == null:
		return
	item.set_icon(TREE_TEXT_COLUMN, texture)
	item.set_icon_max_width(TREE_TEXT_COLUMN, int(round(18.0 * _scale())))
	metadata["mcp_icon_src"] = icon_src
	item.set_metadata(TREE_TEXT_COLUMN, metadata)


func _metadata_icon_src(metadata: Dictionary) -> String:
	var icons = metadata.get("icons", [])
	if not (icons is Array):
		return ""
	for raw_icon in icons as Array:
		if not (raw_icon is Dictionary):
			continue
		var src := str((raw_icon as Dictionary).get("src", "")).strip_edges()
		if not src.is_empty():
			return src
	return ""


func _texture_from_icon_src(src: String) -> Texture2D:
	if src.length() > MAX_PROTOCOL_ICON_SRC_LENGTH:
		return null
	if _icon_texture_cache.has(src):
		_touch_icon_texture_cache_key(src)
		return _icon_texture_cache.get(src)
	var texture: Texture2D = null
	var svg_prefix := "data:image/svg+xml;base64,"
	if src.begins_with(svg_prefix):
		var encoded := src.substr(svg_prefix.length())
		if encoded.length() <= MAX_PROTOCOL_ICON_BASE64_LENGTH:
			var bytes := Marshalls.base64_to_raw(encoded)
			if not bytes.is_empty() and bytes.size() <= MAX_PROTOCOL_ICON_DECODED_BYTES:
				var svg_text := bytes.get_string_from_utf8().strip_edges()
				if svg_text.begins_with("<svg"):
					var image := Image.new()
					if image.load_svg_from_buffer(bytes) == OK:
						texture = ImageTexture.create_from_image(image)
	if texture != null:
		_store_icon_texture(src, texture)
	return texture


func _store_icon_texture(src: String, texture: Texture2D) -> void:
	_icon_texture_cache[src] = texture
	_touch_icon_texture_cache_key(src)
	while _icon_texture_cache_order.size() > MAX_ICON_TEXTURE_CACHE_ENTRIES:
		var evicted_src := _icon_texture_cache_order.pop_front()
		_icon_texture_cache.erase(evicted_src)


func _touch_icon_texture_cache_key(src: String) -> void:
	var existing_index := _icon_texture_cache_order.find(src)
	if existing_index >= 0:
		_icon_texture_cache_order.remove_at(existing_index)
	_icon_texture_cache_order.append(src)


func _scale() -> float:
	return _current_scale if _current_scale > 0.0 else 1.0


func _create_domain_item(root: TreeItem, model: Dictionary, domain_key: String, label_key: String, categories: Array) -> void:
	var settings: Dictionary = model.get("settings", {})
	var counts = _count_categories(model, categories)
	var item = _tool_tree.create_item(root)
	if item == null:
		return
	_configure_item_toggle(item, _is_domain_fully_enabled(model, categories))
	var domain_label = model.get("localization").get_text(label_key)
	var domain_text = "%s    %d/%d" % [domain_label, counts["enabled"], counts["total"]]
	if counts["enabled"] > 0 and counts["enabled"] < counts["total"]:
		domain_text += " %s" % model.get("localization").get_text("tools_partial_suffix")
	var domain_tooltip = _get_group_tooltip(model.get("localization"), label_key)
	_configure_item_text(item, domain_text, _build_tree_node_metadata("domain", domain_key, domain_label, domain_key, {"label_key": label_key}), domain_tooltip)
	item.collapsed = TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_DOMAIN, domain_key)

	for category in categories:
		_create_category_item(item, model, str(category))


func _create_category_item(parent: TreeItem, model: Dictionary, category: String) -> void:
	var settings: Dictionary = model.get("settings", {})
	var counts = _count_category(model, category)
	var item = _tool_tree.create_item(parent)
	if item == null:
		return
	_configure_item_toggle(item, _is_category_fully_enabled(model, category))
	var label_key = _get_category_label_key(category)
	var load_error_messages = _get_category_load_error_messages(model, category)
	var category_label = _get_category_label(model.get("localization"), category)
	var category_text = "%s    %d/%d" % [category_label, counts["enabled"], counts["total"]]
	if counts["enabled"] > 0 and counts["enabled"] < counts["total"]:
		category_text += " %s" % model.get("localization").get_text("tools_partial_suffix")
	if not load_error_messages.is_empty():
		category_text += " %s" % model.get("localization").get_text("tools_load_error_suffix")
	var category_tooltip = _get_group_tooltip(model.get("localization"), label_key)
	if not load_error_messages.is_empty():
		if not category_tooltip.is_empty():
			category_tooltip += "\n\n"
		category_tooltip += "\n".join(load_error_messages)
	_configure_item_text(item, category_text, _build_tree_node_metadata("category", category, category_label, category, {"label_key": label_key}), category_tooltip)
	if not load_error_messages.is_empty():
		item.set_custom_color(TREE_TEXT_COLUMN, _get_error_text_color())
	item.collapsed = TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_CATEGORY, category)

	for tool_def in _get_filtered_tool_definitions(model, category):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		_create_tool_item(item, model, category, tool_def)


func _create_tool_item(parent: TreeItem, model: Dictionary, category: String, tool_def: Dictionary) -> void:
	var tool_name = str(tool_def.get("name", ""))
	var full_name = "%s_%s" % [category, tool_name]
	var item = _tool_tree.create_item(parent)
	if item == null:
		return
	_configure_tool_row(item, model, full_name, category, tool_name, tool_def)
	if category == SYSTEM_CATEGORY:
		var action_values := _extract_action_values(tool_def)
		var has_children := not action_values.is_empty() or ToolPresentationService.has_atomic_children(full_name)
		if has_children:
			var settings: Dictionary = model.get("settings", {})
			item.collapsed = TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_TOOL, full_name)
		_create_action_children(item, full_name, tool_def)
		var visited := {}
		visited[full_name] = true
		_create_atomic_tool_children(item, model, full_name, visited)


func _configure_tool_row(item: TreeItem, model: Dictionary, full_name: String, category: String, tool_name: String, tool_def: Dictionary) -> void:
	var localization = model.get("localization")
	_configure_item_toggle(item, not model.get("settings", {}).get("disabled_tools", []).has(full_name))
	var tool_display_name = _get_tool_display_name(localization, full_name, tool_name)
	_configure_item_text(item, tool_display_name, _build_tree_node_metadata("tool", full_name, tool_display_name, full_name, {
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
	}), _get_tool_description(localization, full_name, tool_def))


func _create_atomic_tool_children(parent: TreeItem, model: Dictionary, system_full_name: String, visited: Dictionary = {}) -> void:
	for entry in ToolPresentationService.get_atomic_child_specs(system_full_name):
		var atomic_full_name := str(entry.get("tool", ""))
		var actions: Array = entry.get("actions", [])

		if atomic_full_name.is_empty() or visited.has(atomic_full_name):
			continue
		var atomic_tool_def = _get_tool_def_by_full_name(model, atomic_full_name)
		if atomic_tool_def.is_empty():
			continue
		if not _matches_atomic_tool_or_action_search(model, atomic_full_name, atomic_tool_def, actions):
			continue
		var category = _extract_category_from_full_name(model, atomic_full_name)
		var tool_name = str(atomic_tool_def.get("name", ""))
		if category.is_empty() or tool_name.is_empty():
			continue

		var item = _tool_tree.create_item(parent)
		if item == null:
			continue
		# Atomic tool: info-only row, no checkbox
		var atomic_display_name = _get_tool_display_name(_localization, atomic_full_name, tool_name)
		_configure_info_row(item, atomic_display_name,
			_build_tree_node_metadata("atomic", atomic_full_name, atomic_display_name, atomic_full_name, {
				"category": category,
				"tool_name": tool_name
			}),
			TreeCollapseState.is_node_collapsed(model.get("settings", {}), TreeCollapseState.KIND_ATOMIC, atomic_full_name))

		if category == SYSTEM_CATEGORY:
			var next_visited = visited.duplicate()
			next_visited[atomic_full_name] = true
			_create_atomic_tool_children(item, model, atomic_full_name, next_visited)

		# Third level: action leaf nodes
		for action_name in actions:
			var action_item = _tool_tree.create_item(item)
			if action_item != null:
				_configure_action_item(action_item, str(action_name), atomic_full_name)


func _create_action_children(parent: TreeItem, parent_full_name: String, tool_def: Dictionary) -> void:
	for action_name in _extract_action_values(tool_def):
		if not _matches_action_search(parent_full_name, str(action_name), tool_def):
			continue
		var action_item = _tool_tree.create_item(parent)
		if action_item != null:
			_configure_action_item(action_item, str(action_name), parent_full_name)


func _count_visible_tools(model: Dictionary) -> Dictionary:
	var tool_tree: Array = _active_tool_presentation().get("toolTree", [])
	if not tool_tree.is_empty():
		return _count_presentation_nodes(tool_tree)
	if not _is_agent_tools_view():
		return {"total": 0, "enabled": 0}
	return _count_legacy_visible_tools(model)


func _count_presentation_tools(model: Dictionary) -> Dictionary:
	return _count_presentation_nodes(_active_tool_presentation().get("toolTree", []))


func _count_presentation_nodes(nodes: Array) -> Dictionary:
	var total = 0
	var enabled = 0
	for entry in nodes:
		if not (entry is Dictionary):
			continue
		var node := entry as Dictionary
		if _is_tool_like_presentation_kind(str(node.get("kind", ""))):
			total += 1
			if bool(node.get("enabled", true)):
				enabled += 1
		var child_counts = _count_presentation_nodes(node.get("children", []))
		total += int(child_counts["total"])
		enabled += int(child_counts["enabled"])
	return {"total": total, "enabled": enabled}


func _count_legacy_visible_tools(model: Dictionary) -> Dictionary:
	var total = 0
	var enabled = 0
	for category in [SYSTEM_CATEGORY, "user"]:
		for tool_def in _get_filtered_tool_definitions(model, category):
			if bool(tool_def.get("compatibility_alias", false)):
				continue
			total += 1
			var full_name = "%s_%s" % [category, tool_def.get("name", "")]
			if not model.get("settings", {}).get("disabled_tools", []).has(full_name):
				enabled += 1
	return {"total": total, "enabled": enabled}


func _count_categories(model: Dictionary, categories: Array) -> Dictionary:
	var total = 0
	var enabled = 0
	for category in categories:
		var counts = _count_category(model, str(category))
		total += int(counts["total"])
		enabled += int(counts["enabled"])
	return {"total": total, "enabled": enabled}


func _count_category(model: Dictionary, category: String) -> Dictionary:
	var total = 0
	var enabled = 0
	for tool_def in _get_filtered_tool_definitions(model, category):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		total += 1
		var full_name = "%s_%s" % [category, tool_def.get("name", "")]
		if not model.get("settings", {}).get("disabled_tools", []).has(full_name):
			enabled += 1
	return {"total": total, "enabled": enabled}


func _is_domain_fully_enabled(model: Dictionary, categories: Array) -> bool:
	var counts = _count_categories(model, categories)
	return counts["total"] > 0 and counts["total"] == counts["enabled"]


func _is_category_fully_enabled(model: Dictionary, category: String) -> bool:
	var counts = _count_category(model, category)
	return counts["total"] > 0 and counts["total"] == counts["enabled"]


func _get_category_label(localization, category: String) -> String:
	var key = CATEGORY_LABEL_KEYS.get(category, category)
	var translated = localization.get_text(str(key))
	return translated if translated != key else category.capitalize()


func _get_category_label_key(category: String) -> String:
	return str(CATEGORY_LABEL_KEYS.get(category, category))


func _get_group_tooltip(localization, label_key: String) -> String:
	var desc_key = "%s_desc" % label_key
	var translated = localization.get_text(desc_key)
	return translated if translated != desc_key else ""


func _get_labeled_presentation_name(node: Dictionary) -> String:
	var label_key := str(node.get("labelKey", ""))
	if _localization != null and not label_key.is_empty():
		var translated = _localization.get_text(label_key)
		if translated != label_key:
			return translated
	var label := str(node.get("label", ""))
	if not label.is_empty():
		return _humanize_identifier(label)
	return _humanize_identifier(str(node.get("key", node.get("id", ""))))


func _normalize_presentation_kind(kind: String) -> String:
	match kind:
		"public_tool", "executor_tool", "legacy_tool":
			return "tool"
		"tool_group", "diagnostic_node":
			return "category"
		"executor_domain":
			return "domain"
		"executor_category":
			return "category"
	return kind


func _is_tool_like_presentation_kind(kind: String) -> bool:
	return ["tool", "public_tool", "executor_tool"].has(kind)


func _is_agent_tools_view() -> bool:
	return _active_tools_view == VIEW_AGENT_TOOLS


func _on_tool_view_button_pressed(view_id: String) -> void:
	var resolved_view := _resolve_tool_view_id(view_id)
	if resolved_view == _active_tools_view:
		_update_tool_view_buttons()
		return
	_active_tools_view = resolved_view
	_clear_selection_metadata()
	_last_tree_signature = ""
	_update_tool_view_buttons()
	tool_view_changed.emit(resolved_view)
	if not _current_model.is_empty():
		_apply_localized_copy(_localization, _current_model)
		_refresh_tree_state(_current_model, _build_tree_signature(_current_model))


func _resolve_tool_view_id(view_id: String) -> String:
	match view_id:
		VIEW_AGENT_TOOLS, VIEW_INTERNAL_EXECUTORS, VIEW_DIAGNOSTICS:
			return view_id
	return VIEW_AGENT_TOOLS


func _update_tool_view_buttons() -> void:
	for view_id in _view_buttons.keys():
		var button := _view_buttons.get(view_id) as Button
		if button == null:
			continue
		button.set_pressed_no_signal(str(view_id) == _active_tools_view)


func _presentation_for_view(view_id: String) -> Dictionary:
	var key := ""
	match _resolve_tool_view_id(view_id):
		VIEW_AGENT_TOOLS:
			key = "agent_tool_presentation"
		VIEW_INTERNAL_EXECUTORS:
			key = "internal_executor_presentation"
		VIEW_DIAGNOSTICS:
			key = "tool_diagnostics_presentation"
	var presentation = _current_model.get(key, {})
	if presentation is Dictionary and not (presentation as Dictionary).is_empty():
		return presentation as Dictionary
	return {}


func _active_tool_presentation() -> Dictionary:
	var selected_presentation := _presentation_for_view(_active_tools_view)
	if not selected_presentation.is_empty():
		return selected_presentation
	if not _is_agent_tools_view():
		return {}
	var active = _current_model.get("active_tool_presentation", {})
	if active is Dictionary and not (active as Dictionary).is_empty():
		return (active as Dictionary)
	var agent = _current_model.get("agent_tool_presentation", {})
	if agent is Dictionary and not (agent as Dictionary).is_empty():
		return (agent as Dictionary)
	var presentation = _current_model.get("tool_presentation", {})
	if presentation is Dictionary:
		return (presentation as Dictionary)
	return {}


func _get_tool_display_name(localization, full_name: String, tool_name: String) -> String:
	var key = "tool_%s_name" % full_name
	var translated = localization.get_text(key)
	return translated if translated != key else _humanize_identifier(tool_name)


func _get_tool_description(localization, full_name: String, tool_def: Dictionary) -> String:
	var key = "tool_%s_desc" % full_name
	var translated = localization.get_text(key)
	if translated != key:
		return translated
	return str(tool_def.get("description", ""))


func _get_action_display_name(parent_tool: String, action_name: String) -> String:
	return _get_action_display_name_from_metadata({}, parent_tool, action_name)


func _get_action_display_name_from_metadata(metadata: Dictionary, parent_tool: String, action_name: String) -> String:
	if _localization != null:
		var specific_key = str(metadata.get("labelKey", metadata.get("label_key", "")))
		if specific_key.is_empty():
			specific_key = ToolPresentationService.get_action_name_key(parent_tool, action_name)
		var translated = _localization.get_text(specific_key)
		if translated != specific_key:
			return translated
		var generic_key = ToolPresentationService.get_generic_action_name_key(action_name)
		translated = _localization.get_text(generic_key)
		if translated != generic_key:
			return translated
		var fallback_key = "tool_action_name_fallback"
		var fallback_template = _localization.get_text(fallback_key)
		if fallback_template != fallback_key:
			return fallback_template % _humanize_identifier(action_name)
	return _humanize_identifier(action_name)


func _get_action_description(parent_tool: String, action_name: String, tool_def: Dictionary) -> String:
	return _get_action_description_from_metadata({}, parent_tool, action_name, tool_def)


func _get_action_description_from_metadata(metadata: Dictionary, parent_tool: String, action_name: String, tool_def: Dictionary) -> String:
	var action_display_name = _get_action_display_name_from_metadata(metadata, parent_tool, action_name)
	var parent_display_name = parent_tool
	if not tool_def.is_empty():
		var tool_name = str(tool_def.get("name", ""))
		if not tool_name.is_empty():
			parent_display_name = _get_tool_display_name(_localization, parent_tool, tool_name)
	if _localization != null:
		var specific_key = str(metadata.get("descriptionKey", metadata.get("description_key", "")))
		if specific_key.is_empty():
			specific_key = ToolPresentationService.get_action_desc_key(parent_tool, action_name)
		var translated = _localization.get_text(specific_key)
		if translated != specific_key:
			return translated
		var generic_key = ToolPresentationService.get_generic_action_desc_key(action_name)
		translated = _localization.get_text(generic_key)
		if translated != generic_key:
			return translated
		var fallback_key = "tool_action_desc_fallback"
		var fallback_template = _localization.get_text(fallback_key)
		if fallback_template != fallback_key:
			var fallback_text = fallback_template % [action_display_name, parent_display_name]
			var tool_description = _get_tool_description(_localization, parent_tool, tool_def)
			if not tool_description.is_empty():
				fallback_text += "\n\n" + tool_description
			return fallback_text
	return ""


func _humanize_identifier(value: String) -> String:
	var parts: Array[String] = []
	for word in value.split("_"):
		if word.is_empty():
			continue
		parts.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(parts)


func _on_tree_item_collapsed(item: TreeItem) -> void:
	if _tree_syncing or item == null:
		return
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if not (metadata is Dictionary):
		return
	var kind = str(metadata.get("kind", ""))
	var key = str(metadata.get("key", ""))
	if key.is_empty():
		return
	tree_collapse_changed.emit(kind, key, item.collapsed)


func _on_search_text_changed(_new_text: String) -> void:
	if _current_model.is_empty():
		return
	_render_tool_tree(_current_model)
	_refresh_preview()
	if _has_tree_selection():
		_queue_selection_sync()


func _on_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_SPACE:
				var selected := _tool_tree.get_selected()
				if selected != null and selected.get_child_count() > 0:
					selected.collapsed = not selected.collapsed
					_on_tree_item_collapsed(selected)
					get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		var item = _tool_tree.get_item_at_position(mouse_event.position)
		if item != null:
			_show_tree_context_menu(item, _get_tree_context_menu_screen_position(mouse_event.position))
			get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.shift_pressed:
		var item: TreeItem = _tool_tree.get_item_at_position(mouse_event.position)
		if item != null and item.get_child_count() > 0:
			# gui_input fires BEFORE Tree's internal _gui_input(), so item.collapsed
			# is still the OLD state here. Toggle to opposite = desired new state.
			var want_collapsed: bool = not item.collapsed
			_tree_syncing = true
			_set_subtree_collapsed(item, want_collapsed)
			_tree_syncing = false
			_sync_subtree_collapsed_to_settings(item, want_collapsed)
			get_viewport().set_input_as_handled()
			return
	call_deferred("_handle_tree_click_deferred", mouse_event.position)


func _set_subtree_collapsed(item: TreeItem, collapsed: bool) -> void:
	item.collapsed = collapsed
	var child := item.get_first_child()
	while child != null:
		_set_subtree_collapsed(child, collapsed)
		child = child.get_next()


func _sync_subtree_collapsed_to_settings(item: TreeItem, want_collapsed: bool) -> void:
	if item == null:
		return
	_sync_item_collapsed_to_settings(item, want_collapsed)
	var child := item.get_first_child()
	while child != null:
		_sync_subtree_collapsed_to_settings(child, want_collapsed)
		child = child.get_next()


func _sync_item_collapsed_to_settings(item: TreeItem, want_collapsed: bool) -> void:
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if not (metadata is Dictionary):
		return
	var meta := metadata as Dictionary
	var kind := str(meta.get("kind", ""))
	var key := str(meta.get("key", ""))
	var settings: Dictionary = _current_model.get("settings", {})
	if key.is_empty() or not TreeCollapseState.EXPANDABLE_KINDS.has(kind):
		return
	var is_saved_collapsed: bool = TreeCollapseState.is_node_collapsed(settings, kind, key)
	if is_saved_collapsed != want_collapsed:
		tree_collapse_changed.emit(kind, key, want_collapsed)


func _show_tree_context_menu(item: TreeItem, screen_position: Vector2) -> Rect2i:
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if not (metadata is Dictionary):
		return Rect2i()
	var meta := metadata as Dictionary
	_context_menu_metadata = meta
	_context_menu_target = item
	_context_menu.clear()
	var kind = str(meta.get("kind", ""))
	var has_children := item.get_child_count() > 0
	_add_context_menu_item(_localization.get_text("tool_ctx_copy_localized_name"), _CTX_COPY_LOCALIZED_NAME)
	_add_context_menu_item(_localization.get_text("tool_ctx_copy_english_id"), _CTX_COPY_ENGLISH_ID)
	_context_menu.add_separator()
	_add_context_menu_item(_localization.get_text("btn_expand_all"), _CTX_EXPAND_ALL, not has_children)
	_add_context_menu_item(_localization.get_text("btn_collapse_all"), _CTX_COLLAPSE_ALL, not has_children)
	match kind:
		"tool":
			_context_menu.add_separator()
			_add_context_menu_item(_localization.get_text("tool_ctx_copy_input_schema_json"), _CTX_COPY_INPUT_SCHEMA)
			_add_context_menu_item(_localization.get_text("tool_ctx_copy_output_schema_json"), _CTX_COPY_OUTPUT_SCHEMA)
			if _is_user_tool_metadata(meta):
				_add_context_menu_item(_localization.get_text("btn_delete_user_tool"), _CTX_DELETE_TOOL)
		_:
			pass
	var popup_rect := _get_tree_context_menu_popup_rect(screen_position)
	_context_menu.popup(popup_rect)
	return popup_rect


func _get_tree_context_menu_screen_position(local_position: Vector2) -> Vector2:
	return _tool_tree.get_screen_transform() * local_position


func _get_tree_context_menu_popup_rect(screen_position: Vector2) -> Rect2i:
	return Rect2i(int(screen_position.x), int(screen_position.y), 0, 0)


func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		_CTX_COPY_LOCALIZED_NAME:
			DisplayServer.clipboard_set(_get_context_menu_localized_name())
		_CTX_COPY_ENGLISH_ID:
			DisplayServer.clipboard_set(_get_context_menu_english_id())
		_CTX_COPY_INPUT_SCHEMA:
			var full_name = str(_context_menu_metadata.get("key", ""))
			var tool_def = _get_tool_metadata(full_name, _context_menu_metadata)
			var schema = tool_def.get("inputSchema", {})
			DisplayServer.clipboard_set(JSON.stringify(schema, "\t"))
		_CTX_COPY_OUTPUT_SCHEMA:
			var full_name = str(_context_menu_metadata.get("key", ""))
			var tool_def = _get_tool_metadata(full_name, _context_menu_metadata)
			var schema = tool_def.get("outputSchema", {})
			DisplayServer.clipboard_set(JSON.stringify(schema, "\t"))
		_CTX_DELETE_TOOL:
			var script_path = _get_context_menu_user_tool_script_path()
			if not script_path.is_empty():
				delete_user_tool_requested.emit(script_path)
		_CTX_EXPAND_ALL:
			if is_instance_valid(_context_menu_target):
				_tree_syncing = true
				_set_subtree_collapsed(_context_menu_target, false)
				_tree_syncing = false
				_sync_subtree_collapsed_to_settings(_context_menu_target, false)
		_CTX_COLLAPSE_ALL:
			if is_instance_valid(_context_menu_target):
				_tree_syncing = true
				_set_subtree_collapsed(_context_menu_target, true)
				_tree_syncing = false
				_sync_subtree_collapsed_to_settings(_context_menu_target, true)


func _add_context_menu_item(label: String, id: int, disabled: bool = false) -> void:
	var index := _context_menu.get_item_count()
	_context_menu.add_item(label, id)
	_context_menu.set_item_disabled(index, disabled)


func _build_tree_node_metadata(kind: String, key: String, localized_name: String = "", english_id: String = "", extra: Dictionary = {}) -> Dictionary:
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


func _duplicate_dictionary(value) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _duplicate_array(value) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _get_context_menu_localized_name() -> String:
	var localized_name := str(_context_menu_metadata.get("localized_name", ""))
	if not localized_name.is_empty():
		return localized_name
	return str(_context_menu_metadata.get("key", ""))


func _get_context_menu_english_id() -> String:
	var english_id := str(_context_menu_metadata.get("english_id", ""))
	if not english_id.is_empty():
		return english_id
	return str(_context_menu_metadata.get("key", ""))


func _is_user_tool_metadata(meta: Dictionary) -> bool:
	if str(meta.get("category", "")) != "user":
		return false
	var script_path = str(meta.get("script_path", ""))
	return str(meta.get("source", "")) == "user_tool" and script_path.begins_with(USER_TOOL_CUSTOM_ROOT + "/")


func _get_context_menu_user_tool_script_path() -> String:
	var direct_path = str(_context_menu_metadata.get("script_path", ""))
	if direct_path.begins_with(USER_TOOL_CUSTOM_ROOT + "/"):
		return direct_path
	return ""


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale
	add_theme_constant_override("separation", int(round(8 * scale)))
	_apply_visual_style(scale)
	_apply_spacing(scale)

	_tool_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Tree content scrolls internally, so its minimum height must stay low enough
	# for the split container to keep search, divider and preview from overlapping.
	_tool_tree.custom_minimum_size.y = 96.0 * scale
	_tool_tree.custom_minimum_size.x = 0.0
	_tool_tree.set_column_expand(TREE_TEXT_COLUMN, true)
	_tool_tree.set_column_expand(TREE_CHECK_COLUMN, false)
	_apply_responsive_layout()
	_tool_preview_panel.custom_minimum_size.y = 148.0 * scale
	var desired_split := 560.0 * scale
	if size.y > 0.0:
		desired_split = max(420.0 * scale, size.y * 0.62)
	_content_split.split_offset = int(round(desired_split))

	_search_edit.custom_minimum_size.y = 0.0
	_tool_count_label.remove_theme_font_size_override("font_size")
	_tool_preview_title.remove_theme_font_size_override("font_size")
	_tool_preview_text.remove_theme_font_size_override("font_size")


func _apply_responsive_layout() -> void:
	if _tool_tree == null:
		return
	var scale: float = _current_scale if _current_scale > 0.0 else 1.0
	var available_width: float = size.x
	if available_width <= 0.0:
		var parent_control := get_parent() as Control
		if parent_control != null:
			available_width = parent_control.size.x
	var check_width: float = min(max(TREE_CHECK_MIN_WIDTH * scale, 32.0 * scale), TREE_CHECK_MAX_WIDTH * scale)
	var tree_width: float = max(available_width - TREE_HORIZONTAL_CHROME_WIDTH * scale, (TREE_TEXT_MIN_WIDTH + TREE_CHECK_MIN_WIDTH) * scale)
	var text_width: float = min(max(tree_width - check_width, TREE_TEXT_MIN_WIDTH * scale), TREE_TEXT_MAX_WIDTH * scale)
	_tool_tree.set_column_custom_minimum_width(TREE_TEXT_COLUMN, int(round(text_width)))
	_tool_tree.set_column_custom_minimum_width(TREE_CHECK_COLUMN, int(round(check_width)))
	var narrow := available_width > 0.0 and available_width < 360.0 * scale
	_view_mode_row.add_theme_constant_override("separation", int(round((4.0 if narrow else 6.0) * scale)))
	_configure_view_mode_button(_agent_tools_button, VIEW_AGENT_TOOLS, 76.0 if narrow else 96.0, scale)
	_configure_view_mode_button(_internal_executors_button, VIEW_INTERNAL_EXECUTORS, 70.0 if narrow else 92.0, scale)
	_configure_view_mode_button(_diagnostics_button, VIEW_DIAGNOSTICS, 78.0 if narrow else 96.0, scale)


func _configure_view_mode_button(button: Button, view: String, min_width: float, scale: float) -> void:
	if button == null:
		return
	button.custom_minimum_size.x = min_width * scale
	button.tooltip_text = button.text if not button.text.strip_edges().is_empty() else view


func _refresh_view_button_tooltips() -> void:
	_configure_view_button_tooltip(_agent_tools_button, VIEW_AGENT_TOOLS)
	_configure_view_button_tooltip(_internal_executors_button, VIEW_INTERNAL_EXECUTORS)
	_configure_view_button_tooltip(_diagnostics_button, VIEW_DIAGNOSTICS)


func _configure_view_button_tooltip(button: Button, view: String) -> void:
	if button == null:
		return
	button.tooltip_text = button.text if not button.text.strip_edges().is_empty() else view


func _on_resized() -> void:
	_apply_responsive_layout()


func _apply_spacing(scale: float) -> void:
	_set_margin_constants(_content_split.get_node_or_null("TopPane/SearchOuterMargin") as MarginContainer, 10, 8, 10, 6, scale)
	_set_margin_constants(_content_split.get_node_or_null("TopPane/ToolListOuterMargin") as MarginContainer, 10, 4, 10, 6, scale)
	_set_margin_constants(_content_split.get_node_or_null("TopPane/ToolListOuterMargin/ToolListPanel/ToolListOverlay/ToolListMargin") as MarginContainer, 0, 6, 0, 6, scale)
	_set_margin_constants(_content_split.get_node_or_null("BottomPane/PreviewOuterMargin") as MarginContainer, 10, 2, 10, 6, scale)
	_set_margin_constants(_content_split.get_node_or_null("BottomPane/PreviewOuterMargin/ToolPreviewPanel/ToolPreviewMargin") as MarginContainer, 0, 2, 0, 12, scale)


func _set_margin_constants(margin: MarginContainer, left: int, top: int, right: int, bottom: int, scale: float) -> void:
	if margin == null:
		return
	margin.add_theme_constant_override("margin_left", int(round(left * scale)))
	margin.add_theme_constant_override("margin_top", int(round(top * scale)))
	margin.add_theme_constant_override("margin_right", int(round(right * scale)))
	margin.add_theme_constant_override("margin_bottom", int(round(bottom * scale)))


func _apply_visual_style(scale: float) -> void:
	begin_bulk_theme_override()
	_header_card.add_theme_stylebox_override("panel", _make_theme_style("panel", "PanelContainer", 0, 0))
	_tool_list_panel.add_theme_stylebox_override("panel", _make_theme_style("panel", "Tree", 0, 0))
	_tool_preview_panel.add_theme_stylebox_override("panel", _make_theme_style("panel", "PanelContainer", 0, 0))
	_search_edit.add_theme_stylebox_override("normal", _make_theme_style("normal", "LineEdit", 10, 6))
	_search_edit.add_theme_stylebox_override("focus", _make_theme_style("focus", "LineEdit", 10, 6))
	_tool_count_label.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
	_tool_count_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_search_edit.add_theme_color_override("font_color", get_theme_color("font_color", "LineEdit"))
	_search_edit.add_theme_color_override("font_placeholder_color", _get_muted_text_color())
	_tool_tree.add_theme_color_override("font_color", get_theme_color("font_color", "Tree"))
	_tool_tree.add_theme_color_override("font_selected_color", get_theme_color("font_selected_color", "Tree"))
	_tool_tree.add_theme_color_override("guide_color", _get_muted_text_color())
	_tool_tree.remove_theme_constant_override("v_separation")
	_tool_preview_title.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
	_tool_preview_text.add_theme_color_override("font_color", get_theme_color("font_color", "TextEdit"))
	_tool_preview_text.add_theme_color_override("font_readonly_color", get_theme_color("font_readonly_color", "TextEdit"))
	_tool_preview_text.add_theme_stylebox_override("normal", _make_theme_style("normal", "TextEdit", 8, 6))
	_tool_preview_text.add_theme_stylebox_override("focus", _make_theme_style("focus", "TextEdit", 8, 6))
	_tool_preview_text.add_theme_stylebox_override("read_only", _make_theme_style("read_only", "TextEdit", 8, 6))
	_tool_preview_text.remove_theme_constant_override("line_spacing")
	end_bulk_theme_override()


func _make_theme_style(style_name: String, theme_type: String, horizontal_margin: int, vertical_margin: int) -> StyleBox:
	var style := get_theme_stylebox(style_name, theme_type).duplicate() as StyleBox
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style


func _get_muted_text_color() -> Color:
	return get_theme_color("font_disabled_color", "Editor")


func _get_dim_text_color() -> Color:
	return get_theme_color("font_disabled_color", "Editor")


func _get_error_text_color() -> Color:
	return get_theme_color("error_color", "Editor")


func _category_matches_search(model: Dictionary, category: String) -> bool:
	var query = _get_search_query()
	if query.is_empty():
		return true
	var category_matches = _get_category_label(model.get("localization"), category).to_lower().contains(query)
	if category_matches:
		return true
	for tool_def in model.get("tools_by_category", {}).get(category, []):
		if _matches_tool_search(model, category, tool_def, query, category_matches):
			return true
	return false


func _get_filtered_tool_definitions(model: Dictionary, category: String) -> Array:
	var filtered: Array = []
	var query = _get_search_query()
	var category_matches = _get_category_label(model.get("localization"), category).to_lower().contains(query)
	for tool_def in model.get("tools_by_category", {}).get(category, []):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		if _matches_tool_search(model, category, tool_def, query, category_matches):
			filtered.append(tool_def)
	return filtered


func _matches_tool_search(model: Dictionary, category: String, tool_def: Dictionary, query: String, category_matches: bool = false) -> bool:
	if bool(tool_def.get("compatibility_alias", false)):
		return false
	if query.is_empty() or category_matches:
		return true
	var localization = model.get("localization")
	var tool_name = str(tool_def.get("name", ""))
	var full_name = "%s_%s" % [category, tool_name]
	if _get_tool_display_name(localization, full_name, tool_name).to_lower().contains(query):
		return true
	if _get_tool_description(localization, full_name, tool_def).to_lower().contains(query):
		return true
	for action_name in _extract_action_values(tool_def):
		if _matches_action_search(full_name, str(action_name), tool_def):
			return true
	if category != SYSTEM_CATEGORY:
		return false
	return _matches_atomic_tool_search_recursive(model, full_name, {})


func _matches_atomic_tool_search(model: Dictionary, atomic_full_name: String, atomic_tool_def: Dictionary) -> bool:
	var query = _get_search_query()
	if query.is_empty():
		return true
	var localization = model.get("localization")
	var tool_name = str(atomic_tool_def.get("name", ""))
	if _get_tool_display_name(localization, atomic_full_name, tool_name).to_lower().contains(query):
		return true
	var description = _get_tool_description(localization, atomic_full_name, atomic_tool_def)
	return description.to_lower().contains(query)


func _matches_atomic_tool_or_action_search(model: Dictionary, atomic_full_name: String, atomic_tool_def: Dictionary, actions: Array) -> bool:
	if _matches_atomic_tool_search(model, atomic_full_name, atomic_tool_def):
		return true
	for action_name in actions:
		if _matches_action_search(atomic_full_name, str(action_name), atomic_tool_def):
			return true
	return false


func _matches_action_search(parent_tool: String, action_name: String, tool_def: Dictionary) -> bool:
	var query = _get_search_query()
	if query.is_empty():
		return true
	if _get_action_display_name(parent_tool, action_name).to_lower().contains(query):
		return true
	if action_name.to_lower().contains(query):
		return true
	var description = _get_action_description(parent_tool, action_name, tool_def)
	return description.to_lower().contains(query)


func _matches_atomic_tool_search_recursive(model: Dictionary, system_full_name: String, visited: Dictionary) -> bool:
	for entry in ToolPresentationService.get_atomic_child_specs(system_full_name):
		var atomic_full_name := str(entry.get("tool", ""))
		var actions: Array = entry.get("actions", [])
		if atomic_full_name.is_empty() or visited.has(atomic_full_name):
			continue
		var atomic_tool_def = _get_tool_def_by_full_name(model, atomic_full_name)
		if atomic_tool_def.is_empty():
			continue
		if _matches_atomic_tool_search(model, atomic_full_name, atomic_tool_def):
			return true
		for action_name in actions:
			if _matches_action_search(atomic_full_name, str(action_name), atomic_tool_def):
				return true
		var next_visited = visited.duplicate()
		next_visited[atomic_full_name] = true
		if _matches_atomic_tool_search_recursive(model, atomic_full_name, next_visited):
			return true
	return false


func _get_search_query() -> String:
	return _search_edit.text.strip_edges().to_lower()


func _get_category_load_error_messages(model: Dictionary, category: String) -> Array[String]:
	var messages: Array[String] = []
	for error_info in model.get("tool_load_errors", []):
		if not (error_info is Dictionary):
			continue
		var info := error_info as Dictionary
		if str(info.get("category", "")) != category:
			continue
		messages.append(str(info.get("message", "Tool domain load failed")))
	return messages


func _apply_selection_metadata(metadata) -> void:
	_clear_selection_metadata()
	if metadata is Dictionary:
		var metadata_dict := metadata as Dictionary
		_selected_tree_metadata = metadata_dict.duplicate(true)
		_selected_tree_kind = str(metadata_dict.get("kind", ""))
		_selected_tree_key = str(metadata_dict.get("key", ""))
		_selected_tool_category = str(metadata_dict.get("category", ""))
		_selected_tool_name = str(metadata_dict.get("tool_name", ""))
	_refresh_preview()


func _clear_selection_metadata() -> void:
	_selected_tree_kind = ""
	_selected_tree_key = ""
	_selected_tool_category = ""
	_selected_tool_name = ""
	_selected_tree_metadata = {}
	_last_preview_key = ""


func _restore_tree_selection() -> void:
	if _selected_tree_kind.is_empty() or _selected_tree_key.is_empty():
		return
	var root = _tool_tree.get_root()
	if root == null:
		return
	var item = _find_item_by_selection(root)
	if item == null:
		_clear_selection_metadata()
		_refresh_preview()
		return
	_tool_tree.set_selected(item, TREE_TEXT_COLUMN)
	_apply_selection_metadata(item.get_metadata(TREE_TEXT_COLUMN))


func _queue_selection_sync() -> void:
	if _selection_sync_queued:
		return
	_selection_sync_queued = true
	call_deferred("_restore_tree_selection_deferred")


func _restore_tree_selection_deferred() -> void:
	_selection_sync_queued = false
	_restore_tree_selection()


func _handle_tree_click_deferred(mouse_position: Vector2) -> void:
	var column = _tool_tree.get_column_at_position(mouse_position)
	if column < 0:
		return
	var item = _tool_tree.get_item_at_position(mouse_position)
	if item == null:
		return
	if column == TREE_TEXT_COLUMN:
		_apply_selection_metadata(item.get_metadata(TREE_TEXT_COLUMN))
		return
	if column == TREE_CHECK_COLUMN:
		_emit_toggle_for_item(item)


func _emit_toggle_for_item(item: TreeItem) -> void:
	if not _is_agent_tools_view():
		return
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if not (metadata is Dictionary):
		return
	var enabled = item.is_checked(TREE_CHECK_COLUMN)
	match str(metadata.get("kind", "")):
		"domain":
			domain_toggled.emit(str(metadata.get("key", "")), enabled)
		"category":
			category_toggled.emit(str(metadata.get("key", "")), enabled)
		"tool":
			tool_toggled.emit(str(metadata.get("key", "")), enabled)


func _has_tree_selection() -> bool:
	return not _selected_tree_kind.is_empty() and not _selected_tree_key.is_empty()


func _find_item_by_selection(item: TreeItem) -> TreeItem:
	if item == null:
		return null
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if metadata is Dictionary:
		var metadata_dict := metadata as Dictionary
		if str(metadata_dict.get("kind", "")) == _selected_tree_kind and str(metadata_dict.get("key", "")) == _selected_tree_key:
			return item

	var child = item.get_first_child()
	while child != null:
		var found = _find_item_by_selection(child)
		if found != null:
			return found
		child = child.get_next()
	return null


func _refresh_preview() -> void:
	if _localization == null:
		return
	_tool_preview_title.text = _localization.get_text("tool_preview_title")
	# Build a key representing the current selection to detect changes
	var current_preview_key := "%s|%s|%s|%s" % [_active_tools_view, _selected_tree_kind, _selected_tree_key, _selected_tool_name]
	var selection_changed := current_preview_key != _last_preview_key
	_last_preview_key = current_preview_key
	# Preserve scroll position when re-rendering without a selection change
	var saved_v_scroll: int = 0
	if not selection_changed:
		saved_v_scroll = int(_tool_preview_text.get_v_scroll())
	_tool_preview_text.clear()
	_tool_preview_text.set_text(_build_preview_text())
	_tool_preview_text.set_v_scroll(saved_v_scroll)


func _build_preview_text() -> String:
	if _selected_tree_kind.is_empty() or _selected_tree_key.is_empty():
		return str(_localization.get_text("tool_preview_empty"))

	match _selected_tree_kind:
		"domain":
			return _build_domain_preview()
		"root":
			return _build_category_preview()
		"category":
			return _build_category_preview()
		"tool":
			return _build_tool_preview()
		"atomic":
			return _build_atomic_item_preview()
		"action":
			return _build_action_item_preview()
		_:
			return str(_localization.get_text("tool_preview_empty"))


func _build_domain_preview() -> String:
	var domain_def = _find_domain_definition(_selected_tree_key)
	var domain_node := _find_presentation_node("domain", _selected_tree_key) if _has_presentation_tree(_current_model) else {}
	if domain_def.is_empty() and domain_node.is_empty():
		return str(_localization.get_text("tool_preview_empty"))

	var label_key = str(domain_node.get("labelKey", domain_def.get("label", "domain_other")))
	var categories: Array = _get_presentation_domain_category_keys(_selected_tree_key)
	if categories.is_empty():
		categories = domain_def.get("categories", [])
	var lines: Array[String] = [
		"%s: %s" % [_localization.get_text("tool_preview_domain"), _localization.get_text(label_key)],
		"",
		_get_group_tooltip(_localization, label_key),
		"",
		_localization.get_text("tool_preview_category_count") % categories.size()
	]
	for category in categories:
		lines.append("- %s" % _get_category_label(_localization, str(category)))
	return "\n".join(_filter_empty_preview_lines(lines))


func _build_category_preview() -> String:
	var category = _selected_tree_key
	var presentation_tools: Array = _get_presentation_category_tool_metadata(category)
	var tools: Array = presentation_tools if _has_presentation_tree(_current_model) else _get_filtered_tool_definitions(_current_model, category)
	var lines: Array[String] = [
		"%s: %s" % [_localization.get_text("tool_preview_category"), _get_category_label(_localization, category)],
		"",
		_get_group_tooltip(_localization, _get_category_label_key(category)),
		"",
		_localization.get_text("tool_preview_tool_count") % _count_previewable_tools(tools)
	]
	for tool_def in tools:
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		var full_name = str(tool_def.get("fullName", tool_def.get("full_name", "")))
		var tool_name = str(tool_def.get("toolName", tool_def.get("tool_name", tool_def.get("name", ""))))
		if full_name.is_empty():
			full_name = "%s_%s" % [category, tool_name]
		lines.append("- %s" % _get_tool_display_name(_localization, full_name, tool_name))
	if category == "user":
		var watch_lines = _build_user_watch_preview_lines()
		if not watch_lines.is_empty():
			lines.append("")
			lines.append(_localization.get_text("tool_preview_watch_section"))
			lines.append_array(watch_lines)
	if category == "system":
		lines.append("")
		var hint_key = "tool_preview_system_category_hint"
		var hint_text = _localization.get_text(hint_key)
		lines.append(hint_text)
	return "\n".join(_filter_empty_preview_lines(lines))


func _get_presentation_domain_category_keys(domain_key: String) -> Array:
	if not _has_presentation_tree(_current_model):
		return []
	var domain_node := _find_presentation_node("domain", domain_key)
	if domain_node.is_empty():
		return []
	var categories: Array = []
	for child in domain_node.get("children", []):
		if not (child is Dictionary):
			continue
		var child_dict := child as Dictionary
		if _normalize_presentation_kind(str(child_dict.get("kind", ""))) != "category":
			continue
		var category_key := str(child_dict.get("category", child_dict.get("key", "")))
		if not category_key.is_empty():
			categories.append(category_key)
	return categories


func _get_presentation_category_tool_metadata(category: String) -> Array:
	if not _has_presentation_tree(_current_model):
		return []
	var category_node := _find_presentation_node("category", category)
	if category_node.is_empty():
		return []
	var tools: Array = []
	for child in category_node.get("children", []):
		if not (child is Dictionary):
			continue
		var child_dict := child as Dictionary
		if not _is_tool_like_presentation_kind(str(child_dict.get("kind", ""))):
			continue
		var full_name := str(child_dict.get("fullName", child_dict.get("key", "")))
		var metadata := _get_tool_metadata(full_name, child_dict)
		if not metadata.is_empty():
			tools.append(metadata)
	return tools


func _find_presentation_node(kind: String, key: String) -> Dictionary:
	for node in _active_tool_presentation().get("toolTree", []):
		if not (node is Dictionary):
			continue
		var found := _find_presentation_node_recursive(node as Dictionary, kind, key)
		if not found.is_empty():
			return found
	return {}


func _find_presentation_node_recursive(node: Dictionary, kind: String, key: String) -> Dictionary:
	var node_kind := str(node.get("kind", ""))
	if node_kind == kind or _normalize_presentation_kind(node_kind) == kind:
		var node_key := str(node.get("key", node.get("id", "")))
		var category_key := str(node.get("category", ""))
		if node_key == key or category_key == key:
			return node
	for child in node.get("children", []):
		if not (child is Dictionary):
			continue
		var found := _find_presentation_node_recursive(child as Dictionary, kind, key)
		if not found.is_empty():
			return found
	return {}


func _build_tool_preview() -> String:
	var category = _selected_tool_category
	var tool_name = _selected_tool_name
	if category.is_empty() or tool_name.is_empty():
		return str(_localization.get_text("tool_preview_empty"))
	var tool_def = _get_tool_metadata(_selected_tree_key)
	if tool_def.is_empty():
		return str(_localization.get_text("tool_preview_empty"))

	var display_name = _get_tool_display_name(_localization, _selected_tree_key, tool_name)
	var description = _get_tool_description(_localization, _selected_tree_key, tool_def)
	var lines: Array[String] = [
		"%s: %s" % [_localization.get_text("tool_preview_tool"), display_name],
		"%s: %s" % [_localization.get_text("tool_preview_tool_id"), _selected_tree_key],
		"%s: %s" % [_localization.get_text("tool_preview_category"), _get_category_label(_localization, category)],
		"",
		_localization.get_text("tool_preview_description"),
		description if not description.is_empty() else _localization.get_text("tool_preview_no_description")
	]

	var actions = _extract_action_values(tool_def)
	if not actions.is_empty():
		lines.append("")
		lines.append(_localization.get_text("tool_preview_actions"))
		for action_value in actions:
			lines.append("- %s" % _get_action_display_name(_selected_tree_key, action_value))

	lines.append("")
	lines.append(_localization.get_text("tool_preview_params"))
	var parameter_lines = _build_parameter_preview_lines(tool_def, _selected_tree_key)
	if parameter_lines.is_empty():
		lines.append(_localization.get_text("tool_preview_no_params"))
	else:
		lines.append_array(parameter_lines)

	lines.append("")
	lines.append(_localization.get_text("tool_preview_output"))
	var output_lines = _build_output_preview_lines(tool_def)
	if output_lines.is_empty():
		lines.append(_localization.get_text("tool_preview_no_output"))
	else:
		lines.append_array(output_lines)

	if category == "user":
		var runtime_lines = _build_user_runtime_preview_lines(tool_def)
		if not runtime_lines.is_empty():
			lines.append("")
			lines.append(_localization.get_text("tool_preview_runtime_section"))
			lines.append_array(runtime_lines)

	if category == "system":
		lines.append("")
		lines.append(_localization.get_text("tool_preview_atomic_tools"))
		var atomic_lines = _build_atomic_tool_preview_lines(_selected_tree_key, 0, {})
		if atomic_lines.is_empty():
			lines.append(_localization.get_text("tool_preview_no_atomic_tools"))
		else:
			lines.append_array(atomic_lines)
		lines.append("")
		var hint_key = "tool_preview_system_tool_hint"
		var hint_text = _localization.get_text(hint_key)
		lines.append(hint_text)

	return "\n".join(_filter_empty_preview_lines(lines))


func _build_user_runtime_preview_lines(tool_def: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var runtime_domain = str(tool_def.get("runtime_domain", ""))
	if not runtime_domain.is_empty():
		lines.append("%s: %s" % [_localization.get_text("tool_preview_runtime_domain"), runtime_domain])
	var runtime_version = int(tool_def.get("runtime_version", 0))
	if runtime_version > 0:
		lines.append("%s: %d" % [_localization.get_text("tool_preview_runtime_version"), runtime_version])
	var runtime_state = _get_user_runtime_state_label(str(tool_def.get("state", "")))
	if not runtime_state.is_empty():
		lines.append("%s: %s" % [_localization.get_text("tool_preview_runtime_state"), runtime_state])
	lines.append("%s: %s" % [
		_localization.get_text("tool_preview_pending_reload"),
		_localization.get_text("status_enabled") if bool(tool_def.get("pending_reload", false)) else _localization.get_text("status_disabled")
	])
	var discovery_source = _get_user_watch_source_label(str(tool_def.get("discovery_source", "")))
	if not discovery_source.is_empty():
		lines.append("%s: %s" % [_localization.get_text("tool_preview_discovery_source"), discovery_source])
	var last_refresh_reason = _get_user_watch_reason_label(str(tool_def.get("last_refresh_reason", "")))
	if not last_refresh_reason.is_empty():
		lines.append("%s: %s" % [_localization.get_text("tool_preview_last_refresh_reason"), last_refresh_reason])
	var script_path = str(tool_def.get("script_path", ""))
	if not script_path.is_empty():
		lines.append("%s: %s" % [_localization.get_text("tool_preview_script_path"), script_path])
	var last_error = str(tool_def.get("last_error", ""))
	if not last_error.is_empty():
		lines.append("%s: %s" % [_localization.get_text("tool_preview_last_error"), last_error])
	var raw_state = str(tool_def.get("state", ""))
	if raw_state == "reload_failed":
		lines.append(_localization.get_text("tool_preview_reload_failed_keeps_old_version"))
	elif raw_state == "waiting_quiesce":
		lines.append(_localization.get_text("tool_preview_waiting_quiesce"))
	return lines


func _build_user_watch_preview_lines() -> Array[String]:
	var lines: Array[String] = []
	var watch_status: Dictionary = _current_model.get("user_tool_watch", {})
	if not watch_status.is_empty():
		var watching = bool(watch_status.get("watching", false))
		lines.append("%s: %s" % [
			_localization.get_text("tool_preview_watch_status"),
			_localization.get_text("status_enabled") if watching else _localization.get_text("status_disabled")
		])
		lines.append("%s: %d" % [
			_localization.get_text("tool_preview_watch_known_scripts"),
			int(watch_status.get("known_script_count", 0))
		])
		var last_reason = _get_user_watch_reason_label(str(watch_status.get("last_change_reason", "")))
		if not last_reason.is_empty():
			lines.append("%s: %s" % [_localization.get_text("tool_preview_last_refresh_reason"), last_reason])
		var last_error = str(watch_status.get("last_error", ""))
		if not last_error.is_empty():
			lines.append("%s: %s" % [_localization.get_text("tool_preview_watch_last_error"), last_error])
	var invalid_tools: Array[String] = []
	for tool_info in _current_model.get("user_tools", []):
		if not (tool_info is Dictionary):
			continue
		var info := tool_info as Dictionary
		if bool(info.get("loadable", false)):
			continue
		var display_name = str(info.get("display_name", info.get("script_path", "")))
		var load_error = str(info.get("load_error", ""))
		invalid_tools.append("%s (%s)" % [display_name, load_error if not load_error.is_empty() else "invalid"])
	if not invalid_tools.is_empty():
		lines.append("%s: %d" % [_localization.get_text("tool_preview_watch_invalid_scripts"), invalid_tools.size()])
		for invalid_entry in invalid_tools:
			lines.append("- %s" % invalid_entry)
	return lines


func _get_user_runtime_state_label(state: String) -> String:
	if state.is_empty():
		return ""
	var key = "tool_preview_runtime_state_%s" % state
	var translated = _localization.get_text(key)
	if translated != key:
		return translated
	return _humanize_identifier(state)


func _get_user_watch_source_label(source: String) -> String:
	if source.is_empty():
		return ""
	var key = "tool_preview_discovery_source_%s" % source
	var translated = _localization.get_text(key)
	if translated != key:
		return translated
	return _humanize_identifier(source)


func _get_user_watch_reason_label(reason: String) -> String:
	if reason.is_empty():
		return ""
	var key = "tool_preview_watch_reason_%s" % reason
	var translated = _localization.get_text(key)
	if translated != key:
		return translated
	return _humanize_identifier(reason)


func _build_atomic_item_preview() -> String:
	var atomic_full_name = _selected_tree_key
	if atomic_full_name.is_empty():
		return str(_localization.get_text("tool_preview_empty"))
	var tool_def = _get_tool_metadata(atomic_full_name)
	if tool_def.is_empty():
		return str(_localization.get_text("tool_preview_empty"))
	var category = str(tool_def.get("category", _extract_category_from_full_name(_current_model, atomic_full_name)))
	var tool_name = str(tool_def.get("toolName", tool_def.get("name", _tool_name_from_full_name(atomic_full_name, tool_def))))
	var display_name = _get_tool_display_name(_localization, atomic_full_name, tool_name)
	var description = _get_tool_description(_localization, atomic_full_name, tool_def)
	var actions = _extract_action_values(tool_def)
	var lines: Array[String] = [
		"%s: %s" % [_localization.get_text("tool_preview_tool"), display_name],
		"%s: %s" % [_localization.get_text("tool_preview_tool_id"), atomic_full_name],
		"%s: %s" % [_localization.get_text("tool_preview_category"), _get_category_label(_localization, category)],
		"",
		_localization.get_text("tool_preview_description"),
		description if not description.is_empty() else _localization.get_text("tool_preview_no_description"),
	]
	if not actions.is_empty():
		lines.append("")
		lines.append(_localization.get_text("tool_preview_actions"))
		for action_value in actions:
			lines.append("- %s" % _get_action_display_name(atomic_full_name, action_value))
	lines.append("")
	lines.append(_localization.get_text("tool_preview_params"))
	var parameter_lines = _build_parameter_preview_lines(tool_def, atomic_full_name)
	if parameter_lines.is_empty():
		lines.append(_localization.get_text("tool_preview_no_params"))
	else:
		lines.append_array(parameter_lines)
	lines.append("")
	lines.append(_localization.get_text("tool_preview_output"))
	var output_lines = _build_output_preview_lines(tool_def)
	if output_lines.is_empty():
		lines.append(_localization.get_text("tool_preview_no_output"))
	else:
		lines.append_array(output_lines)
	return "\n".join(_filter_empty_preview_lines(lines))


func _build_action_item_preview() -> String:
	var key = _selected_tree_key
	if key.is_empty():
		return str(_localization.get_text("tool_preview_empty"))
	var dot_idx = key.rfind(".")
	if dot_idx < 0:
		return str(_localization.get_text("tool_preview_empty"))
	var parent_tool: String = key.left(dot_idx)
	var action_name: String = key.substr(dot_idx + 1)
	var action_metadata := _context_for_selected_action()
	var tool_def = _get_tool_metadata(parent_tool)
	var category = str(tool_def.get("category", _extract_category_from_full_name(_current_model, parent_tool)))
	var tool_name = str(tool_def.get("toolName", tool_def.get("name", ""))) if not tool_def.is_empty() else parent_tool
	var display_name = _get_tool_display_name(_localization, parent_tool, tool_name) if not tool_def.is_empty() else parent_tool
	var lines: Array[String] = [
		"%s: %s" % [_localization.get_text("tool_action"), _get_action_display_name_from_metadata(action_metadata, parent_tool, action_name)],
		"%s: %s" % [_localization.get_text("tool_preview_action_id"), action_name],
		"%s: %s" % [_localization.get_text("tool_preview_parent_tool"), display_name],
		"%s: %s" % [_localization.get_text("tool_preview_category"), _get_category_label(_localization, category)],
		"",
		_localization.get_text("tool_preview_description"),
		_get_action_description_from_metadata(action_metadata, parent_tool, action_name, tool_def),
	]
	if not tool_def.is_empty():
		var param_lines = _build_action_parameter_lines(tool_def, parent_tool)
		if not param_lines.is_empty():
			lines.append("")
			lines.append(_localization.get_text("tool_preview_params"))
			lines.append_array(param_lines)
	return "\n".join(_filter_empty_preview_lines(lines))


func _context_for_selected_action() -> Dictionary:
	if str(_selected_tree_metadata.get("kind", "")) != "action":
		return {}
	return _selected_tree_metadata.duplicate(true)


func _build_action_parameter_lines(tool_def: Dictionary, full_name: String) -> Array[String]:
	var input_schema = tool_def.get("inputSchema", {})
	if not (input_schema is Dictionary):
		return []
	var properties = (input_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return []
	var required_lookup: Dictionary = {}
	for required_name in (input_schema as Dictionary).get("required", []):
		required_lookup[str(required_name)] = true
	var property_names: Array = (properties as Dictionary).keys()
	property_names.sort()
	var lines: Array[String] = []
	for property_name in property_names:
		if property_name == "action":
			continue
		var property_def = (properties as Dictionary).get(property_name, {})
		if not (property_def is Dictionary):
			continue
		lines.append("- %s" % _format_parameter_summary(str(property_name), property_def as Dictionary, required_lookup, full_name))
	return lines


func _find_domain_definition(domain_key: String) -> Dictionary:
	for domain_def in _current_model.get("domain_defs", []):
		if str(domain_def.get("key", "")) == domain_key:
			return (domain_def as Dictionary).duplicate(true)
	if domain_key == "other":
		return {
			"key": "other",
			"label": "domain_other",
			"categories": []
		}
	return {}


func _get_tool_metadata(full_name: String, fallback: Dictionary = {}) -> Dictionary:
	var presentation = _active_tool_presentation()
	var metadata_by_name = (presentation as Dictionary).get("toolMetadataByName", {}) if presentation is Dictionary else {}
	var metadata: Dictionary = {}
	var has_shared_metadata := false
	if metadata_by_name is Dictionary and (metadata_by_name as Dictionary).has(full_name):
		var shared_metadata = (metadata_by_name as Dictionary).get(full_name, {})
		if shared_metadata is Dictionary:
			metadata = (shared_metadata as Dictionary).duplicate(true)
			has_shared_metadata = true
	if metadata.is_empty() and not fallback.is_empty():
		metadata = fallback.duplicate(true)
	if metadata.is_empty() and not _has_presentation_tree(_current_model):
		metadata = _get_tool_def_by_full_name(_current_model, full_name)
	elif not has_shared_metadata:
		_merge_missing_tool_runtime_fields(metadata, _get_tool_def_by_full_name(_current_model, full_name))
	if not metadata.has("fullName"):
		metadata["fullName"] = full_name
	if not metadata.has("full_name"):
		metadata["full_name"] = full_name
	if not metadata.has("key"):
		metadata["key"] = full_name
	if not metadata.has("name"):
		metadata["name"] = _tool_name_from_full_name(full_name, metadata)
	if not metadata.has("toolName"):
		metadata["toolName"] = str(metadata.get("name", _tool_name_from_full_name(full_name, metadata)))
	if not metadata.has("category"):
		metadata["category"] = _extract_category_from_full_name(_current_model, full_name)
	return metadata


func _merge_missing_tool_runtime_fields(target: Dictionary, source: Dictionary) -> void:
	for key in ["name", "category", "source", "script_path", "runtime_domain", "runtime_version", "state", "pending_reload", "last_error", "discovery_source", "last_refresh_reason"]:
		if target.has(key):
			continue
		if source.has(key):
			target[key] = source[key]


func _tool_name_from_full_name(full_name: String, metadata: Dictionary = {}) -> String:
	var category = str(metadata.get("category", ""))
	if category.is_empty():
		category = _extract_category_from_full_name(_current_model, full_name)
	if not category.is_empty() and full_name.begins_with("%s_" % category):
		return full_name.trim_prefix("%s_" % category)
	return full_name


func _get_tool_def_by_full_name(model: Dictionary, full_name: String) -> Dictionary:
	var category = _extract_category_from_full_name(model, full_name)
	if category.is_empty():
		return {}
	var tool_name = full_name.trim_prefix("%s_" % category)
	for tool_def in model.get("tools_by_category", {}).get(category, []):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		if str(tool_def.get("name", "")) == tool_name:
			return (tool_def as Dictionary).duplicate(true)
	return {}


func _extract_category_from_full_name(model: Dictionary, full_name: String) -> String:
	for category in model.get("tools_by_category", {}).keys():
		var category_name = str(category)
		if full_name.begins_with("%s_" % category_name):
			return category_name
	return ""


func _build_atomic_tool_preview_lines(system_full_name: String, depth: int = 0, visited: Dictionary = {}) -> Array[String]:
	var lines: Array[String] = []
	var presentation_lines := _build_presentation_atomic_tool_preview_lines(system_full_name, depth, visited)
	if not presentation_lines.is_empty():
		return presentation_lines
	if _has_presentation_tree(_current_model):
		return lines
	for entry in ToolPresentationService.get_atomic_child_specs(system_full_name):
		var atomic_full_name := str(entry.get("tool", ""))
		var actions: Array = entry.get("actions", [])
		if atomic_full_name.is_empty() or visited.has(atomic_full_name):
			continue
		var atomic_tool_def = _get_tool_def_by_full_name(_current_model, atomic_full_name)
		if atomic_tool_def.is_empty():
			continue
		var category = _extract_category_from_full_name(_current_model, atomic_full_name)
		var tool_name = str(atomic_tool_def.get("name", ""))
		if category.is_empty() or tool_name.is_empty():
			continue
		var display_name = _get_tool_display_name(_localization, atomic_full_name, tool_name)
		var indent = "  ".repeat(depth)
		lines.append("%s- %s" % [indent, display_name])
		for action_name in actions:
			lines.append("%s  - %s" % [indent, _get_action_display_name(atomic_full_name, str(action_name))])
		if category == SYSTEM_CATEGORY:
			var next_visited = visited.duplicate()
			next_visited[atomic_full_name] = true
			lines.append_array(_build_atomic_tool_preview_lines(atomic_full_name, depth + 1, next_visited))
	return lines


func _build_presentation_atomic_tool_preview_lines(system_full_name: String, depth: int = 0, visited: Dictionary = {}) -> Array[String]:
	var parent_metadata := _get_tool_metadata(system_full_name)
	var children = parent_metadata.get("treeChildren", [])
	if not (children is Array) or (children as Array).is_empty():
		return []
	var lines: Array[String] = []
	for child_id in children:
		var atomic_full_name := str(child_id).trim_prefix("atomic:")
		if atomic_full_name.is_empty() or visited.has(atomic_full_name):
			continue
		var atomic_metadata := _get_tool_metadata(atomic_full_name)
		if atomic_metadata.is_empty():
			continue
		var category = str(atomic_metadata.get("category", _extract_category_from_full_name(_current_model, atomic_full_name)))
		var tool_name = str(atomic_metadata.get("toolName", atomic_metadata.get("name", _tool_name_from_full_name(atomic_full_name, atomic_metadata))))
		if category.is_empty() or tool_name.is_empty():
			continue
		var display_name = _get_tool_display_name(_localization, atomic_full_name, tool_name)
		var indent = "  ".repeat(depth)
		lines.append("%s- %s" % [indent, display_name])
		for action_name in _extract_action_values(atomic_metadata):
			lines.append("%s  - %s" % [indent, _get_action_display_name(atomic_full_name, str(action_name))])
		if category == SYSTEM_CATEGORY:
			var next_visited = visited.duplicate()
			next_visited[atomic_full_name] = true
			lines.append_array(_build_presentation_atomic_tool_preview_lines(atomic_full_name, depth + 1, next_visited))
	return lines


func _extract_action_values(tool_def: Dictionary) -> Array[String]:
	var actions: Array[String] = []
	var input_schema = tool_def.get("inputSchema", {})
	if not (input_schema is Dictionary):
		return actions
	var properties = (input_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return actions
	var action_definition = (properties as Dictionary).get("action", {})
	if not (action_definition is Dictionary):
		return actions
	for value in (action_definition as Dictionary).get("enum", []):
		actions.append(str(value))
	return actions


func _build_parameter_preview_lines(tool_def: Dictionary, full_name: String) -> Array[String]:
	var input_schema = tool_def.get("inputSchema", {})
	if not (input_schema is Dictionary):
		return []
	var properties = (input_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return []

	var required_lookup: Dictionary = {}
	for required_name in (input_schema as Dictionary).get("required", []):
		required_lookup[str(required_name)] = true

	var property_names: Array = (properties as Dictionary).keys()
	property_names.sort()
	var lines: Array[String] = []
	for property_name in property_names:
		var property_def = (properties as Dictionary).get(property_name, {})
		if not (property_def is Dictionary):
			continue
		lines.append("- %s" % _format_parameter_summary(str(property_name), property_def as Dictionary, required_lookup, full_name))
	return lines


func _build_output_preview_lines(tool_def: Dictionary) -> Array[String]:
	var output_schema = tool_def.get("outputSchema", {})
	if not (output_schema is Dictionary):
		return []
	var properties = (output_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return []

	var required_lookup: Dictionary = {}
	for required_name in (output_schema as Dictionary).get("required", []):
		required_lookup[str(required_name)] = true

	var property_names: Array = (properties as Dictionary).keys()
	property_names.sort()
	var lines: Array[String] = []
	for property_name in property_names:
		var property_def = (properties as Dictionary).get(property_name, {})
		if not (property_def is Dictionary):
			continue
		lines.append("- %s" % _format_schema_property_summary(str(property_name), property_def as Dictionary, required_lookup))
	return lines


func _format_parameter_summary(property_name: String, property_def: Dictionary, required_lookup: Dictionary, full_name: String = "") -> String:
	var parts: Array[String] = [property_name]
	_append_schema_property_parts(parts, property_def, required_lookup, property_name)
	var description = _get_parameter_description(full_name, property_name, property_def)
	if not description.is_empty():
		parts.append(description)
	return " | ".join(parts)


func _format_schema_property_summary(property_name: String, property_def: Dictionary, required_lookup: Dictionary) -> String:
	var parts: Array[String] = [property_name]
	_append_schema_property_parts(parts, property_def, required_lookup, property_name)
	var description := str(property_def.get("description", ""))
	if not description.is_empty():
		parts.append(description)
	return " | ".join(parts)


func _append_schema_property_parts(parts: Array[String], property_def: Dictionary, required_lookup: Dictionary, property_name: String) -> void:
	var type_name = str(property_def.get("type", "any"))
	parts.append(type_name)
	if required_lookup.has(property_name):
		parts.append(_localization.get_text("tool_preview_required"))
	if property_def.has("enum"):
		var values: Array[String] = []
		for value in property_def.get("enum", []):
			values.append(str(value))
		parts.append("enum=%s" % ", ".join(values))


func _get_parameter_description(full_name: String, property_name: String, property_def: Dictionary) -> String:
	if _localization != null:
		for tool_key in _get_parameter_description_tool_keys(full_name):
			var specific_key = "tool_param_%s_%s_desc" % [tool_key, property_name]
			var specific_translation = _localization.get_text(specific_key)
			if specific_translation != specific_key:
				return specific_translation
		var generic_key = "tool_param_%s_desc" % property_name
		var generic_translation = _localization.get_text(generic_key)
		if generic_translation != generic_key:
			return generic_translation
	var schema_description := str(property_def.get("description", ""))
	if not schema_description.is_empty():
		return schema_description
	if _localization != null:
		var fallback_key = "tool_param_desc_fallback"
		var fallback_template = _localization.get_text(fallback_key)
		if fallback_template != fallback_key:
			return fallback_template % _humanize_identifier(property_name)
	return ""


func _get_parameter_description_tool_keys(full_name: String) -> Array[String]:
	var keys: Array[String] = []
	if not full_name.is_empty():
		keys.append(full_name)
	if full_name == "dap_debugger":
		keys.append("system_dap_debugger")
	return keys


func _count_previewable_tools(tools: Array) -> int:
	var count := 0
	for tool_def in tools:
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		count += 1
	return count


func _filter_empty_preview_lines(lines: Array[String]) -> Array[String]:
	var filtered: Array[String] = []
	var previous_empty := false
	for line in lines:
		var text = str(line)
		if text.is_empty():
			if previous_empty:
				continue
			previous_empty = true
			filtered.append("")
			continue
		previous_empty = false
		filtered.append(text)
	return filtered


func _build_tree_signature(model: Dictionary) -> String:
	var tools_by_category = model.get("tools_by_category", {})
	var parts: Array[String] = [
		_active_tools_view,
		_get_tree_language_signature(model),
		_get_search_query(),
		JSON.stringify(model.get("settings", {}).get("disabled_tools", [])),
		JSON.stringify(TreeCollapseState.get_collapsed_nodes(model.get("settings", {}))),
		JSON.stringify(model.get("tool_load_errors", []))
	]
	if _has_presentation_tree(model):
		var presentation = _active_tool_presentation()
		parts.append(_get_presentation_signature(presentation as Dictionary))
		return "\n".join(parts)
	var categories: Array = tools_by_category.keys()
	categories.sort()
	for category in categories:
		parts.append(str(category))
		var tools: Array = tools_by_category.get(category, [])
		for tool_def in tools:
			if not (tool_def is Dictionary):
				continue
			var tool_dict := tool_def as Dictionary
			parts.append("%s|%s|%s|%s" % [
				str(tool_dict.get("name", "")),
				str(tool_dict.get("source", "")),
				str(tool_dict.get("script_path", "")),
				str(tool_dict.get("load_state", ""))
			])
	return "\n".join(parts)


func _get_presentation_signature(presentation: Dictionary) -> String:
	var signature := str(presentation.get("signature", ""))
	if not signature.is_empty():
		return signature
	return ToolPresentationService.build_presentation_signature(
		str(presentation.get("view", _active_tools_view)),
		presentation.get("toolTree", []),
		presentation.get("toolGroups", []),
		presentation.get("toolMetadataByName", {})
	)


func _get_tree_language_signature(model: Dictionary) -> String:
	var current_language := str(model.get("current_language", ""))
	if not current_language.is_empty():
		return current_language
	var localization = model.get("localization")
	if localization != null and localization.has_method("get_language"):
		return str(localization.call("get_language"))
	return ""
