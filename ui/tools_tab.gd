@tool
extends VBoxContainer

signal profile_selected(profile_id: String)
signal save_profile_requested(profile_name: String)
signal rename_profile_requested(profile_id: String, profile_name: String)
signal delete_profile_requested(profile_id: String)
signal show_user_tools_toggled(enabled: bool)
signal delete_user_tool_requested(script_path: String)
signal tool_toggled(tool_name: String, enabled: bool)
signal category_toggled(category: String, enabled: bool)
signal domain_toggled(domain_key: String, enabled: bool)
signal category_collapse_toggled(category: String)
signal domain_collapse_toggled(domain_key: String)
signal expand_all_requested
signal collapse_all_requested

const CATEGORY_LABEL_KEYS := {
	"scene": "cat_scene",
	"node": "cat_node",
	"script": "cat_script",
	"resource": "cat_resource",
	"filesystem": "cat_filesystem",
	"project": "cat_project",
	"editor": "cat_editor",
	"plugin_runtime": "cat_plugin_runtime",
	"plugin_evolution": "cat_plugin_evolution",
	"plugin_developer": "cat_plugin_developer",
	"debug": "cat_debug",
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
	"user": "cat_user"
}

const TREE_TEXT_COLUMN := 0
const TREE_CHECK_COLUMN := 1

@onready var _tool_count_label: Label = %ToolCountLabel
@onready var _search_edit: LineEdit = %ToolSearchEdit
@onready var _profile_label: Label = %ToolProfileLabel
@onready var _profile_option: OptionButton = %ToolProfileOption
@onready var _add_profile_button: Button = %AddProfileButton
@onready var _rename_profile_button: Button = %RenameProfileButton
@onready var _delete_profile_button: Button = %DeleteProfileButton
@onready var _profile_desc_label: Label = %ToolProfileDescription
@onready var _show_user_tools_check: CheckBox = %ShowUserToolsCheck
@onready var _expand_all_button: Button = %ExpandAllButton
@onready var _collapse_all_button: Button = %CollapseAllButton
@onready var _delete_user_tool_button: Button = %DeleteUserToolButton
@onready var _content_split: VSplitContainer = %ContentSplit
@onready var _tool_tree: Tree = %ToolTree
@onready var _top_shadow: ColorRect = %TopShadow
@onready var _bottom_shadow: ColorRect = %BottomShadow
@onready var _tool_preview_panel: PanelContainer = %ToolPreviewPanel
@onready var _tool_preview_title: Label = %ToolPreviewTitle
@onready var _tool_preview_text: TextEdit = %ToolPreviewText
@onready var _save_dialog: ConfirmationDialog = %SaveProfileDialog
@onready var _profile_name_edit: LineEdit = %ProfileNameEdit
@onready var _save_dialog_desc: Label = %SaveProfileDescription
@onready var _delete_profile_dialog: ConfirmationDialog = %DeleteProfileDialog
@onready var _delete_profile_desc: Label = %DeleteProfileDescription

var _profile_option_syncing := false
var _tree_syncing := false
var _current_scale := -1.0
var _selected_user_script_path := ""
var _selected_profile_id := "default"
var _selected_profile_name := ""
var _selected_profile_is_custom := false
var _profile_dialog_mode := "save"
var _localization = null
var _current_model: Dictionary = {}
var _selected_tree_kind := ""
var _selected_tree_key := ""
var _selected_tool_category := ""
var _selected_tool_name := ""
var _selection_sync_queued := false
var _last_tree_signature := ""


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_search_edit.text_changed.connect(_on_search_text_changed)
	_profile_option.item_selected.connect(_on_profile_option_selected)
	_add_profile_button.pressed.connect(_on_add_profile_button_pressed)
	_rename_profile_button.pressed.connect(_on_rename_profile_button_pressed)
	_delete_profile_button.pressed.connect(_on_delete_profile_button_pressed)
	_show_user_tools_check.toggled.connect(_on_show_user_tools_check_toggled)
	_expand_all_button.pressed.connect(_on_expand_all_button_pressed)
	_collapse_all_button.pressed.connect(_on_collapse_all_button_pressed)
	_delete_user_tool_button.pressed.connect(_on_delete_user_tool_button_pressed)
	_save_dialog.confirmed.connect(_on_save_dialog_confirmed)
	_delete_profile_dialog.confirmed.connect(_on_delete_profile_dialog_confirmed)
	_tool_tree.item_collapsed.connect(_on_tree_item_collapsed)
	_tool_tree.gui_input.connect(_on_tree_gui_input)
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
	_configure_tree_shadow(_top_shadow, false)
	_configure_tree_shadow(_bottom_shadow, true)
	set_process(true)


