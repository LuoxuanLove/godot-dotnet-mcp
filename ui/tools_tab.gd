@tool
extends VBoxContainer

signal profile_selected(profile_id: String)
signal save_profile_requested(profile_name: String)
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

@onready var _tool_count_label: Label = %ToolCountLabel
@onready var _profile_label: Label = %ToolProfileLabel
@onready var _profile_option: OptionButton = %ToolProfileOption
@onready var _add_profile_button: Button = %AddProfileButton
@onready var _profile_desc_label: Label = %ToolProfileDescription
@onready var _show_user_tools_check: CheckBox = %ShowUserToolsCheck
@onready var _expand_all_button: Button = %ExpandAllButton
@onready var _collapse_all_button: Button = %CollapseAllButton
@onready var _delete_user_tool_button: Button = %DeleteUserToolButton
@onready var _tool_tree: Tree = %ToolTree
@onready var _top_shadow: ColorRect = %TopShadow
@onready var _save_dialog: ConfirmationDialog = %SaveProfileDialog
@onready var _profile_name_edit: LineEdit = %ProfileNameEdit
@onready var _save_dialog_desc: Label = %SaveProfileDescription

var _profile_option_syncing := false
var _tree_syncing := false
var _current_scale := -1.0
var _selected_user_script_path := ""


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_profile_option.item_selected.connect(_on_profile_option_selected)
	_add_profile_button.pressed.connect(_on_add_profile_button_pressed)
	_show_user_tools_check.toggled.connect(_on_show_user_tools_check_toggled)
	_expand_all_button.pressed.connect(_on_expand_all_button_pressed)
	_collapse_all_button.pressed.connect(_on_collapse_all_button_pressed)
	_delete_user_tool_button.pressed.connect(_on_delete_user_tool_button_pressed)
	_save_dialog.confirmed.connect(_on_save_dialog_confirmed)
	_tool_tree.item_edited.connect(_on_tree_item_edited)
	_tool_tree.item_collapsed.connect(_on_tree_item_collapsed)
	_tool_tree.item_selected.connect(_on_tree_item_selected)
	_configure_top_shadow()
	set_process(true)


func apply_model(model: Dictionary) -> void:
	var localization = model.get("localization")
	var settings: Dictionary = model.get("settings", {})
	var builtin_profiles: Array = model.get("builtin_profiles", [])
	var custom_profiles: Dictionary = model.get("custom_profiles", {})
	var profile_description = str(model.get("profile_description", ""))
	var editor_scale = float(model.get("editor_scale", 1.0))

	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)

	_tool_count_label.text = localization.get_text("tools_enabled") % _count_enabled_tools(model)
	_profile_label.text = localization.get_text("tool_profile")
	_add_profile_button.text = localization.get_text("btn_add_profile")
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

	_profile_option_syncing = true
	_profile_option.clear()
	var selected_profile_id = str(settings.get("tool_profile_id", "default"))
	var index = 0
	for profile in builtin_profiles:
		_profile_option.add_item(localization.get_text(str(profile.get("name_key", ""))), index)
		_profile_option.set_item_metadata(index, str(profile.get("id", "")))
		if str(profile.get("id", "")) == selected_profile_id:
			_profile_option.select(index)
		index += 1

	var custom_ids = custom_profiles.keys()
	custom_ids.sort()
	for profile_id in custom_ids:
		var custom_profile = custom_profiles[profile_id]
		_profile_option.add_item(str(custom_profile.get("name", profile_id)), index)
		_profile_option.set_item_metadata(index, str(profile_id))
		if str(profile_id) == selected_profile_id:
			_profile_option.select(index)
		index += 1
	_profile_option_syncing = false

	_selected_user_script_path = ""
	_render_tool_tree(model)
	_sync_delete_button()


func _render_tool_tree(model: Dictionary) -> void:
	_tree_syncing = true
	_tool_tree.clear()
	_tool_tree.set_column_clip_content(0, true)
	var root = _tool_tree.create_item()
	if root == null:
		_tree_syncing = false
		call_deferred("_update_top_shadow_visibility")
		return

	var tools_by_category: Dictionary = model.get("tools_by_category", {})
	var domain_defs: Array = model.get("domain_defs", [])
	var rendered_categories: Array[String] = []

	for domain_def in domain_defs:
		var categories: Array = []
		for category in domain_def.get("categories", []):
			if tools_by_category.has(category):
				categories.append(category)
				rendered_categories.append(category)
		if not categories.is_empty():
			_create_domain_item(root, model, str(domain_def.get("key", "")), str(domain_def.get("label", "")), categories)

	var other_categories: Array = []
	for category in tools_by_category.keys():
		if not rendered_categories.has(category):
			other_categories.append(category)
	if not other_categories.is_empty():
		_create_domain_item(root, model, "other", "domain_other", other_categories)

	_tree_syncing = false
	call_deferred("_update_top_shadow_visibility")


