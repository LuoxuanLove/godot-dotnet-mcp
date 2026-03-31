@tool
extends RefCounted
class_name ToolsTabViewBindingService


func configure_preview_text(preview_text: TextEdit) -> void:
	preview_text.editable = false
	preview_text.selecting_enabled = true
	preview_text.context_menu_enabled = true
	preview_text.set_line_wrapping_mode(TextEdit.LINE_WRAPPING_BOUNDARY)
	preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func apply_header_state(tool_count_label: Label, search_edit: LineEdit, header_state: Dictionary) -> void:
	tool_count_label.text = str(header_state.get("tool_count_text", ""))
	search_edit.placeholder_text = str(header_state.get("search_placeholder_text", ""))


func apply_preview_state(tool_preview_title: Label, tool_preview_text: TextEdit, preview_state: Dictionary) -> void:
	var selection_changed := bool(preview_state.get("selection_changed", true))
	var saved_v_scroll := tool_preview_text.get_v_scroll() if not selection_changed else 0
	tool_preview_title.text = str(preview_state.get("title", ""))
	tool_preview_text.clear()
	tool_preview_text.set_text(str(preview_state.get("text", "")))
	tool_preview_text.set_v_scroll(saved_v_scroll)


func configure_tree_shadow(shadow: ColorRect, invert: bool) -> void:
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


func apply_editor_scale(
	tool_tree: Tree,
	tool_preview_panel: PanelContainer,
	top_shadow: ColorRect,
	bottom_shadow: ColorRect,
	search_edit: LineEdit,
	scale: float,
	text_column: int,
	check_column: int
) -> void:
	tool_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Tree content scrolls internally, so its minimum height must stay low enough
	# for the split container to keep search, divider and preview from overlapping.
	tool_tree.custom_minimum_size.y = 96.0 * scale
	tool_tree.custom_minimum_size.x = 0.0
	tool_tree.set_column_expand(text_column, true)
	tool_tree.set_column_expand(check_column, false)
	tool_tree.set_column_custom_minimum_width(text_column, int(round(320 * scale)))
	tool_tree.set_column_custom_minimum_width(check_column, int(round(44 * scale)))
	tool_preview_panel.custom_minimum_size.y = 88.0 * scale
	top_shadow.offset_left = -12.0 * scale
	top_shadow.offset_right = 12.0 * scale
	top_shadow.custom_minimum_size.y = 14.0 * scale
	top_shadow.offset_bottom = 14.0 * scale
	bottom_shadow.offset_left = -12.0 * scale
	bottom_shadow.offset_right = 12.0 * scale
	bottom_shadow.custom_minimum_size.y = 14.0 * scale
	bottom_shadow.offset_top = -14.0 * scale
	search_edit.custom_minimum_size.y = 30.0 * scale