func apply_model(model: Dictionary) -> void:
	var localization = model.get("localization")
	_localization = localization
	_current_model = model
	var settings: Dictionary = model.get("settings", {})
	var builtin_profiles: Array = model.get("builtin_profiles", [])
	var custom_profiles: Dictionary = model.get("custom_profiles", {})
	var profile_description = str(model.get("profile_description", ""))
	var editor_scale = float(model.get("editor_scale", 1.0))

	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)

	_apply_localized_copy(localization, model, profile_description)
	_rebuild_profile_options(localization, builtin_profiles, custom_profiles, str(settings.get("tool_profile_id", "default")))
	_sync_profile_selection_from_option()
	_sync_profile_buttons()

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
		call_deferred("_update_tree_shadow_visibility")
		return

	var tools_by_category: Dictionary = model.get("tools_by_category", {})
	var domain_defs: Array = model.get("domain_defs", [])
	var rendered_categories: Array[String] = []

	for domain_def in domain_defs:
		var categories: Array = []
		for category in domain_def.get("categories", []):
			if tools_by_category.has(category) and _category_matches_search(model, str(category)):
				categories.append(category)
				rendered_categories.append(category)
		if not categories.is_empty():
			_create_domain_item(root, model, str(domain_def.get("key", "")), str(domain_def.get("label", "")), categories)

	var other_categories: Array = []
	for category in tools_by_category.keys():
		if not rendered_categories.has(category) and _category_matches_search(model, str(category)):
			other_categories.append(category)
	if not other_categories.is_empty():
		_create_domain_item(root, model, "other", "domain_other", other_categories)

	_tree_syncing = false
	call_deferred("_update_tree_shadow_visibility")


func _apply_localized_copy(localization, model: Dictionary, profile_description: String) -> void:
	_tool_count_label.text = localization.get_text("tools_enabled") % _count_enabled_tools(model)
	_search_edit.placeholder_text = localization.get_text("tool_search_placeholder")
	_profile_label.text = localization.get_text("tool_profile")
	_add_profile_button.text = localization.get_text("btn_add_profile")
	_rename_profile_button.text = localization.get_text("btn_rename_profile")
	_delete_profile_button.text = localization.get_text("btn_delete_profile")
	_show_user_tools_check.text = localization.get_text("show_user_tools")
	_expand_all_button.text = localization.get_text("btn_expand_all")
	_collapse_all_button.text = localization.get_text("btn_collapse_all")
	_delete_user_tool_button.text = localization.get_text("btn_delete_user_tool")
	_show_user_tools_check.set_pressed_no_signal(bool(model.get("show_user_tools", false)))
	_profile_desc_label.text = profile_description
	_save_dialog.title = localization.get_text("tool_profile_save_title")
	_save_dialog.get_ok_button().text = localization.get_text("btn_save_profile")
	_save_dialog_desc.text = localization.get_text("tool_profile_save_desc")
	_profile_name_edit.placeholder_text = localization.get_text("tool_profile_name_placeholder")