func _create_domain_item(root: TreeItem, model: Dictionary, domain_key: String, label_key: String, categories: Array) -> void:
	var settings: Dictionary = model.get("settings", {})
	var counts = _count_categories(model, categories)
	var item = _tool_tree.create_item(root)
	if item == null:
		return
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_editable(0, true)
	item.set_checked(0, _is_domain_fully_enabled(model, categories))
	item.set_text(0, "%s    %d/%d" % [model.get("localization").get_text(label_key), counts["enabled"], counts["total"]])
	item.set_metadata(0, {"kind": "domain", "key": domain_key})
	var domain_tooltip = _get_group_tooltip(model.get("localization"), label_key)
	if not domain_tooltip.is_empty():
		item.set_tooltip_text(0, domain_tooltip)
	item.collapsed = domain_key in settings.get("collapsed_domains", [])

	for category in categories:
		_create_category_item(item, model, str(category))


func _create_category_item(parent: TreeItem, model: Dictionary, category: String) -> void:
	var settings: Dictionary = model.get("settings", {})
	var counts = _count_category(model, category)
	var item = _tool_tree.create_item(parent)
	if item == null:
		return
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_editable(0, true)
	item.set_checked(0, _is_category_fully_enabled(model, category))
	var label_key = _get_category_label_key(category)
	item.set_text(0, "%s    %d/%d" % [_get_category_label(model.get("localization"), category), counts["enabled"], counts["total"]])
	item.set_metadata(0, {"kind": "category", "key": category})
	var category_tooltip = _get_group_tooltip(model.get("localization"), label_key)
	if not category_tooltip.is_empty():
		item.set_tooltip_text(0, category_tooltip)
	item.collapsed = category in settings.get("collapsed_categories", [])

	for tool_def in model.get("tools_by_category", {}).get(category, []):
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
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_editable(0, true)
	item.set_checked(0, not model.get("settings", {}).get("disabled_tools", []).has(full_name))
	item.set_text(0, _get_tool_display_name(localization, full_name, tool_name))
	item.set_metadata(0, {
		"kind": "tool",
		"key": full_name,
		"category": category,
		"source": str(tool_def.get("source", "builtin")),
		"script_path": str(tool_def.get("script_path", ""))
	})

	var desc_key = "tool_%s_desc" % full_name
	var desc_text = localization.get_text(desc_key)
	if desc_text != desc_key:
		item.set_tooltip_text(0, desc_text)


func _count_enabled_tools(model: Dictionary) -> Array:
	var total = 0
	var enabled = 0
	for category in model.get("tools_by_category", {}).keys():
		for tool_def in model["tools_by_category"][category]:
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
	for tool_def in model.get("tools_by_category", {}).get(category, []):
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
	profile_selected.emit(str(_profile_option.get_item_metadata(index)))


func _on_add_profile_button_pressed() -> void:
	_profile_name_edit.text = ""
	_save_dialog.popup_centered()
	_profile_name_edit.grab_focus()


func _on_save_dialog_confirmed() -> void:
	save_profile_requested.emit(_profile_name_edit.text.strip_edges())


func _on_show_user_tools_check_toggled(pressed: bool) -> void:
	show_user_tools_toggled.emit(pressed)


func _on_delete_user_tool_button_pressed() -> void:
	if _selected_user_script_path.is_empty():
		return
	delete_user_tool_requested.emit(_selected_user_script_path)


func _on_tree_item_edited() -> void:
	if _tree_syncing:
		return
	var item = _tool_tree.get_edited()
	if item == null:
		return
	if _tool_tree.get_edited_column() != 0:
		return
	var metadata = item.get_metadata(0)
	if not (metadata is Dictionary):
		return
	var enabled = item.is_checked(0)
	match str(metadata.get("kind", "")):
		"domain":
			domain_toggled.emit(str(metadata.get("key", "")), enabled)
		"category":
			category_toggled.emit(str(metadata.get("key", "")), enabled)
		"tool":
			tool_toggled.emit(str(metadata.get("key", "")), enabled)