func _rebuild_profile_options(localization, builtin_profiles: Array, custom_profiles: Dictionary, selected_profile_id: String) -> void:
	_profile_option_syncing = true
	_profile_option.clear()

	var index := 0
	for profile in builtin_profiles:
		_profile_option.add_item(localization.get_text(str(profile.get("name_key", ""))), index)
		_profile_option.set_item_metadata(index, {
			"profile_id": str(profile.get("id", "")),
			"profile_name": localization.get_text(str(profile.get("name_key", ""))),
			"is_custom": false
		})
		if str(profile.get("id", "")) == selected_profile_id:
			_profile_option.select(index)
		index += 1

	var custom_ids = custom_profiles.keys()
	custom_ids.sort()
	for profile_id in custom_ids:
		var custom_profile = custom_profiles[profile_id]
		_profile_option.add_item(str(custom_profile.get("name", profile_id)), index)
		_profile_option.set_item_metadata(index, {
			"profile_id": str(profile_id),
			"profile_name": str(custom_profile.get("name", profile_id)),
			"is_custom": true
		})
		if str(profile_id) == selected_profile_id:
			_profile_option.select(index)
		index += 1

	_profile_option_syncing = false


func _refresh_tree_state(model: Dictionary, tree_signature: String) -> void:
	if tree_signature != _last_tree_signature:
		_last_tree_signature = tree_signature
		_render_tool_tree(model)
		_sync_delete_button()
		_refresh_preview()
		if _has_tree_selection():
			_queue_selection_sync()
		return

	_sync_delete_button()
	_refresh_preview()


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


func _create_domain_item(root: TreeItem, model: Dictionary, domain_key: String, label_key: String, categories: Array) -> void:
	var settings: Dictionary = model.get("settings", {})
	var counts = _count_categories(model, categories)
	var item = _tool_tree.create_item(root)
	if item == null:
		return
	_configure_item_toggle(item, _is_domain_fully_enabled(model, categories))
	var domain_text = "%s    %d/%d" % [model.get("localization").get_text(label_key), counts["enabled"], counts["total"]]
	if counts["enabled"] > 0 and counts["enabled"] < counts["total"]:
		domain_text += " %s" % model.get("localization").get_text("tools_partial_suffix")
	var domain_tooltip = _get_group_tooltip(model.get("localization"), label_key)
	_configure_item_text(item, domain_text, {"kind": "domain", "key": domain_key, "label_key": label_key}, domain_tooltip)
	item.collapsed = domain_key in settings.get("collapsed_domains", [])

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
	var category_text = "%s    %d/%d" % [_get_category_label(model.get("localization"), category), counts["enabled"], counts["total"]]
	if counts["enabled"] > 0 and counts["enabled"] < counts["total"]:
		category_text += " %s" % model.get("localization").get_text("tools_partial_suffix")
	if not load_error_messages.is_empty():
		category_text += " %s" % model.get("localization").get_text("tools_load_error_suffix")
	item.set_text(0, category_text)
	item.set_selectable(0, true)
	item.set_metadata(0, {"kind": "category", "key": category, "label_key": label_key})
	var category_tooltip = _get_group_tooltip(model.get("localization"), label_key)
	if not load_error_messages.is_empty():
		if not category_tooltip.is_empty():
			category_tooltip += "\n\n"
		category_tooltip += "\n".join(load_error_messages)
	_configure_item_text(item, category_text, {"kind": "category", "key": category, "label_key": label_key}, category_tooltip)
	if not load_error_messages.is_empty():
		item.set_custom_color(TREE_TEXT_COLUMN, Color(0.9, 0.35, 0.35))
	item.collapsed = category in settings.get("collapsed_categories", [])

	for tool_def in _get_filtered_tool_definitions(model, category):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		_create_tool_item(item, model, category, tool_def)


func _create_tool_item(parent: TreeItem, model: Dictionary, category: String, tool_def: Dictionary) -> void:
	var localization = model.get("localization")
	var tool_name = str(tool_def.get("name", ""))
	var full_name = "%s_%s" % [category, tool_name]
	var item = _tool_tree.create_item(parent)
	if item == null:
		return
	_configure_item_toggle(item, not model.get("settings", {}).get("disabled_tools", []).has(full_name))
	_configure_item_text(item, _get_tool_display_name(localization, full_name, tool_name), {
		"kind": "tool",
		"key": full_name,
		"category": category,
		"tool_name": tool_name,
		"source": str(tool_def.get("source", "builtin")),
		"script_path": str(tool_def.get("script_path", ""))
	}, _get_tool_description(localization, full_name, tool_def))


func _count_enabled_tools(model: Dictionary) -> Array:
	var total = 0
	var enabled = 0
	for category in model.get("tools_by_category", {}).keys():
		for tool_def in _get_filtered_tool_definitions(model, str(category)):
			if bool(tool_def.get("compatibility_alias", false)):
				continue
			total += 1
			var full_name = "%s_%s" % [category, tool_def.get("name", "")]
			if not model.get("settings", {}).get("disabled_tools", []).has(full_name):
				enabled += 1
	return [enabled, total]


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


func _humanize_identifier(value: String) -> String:
	var parts: Array[String] = []
	for word in value.split("_"):
		if word.is_empty():
			continue
		parts.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(parts)


func _on_profile_option_selected(index: int) -> void:
	if _profile_option_syncing:
		return
	_sync_profile_selection_from_option(index)
	_sync_profile_buttons()
	profile_selected.emit(_selected_profile_id)


func _on_add_profile_button_pressed() -> void:
	_profile_dialog_mode = "save"
	_profile_name_edit.text = ""
	_refresh_profile_dialog_copy()
	_save_dialog.popup_centered()
	_profile_name_edit.grab_focus()


func _on_rename_profile_button_pressed() -> void:
	if not _selected_profile_is_custom:
		return
	_profile_dialog_mode = "rename"
	_profile_name_edit.text = _selected_profile_name
	_refresh_profile_dialog_copy()
	_save_dialog.popup_centered()
	_profile_name_edit.grab_focus()


func _on_save_dialog_confirmed() -> void:
	var profile_name = _profile_name_edit.text.strip_edges()
	if _profile_dialog_mode == "rename":
		rename_profile_requested.emit(_selected_profile_id, profile_name)
		return
	save_profile_requested.emit(profile_name)


func _on_delete_profile_button_pressed() -> void:
	if not _selected_profile_is_custom:
		return
	_refresh_delete_profile_dialog_copy()
	_delete_profile_dialog.popup_centered()


func _on_delete_profile_dialog_confirmed() -> void:
	if not _selected_profile_is_custom:
		return
	delete_profile_requested.emit(_selected_profile_id)


func _on_show_user_tools_check_toggled(pressed: bool) -> void:
	show_user_tools_toggled.emit(pressed)


func _on_delete_user_tool_button_pressed() -> void:
	if _selected_user_script_path.is_empty():
		return
	delete_user_tool_requested.emit(_selected_user_script_path)


func _on_tree_item_collapsed(item: TreeItem) -> void:
	if _tree_syncing or item == null:
		return
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if not (metadata is Dictionary):
		return
	match str(metadata.get("kind", "")):
		"domain":
			domain_collapse_toggled.emit(str(metadata.get("key", "")))
		"category":
			category_collapse_toggled.emit(str(metadata.get("key", "")))


func _on_expand_all_button_pressed() -> void:
	expand_all_requested.emit()


func _on_collapse_all_button_pressed() -> void:
	collapse_all_requested.emit()


func _on_search_text_changed(_new_text: String) -> void:
	if _current_model.is_empty():
		return
	_render_tool_tree(_current_model)
	_sync_delete_button()
	_refresh_preview()
	if _has_tree_selection():
		_queue_selection_sync()


func _on_tree_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	call_deferred("_handle_tree_click_deferred", mouse_event.position)


func _configure_tree_shadow(shadow: ColorRect, invert: bool) -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.58);
uniform bool invert_gradient = false;

void fragment() {
	float amount = 1.0 - UV.y;
	if (invert_gradient) {
		amount = UV.y;
	}
	float alpha = pow(amount, 1.35) * shadow_color.a;
	COLOR = vec4(shadow_color.rgb, alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.0, 0.58))
	material.set_shader_parameter("invert_gradient", invert)
	shadow.material = material
	shadow.color = Color.WHITE
	shadow.anchor_left = 0.0
	shadow.anchor_right = 1.0
	shadow.offset_left = -12.0
	shadow.offset_right = 12.0
	shadow.z_index = 8
	if invert:
		shadow.anchor_top = 1.0
		shadow.anchor_bottom = 1.0
		shadow.offset_top = -18.0
		shadow.offset_bottom = 0.0
	else:
		shadow.anchor_top = 0.0
		shadow.anchor_bottom = 0.0
		shadow.offset_top = 0.0
		shadow.offset_bottom = 18.0