func _on_tree_item_collapsed(item: TreeItem) -> void:
	if _tree_syncing or item == null:
		return
	var metadata = item.get_metadata(0)
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


func _on_tree_item_selected() -> void:
	var item = _tool_tree.get_selected()
	_selected_user_script_path = ""
	if item != null:
		var metadata = item.get_metadata(0)
		if metadata is Dictionary and str(metadata.get("kind", "")) == "tool":
			if str(metadata.get("category", "")) == "user" and str(metadata.get("source", "")) == "custom":
				_selected_user_script_path = str(metadata.get("script_path", ""))
	_sync_delete_button()


func _configure_top_shadow() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.58);

void fragment() {
	float alpha = pow(1.0 - UV.y, 1.35) * shadow_color.a;
	COLOR = vec4(shadow_color.rgb, alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.0, 0.58))
	_top_shadow.material = material
	_top_shadow.color = Color.WHITE
	_top_shadow.anchor_left = 0.0
	_top_shadow.anchor_top = 0.0
	_top_shadow.anchor_right = 1.0
	_top_shadow.anchor_bottom = 0.0
	_top_shadow.offset_left = -12.0
	_top_shadow.offset_top = 0.0
	_top_shadow.offset_right = 12.0
	_top_shadow.offset_bottom = 18.0
	_top_shadow.z_index = 8


func _process(_delta: float) -> void:
	_update_top_shadow_visibility()


func _update_top_shadow_visibility() -> void:
	if not is_instance_valid(_tool_tree):
		_top_shadow.visible = false
		return
	var scroll: Vector2 = _tool_tree.get_scroll()
	_top_shadow.visible = scroll.y > 0.5


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale

	var header_margin = get_node("HeaderMargin") as MarginContainer
	header_margin.add_theme_constant_override("margin_left", int(round(12 * scale)))
	header_margin.add_theme_constant_override("margin_right", int(round(12 * scale)))
	header_margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
	header_margin.add_theme_constant_override("margin_bottom", int(round(8 * scale)))

	var header_content = get_node("HeaderMargin/HeaderContent") as VBoxContainer
	header_content.add_theme_constant_override("separation", int(round(8 * scale)))

	var profile_row = get_node("HeaderMargin/HeaderContent/ProfileRow") as HBoxContainer
	profile_row.add_theme_constant_override("separation", int(round(8 * scale)))

	var actions_row = get_node("HeaderMargin/HeaderContent/ActionsRow") as HBoxContainer
	actions_row.add_theme_constant_override("separation", int(round(8 * scale)))

	var user_actions_row = get_node("HeaderMargin/HeaderContent/UserActionsRow") as HBoxContainer
	user_actions_row.add_theme_constant_override("separation", int(round(8 * scale)))

	var tool_list_outer_margin = get_node("TreeContainer/ToolListOuterMargin") as MarginContainer
	tool_list_outer_margin.add_theme_constant_override("margin_left", int(round(12 * scale)))
	tool_list_outer_margin.add_theme_constant_override("margin_right", int(round(12 * scale)))
	tool_list_outer_margin.add_theme_constant_override("margin_top", int(round(3 * scale)))
	tool_list_outer_margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))

	var tool_list_margin = get_node("TreeContainer/ToolListOuterMargin/ToolListPanel/ToolListOverlay/ToolListMargin") as MarginContainer
	tool_list_margin.add_theme_constant_override("margin_left", int(round(4 * scale)))
	tool_list_margin.add_theme_constant_override("margin_right", 0)
	tool_list_margin.add_theme_constant_override("margin_top", int(round(4 * scale)))
	tool_list_margin.add_theme_constant_override("margin_bottom", int(round(4 * scale)))

	_tool_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tool_tree.custom_minimum_size.y = 320.0 * scale
	_tool_tree.custom_minimum_size.x = 0.0
	_tool_tree.set_column_custom_minimum_width(0, int(round(360 * scale)))
	_top_shadow.offset_left = -12.0 * scale
	_top_shadow.offset_right = 12.0 * scale
	_top_shadow.custom_minimum_size.y = 18.0 * scale
	_top_shadow.offset_bottom = 18.0 * scale
	_save_dialog.min_size = Vector2i(int(round(320 * scale)), 0)

	for control in [_profile_option, _add_profile_button, _show_user_tools_check, _expand_all_button, _collapse_all_button, _delete_user_tool_button]:
		control.custom_minimum_size.y = 30.0 * scale


func _sync_delete_button() -> void:
	_delete_user_tool_button.disabled = _selected_user_script_path.is_empty()