func _process(_delta: float) -> void:
	_update_tree_shadow_visibility()


func _update_tree_shadow_visibility() -> void:
	if not is_instance_valid(_tool_tree):
		_top_shadow.visible = false
		_bottom_shadow.visible = false
		return
	var scroll: Vector2 = _tool_tree.get_scroll()
	var root = _tool_tree.get_root()
	var has_items := root != null and root.get_first_child() != null
	_top_shadow.visible = scroll.y > 0.5
	_bottom_shadow.visible = has_items and _tree_has_hidden_content_below(root)


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale

	_tool_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Tree content scrolls internally, so its minimum height must stay low enough
	# for the split container to keep search, divider and preview from overlapping.
	_tool_tree.custom_minimum_size.y = 96.0 * scale
	_tool_tree.custom_minimum_size.x = 0.0
	_tool_tree.set_column_expand(TREE_TEXT_COLUMN, true)
	_tool_tree.set_column_expand(TREE_CHECK_COLUMN, false)
	_tool_tree.set_column_custom_minimum_width(TREE_TEXT_COLUMN, int(round(320 * scale)))
	_tool_tree.set_column_custom_minimum_width(TREE_CHECK_COLUMN, int(round(44 * scale)))
	_tool_preview_panel.custom_minimum_size.y = 88.0 * scale
	_top_shadow.offset_left = -12.0 * scale
	_top_shadow.offset_right = 12.0 * scale
	_top_shadow.custom_minimum_size.y = 14.0 * scale
	_top_shadow.offset_bottom = 14.0 * scale
	_bottom_shadow.offset_left = -12.0 * scale
	_bottom_shadow.offset_right = 12.0 * scale
	_bottom_shadow.custom_minimum_size.y = 14.0 * scale
	_bottom_shadow.offset_top = -14.0 * scale
	_save_dialog.min_size = Vector2i(int(round(320 * scale)), 0)
	_delete_profile_dialog.min_size = Vector2i(int(round(320 * scale)), 0)

	for control in [_search_edit, _profile_option, _add_profile_button, _rename_profile_button, _delete_profile_button, _show_user_tools_check, _expand_all_button, _collapse_all_button, _delete_user_tool_button]:
		control.custom_minimum_size.y = 30.0 * scale


func _sync_delete_button() -> void:
	_delete_user_tool_button.disabled = _selected_user_script_path.is_empty()


func _sync_profile_selection_from_option(index: int = -1) -> void:
	var selected_index = index if index >= 0 else _profile_option.get_selected()
	if selected_index < 0:
		_selected_profile_id = "default"
		_selected_profile_name = ""
		_selected_profile_is_custom = false
		return

	var metadata = _profile_option.get_item_metadata(selected_index)
	if not (metadata is Dictionary):
		_selected_profile_id = "default"
		_selected_profile_name = ""
		_selected_profile_is_custom = false
		return

	_selected_profile_id = str(metadata.get("profile_id", "default"))
	_selected_profile_name = str(metadata.get("profile_name", _selected_profile_id))
	_selected_profile_is_custom = bool(metadata.get("is_custom", false))


func _sync_profile_buttons() -> void:
	_rename_profile_button.disabled = not _selected_profile_is_custom
	_delete_profile_button.disabled = not _selected_profile_is_custom
	_refresh_profile_dialog_copy()
	_refresh_delete_profile_dialog_copy()


func _refresh_profile_dialog_copy() -> void:
	if _localization == null:
		return
	if _profile_dialog_mode == "rename":
		_save_dialog.title = _localization.get_text("tool_profile_rename_title")
		_save_dialog_desc.text = _localization.get_text("tool_profile_rename_desc")
	else:
		_save_dialog.title = _localization.get_text("tool_profile_save_title")
		_save_dialog_desc.text = _localization.get_text("tool_profile_save_desc")
	_save_dialog.get_ok_button().text = _localization.get_text("btn_save_profile")
	_profile_name_edit.placeholder_text = _localization.get_text("tool_profile_name_placeholder")


func _refresh_delete_profile_dialog_copy() -> void:
	if _localization == null:
		return
	_delete_profile_dialog.title = _localization.get_text("tool_profile_delete_title")
	_delete_profile_desc.text = _localization.get_text("tool_profile_delete_desc") % [_selected_profile_name]


func _category_matches_search(model: Dictionary, category: String) -> bool:
	var query = _get_search_query()
	if query.is_empty():
		return true
	if _get_category_label(model.get("localization"), category).to_lower().contains(query):
		return true
	for tool_def in model.get("tools_by_category", {}).get(category, []):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		var tool_name = str(tool_def.get("name", ""))
		var full_name = "%s_%s" % [category, tool_name]
		if _get_tool_display_name(model.get("localization"), full_name, tool_name).to_lower().contains(query):
			return true
	return false


func _get_filtered_tool_definitions(model: Dictionary, category: String) -> Array:
	var filtered: Array = []
	var query = _get_search_query()
	var category_matches = _get_category_label(model.get("localization"), category).to_lower().contains(query)
	for tool_def in model.get("tools_by_category", {}).get(category, []):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		if query.is_empty() or category_matches:
			filtered.append(tool_def)
			continue
		var tool_name = str(tool_def.get("name", ""))
		var full_name = "%s_%s" % [category, tool_name]
		if _get_tool_display_name(model.get("localization"), full_name, tool_name).to_lower().contains(query):
			filtered.append(tool_def)
	return filtered


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
		_selected_tree_kind = str(metadata_dict.get("kind", ""))
		_selected_tree_key = str(metadata_dict.get("key", ""))
		_selected_tool_category = str(metadata_dict.get("category", ""))
		_selected_tool_name = str(metadata_dict.get("tool_name", ""))
		if _selected_tree_kind == "tool":
			if str(metadata_dict.get("category", "")) == "user" and str(metadata_dict.get("source", "")) == "custom":
				_selected_user_script_path = str(metadata_dict.get("script_path", ""))
	_sync_delete_button()
	_refresh_preview()


func _clear_selection_metadata() -> void:
	_selected_user_script_path = ""
	_selected_tree_kind = ""
	_selected_tree_key = ""
	_selected_tool_category = ""
	_selected_tool_name = ""


func _restore_tree_selection() -> void:
	if _selected_tree_kind.is_empty() or _selected_tree_key.is_empty():
		return
	var root = _tool_tree.get_root()
	if root == null:
		return
	var item = _find_item_by_selection(root)
	if item == null:
		_clear_selection_metadata()
		_sync_delete_button()
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


func _tree_has_hidden_content_below(root: TreeItem) -> bool:
	var last_item = _find_last_visible_tree_item(root)
	if last_item == null:
		return false
	var rect = _tool_tree.get_item_area_rect(last_item, TREE_TEXT_COLUMN, -1)
	return rect.position.y + rect.size.y > _tool_tree.size.y + 1.0


func _find_last_visible_tree_item(item: TreeItem) -> TreeItem:
	if item == null:
		return null
	var child = item.get_first_child()
	if child == null:
		return item

	var last_visible: TreeItem = null
	while child != null:
		last_visible = child
		if not child.collapsed:
			var deepest = _find_last_visible_tree_item(child)
			if deepest != null:
				last_visible = deepest
		child = child.get_next()
	return last_visible


func _refresh_preview() -> void:
	if _localization == null:
		return
	_tool_preview_title.text = _localization.get_text("tool_preview_title")
	_tool_preview_text.clear()
	_tool_preview_text.set_text(_build_preview_text())
	_tool_preview_text.set_v_scroll(0)


func _build_preview_text() -> String:
	if _selected_tree_kind.is_empty() or _selected_tree_key.is_empty():
		return str(_localization.get_text("tool_preview_empty"))

	match _selected_tree_kind:
		"domain":
			return _build_domain_preview()
		"category":
			return _build_category_preview()
		"tool":
			return _build_tool_preview()
		_:
			return str(_localization.get_text("tool_preview_empty"))


func _build_domain_preview() -> String:
	var domain_def = _find_domain_definition(_selected_tree_key)
	if domain_def.is_empty():
		return str(_localization.get_text("tool_preview_empty"))

	var label_key = str(domain_def.get("label", "domain_other"))
	var categories: Array = domain_def.get("categories", [])
	var lines: Array[String] = [
		"%s: %s" % [_localization.get_text("tool_preview_domain"), _localization.get_text(label_key)],
		"",
		_get_group_tooltip(_localization, label_key),
		"",
		_localization.get_text("tool_preview_category_count") % categories.size()
	]
	for category in categories:
		if not _current_model.get("tools_by_category", {}).has(category):
			continue
		lines.append("- %s" % _get_category_label(_localization, str(category)))
	return "\n".join(_filter_empty_preview_lines(lines))


func _build_category_preview() -> String:
	var category = _selected_tree_key
	var tools: Array = _current_model.get("tools_by_category", {}).get(category, [])
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
		var tool_name = str(tool_def.get("name", ""))
		var full_name = "%s_%s" % [category, tool_name]
		lines.append("- %s" % _get_tool_display_name(_localization, full_name, tool_name))
	return "\n".join(_filter_empty_preview_lines(lines))


func _build_tool_preview() -> String:
	var category = _selected_tool_category
	var tool_name = _selected_tool_name
	if category.is_empty() or tool_name.is_empty():
		return str(_localization.get_text("tool_preview_empty"))
	var tool_def = _find_tool_definition(category, tool_name)
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
		description if not description.is_empty() else _localization.get_text("tool_preview_no_description"),
		"",
		_localization.get_text("tool_preview_actions")
	]

	var actions = _extract_action_values(tool_def)
	if actions.is_empty():
		lines.append(_localization.get_text("tool_preview_no_actions"))
	else:
		for action_value in actions:
			lines.append("- %s" % action_value)

	lines.append("")
	lines.append(_localization.get_text("tool_preview_params"))
	var parameter_lines = _build_parameter_preview_lines(tool_def)
	if parameter_lines.is_empty():
		lines.append(_localization.get_text("tool_preview_no_params"))
	else:
		lines.append_array(parameter_lines)

	return "\n".join(_filter_empty_preview_lines(lines))


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


func _find_tool_definition(category: String, tool_name: String) -> Dictionary:
	for tool_def in _current_model.get("tools_by_category", {}).get(category, []):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		if str(tool_def.get("name", "")) == tool_name:
			return (tool_def as Dictionary).duplicate(true)
	return {}


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


func _build_parameter_preview_lines(tool_def: Dictionary) -> Array[String]:
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
		lines.append("- %s" % _format_parameter_summary(str(property_name), property_def as Dictionary, required_lookup))
	return lines


func _format_parameter_summary(property_name: String, property_def: Dictionary, required_lookup: Dictionary) -> String:
	var parts: Array[String] = [property_name]
	var type_name = str(property_def.get("type", "any"))
	parts.append(type_name)
	if required_lookup.has(property_name):
		parts.append(_localization.get_text("tool_preview_required"))
	if property_def.has("enum"):
		var values: Array[String] = []
		for value in property_def.get("enum", []):
			values.append(str(value))
		parts.append("enum=%s" % ", ".join(values))
	var description = str(property_def.get("description", ""))
	if not description.is_empty():
		parts.append(description)
	return " | ".join(parts)


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
		_get_search_query(),
		JSON.stringify(model.get("settings", {}).get("disabled_tools", [])),
		JSON.stringify(model.get("settings", {}).get("collapsed_categories", [])),
		JSON.stringify(model.get("settings", {}).get("collapsed_domains", [])),
		JSON.stringify(model.get("tool_load_errors", []))
	]
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
