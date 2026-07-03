extends RefCounted

# {"name": "mcp_catalog_tab_rendering_contracts"}

const McpCatalogTabScene = preload("res://addons/godot_dotnet_mcp/ui/mcp_catalog_tab.tscn")

var _instances: Array = []


class FakeLocalization extends RefCounted:
	const TEXTS := {
		"mcp_resources_title": "Resources",
		"mcp_resources_description": "Browse read-only MCP context resources.",
		"mcp_resources_counts": "Resources: %d | Templates: %d",
		"mcp_prompts_title": "Prompts",
		"mcp_prompts_description": "Browse workflow prompts.",
		"mcp_prompts_counts": "Prompts: %d",
		"mcp_catalog_resources": "Resources",
		"mcp_catalog_resource_templates": "Resource Templates",
		"mcp_catalog_prompts": "Prompts",
		"mcp_catalog_empty": "No protocol entries available.",
		"mcp_catalog_copy_id": "Copy ID",
		"mcp_catalog_kind": "Kind",
		"mcp_catalog_mime_type": "MIME",
		"mcp_catalog_source": "Source",
		"mcp_catalog_visibility": "Visibility",
		"mcp_catalog_callability": "Callability",
		"mcp_catalog_group": "Group",
		"mcp_catalog_arguments": "Arguments",
		"mcp_catalog_preview": "Preview",
		"mcp_catalog_preview_title": "Preview",
		"mcp_catalog_preview_empty": "Preview returned no text.",
		"mcp_catalog_preview_error": "Preview failed: %s",
		"mcp_catalog_copy_preview": "Copy Preview",
		"mcp_catalog_argument_placeholder": "Enter argument value",
		"mcp_catalog_view_catalog": "Catalog",
		"mcp_catalog_view_workflows": "Workflows",
		"mcp_catalog_view_diagnostics": "Diagnostics",
		"mcp_catalog_search_resources": "Search resources, templates, URIs, MIME types...",
		"mcp_catalog_search_prompts": "Search prompts, workflows, arguments...",
		"mcp_catalog_clear_arguments": "Clear",
		"mcp_catalog_select_entry": "Select an entry",
		"mcp_catalog_select_entry_hint": "Select a resource, template, or prompt to inspect protocol metadata and generate previews.",
		"mcp_catalog_template_argument_placeholder": "Value for {%s}",
		"mcp_catalog_diagnostics_section": "Diagnostics",
		"mcp_catalog_resolved_uri": "Resolved URI",
		"mcp_catalog_template_missing_arguments": "Template arguments required.",
		"mcp_catalog_icon_status": "Icon",
		"mcp_catalog_icon_missing": "missing",
		"mcp_catalog_icon_available": "available",
		"mcp_catalog_icon_rejected": "rejected",
		"mcp_catalog_preview_status": "Preview",
		"mcp_catalog_preview_available": "available",
		"mcp_catalog_metadata": "Metadata",
		"mcp_resource_group_guides": "Guides",
		"mcp_resource_group_project_state": "Project State",
		"mcp_resource_group_editor_state": "Editor State",
		"mcp_resource_group_activity_logs": "Activity & Logs",
		"mcp_resource_group_tool_catalog": "Tool Catalog",
		"mcp_resource_group_templates": "Resource Templates",
		"mcp_resource_group_advanced": "Advanced Resources",
		"mcp_prompt_group_project_understanding": "Project Understanding",
		"mcp_prompt_group_editor_workflow": "Editor Workflow",
		"mcp_prompt_group_runtime_validation": "Runtime Validation",
		"mcp_prompt_group_script_csharp": "Script & C# Workflow",
		"mcp_prompt_group_plugin_maintenance": "Plugin Maintenance",
		"mcp_prompt_group_advanced": "Advanced Prompts"
	}

	func get_text(key: String) -> String:
		return str(TEXTS.get(key, key))


class EventRecorder extends RefCounted:
	var copied_text := ""
	var copied_source := ""
	var preview_kind := ""
	var preview_id := ""
	var preview_arguments: Dictionary = {}

	func on_copy_requested(text: String, source: String) -> void:
		copied_text = text
		copied_source = source

	func on_preview_requested(kind: String, id: String, arguments: Dictionary) -> void:
		preview_kind = kind
		preview_id = id
		preview_arguments = arguments.duplicate(true)


func run_case(tree: SceneTree) -> Dictionary:
	var source_guard := _verify_catalog_tab_uses_workbench_signatures()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var model := _build_model()
	var resources_tab = await _instantiate_tab(tree, "resources")
	var prompts_tab = await _instantiate_tab(tree, "prompts")
	if resources_tab == null or prompts_tab == null:
		return _failure("MCP catalog rendering test could not instantiate the Resources and Prompts tabs.")
	var recorder := EventRecorder.new()
	resources_tab.copy_requested.connect(Callable(recorder, "on_copy_requested"))
	resources_tab.preview_requested.connect(Callable(recorder, "on_preview_requested"))
	prompts_tab.copy_requested.connect(Callable(recorder, "on_copy_requested"))
	prompts_tab.preview_requested.connect(Callable(recorder, "on_preview_requested"))

	resources_tab.apply_model(model)
	prompts_tab.apply_model(model)
	await tree.process_frame

	if _label_text(resources_tab, "HeaderCounts") != "Resources: 3 | Templates: 1":
		return _failure("Resources tab should render resource/template counts from the Dock protocol model.")
	if _label_text(prompts_tab, "HeaderCounts") != "Prompts: 3":
		return _failure("Prompts tab should render prompt counts from the Dock protocol model.")
	if resources_tab.find_child("ResourcesCard", true, false) != null or prompts_tab.find_child("PromptsCard", true, false) != null:
		return _failure("MCP catalog tabs should use the split Tree workbench instead of the old stacked card sections.")
	if resources_tab.find_child("CatalogTree", true, false) == null or resources_tab.find_child("PreviewText", true, false) == null:
		return _failure("Resources tab should expose a Tree plus detail/preview pane.")
	if prompts_tab.find_child("CatalogTree", true, false) == null or prompts_tab.find_child("PreviewText", true, false) == null:
		return _failure("Prompts tab should expose a Tree plus detail/preview pane.")
	if not _button_pressed(resources_tab, "CatalogViewButton") or _button_pressed(resources_tab, "DiagnosticsViewButton"):
		return _failure("MCP catalog tabs should default to the Catalog view.")
	if _line_edit(resources_tab, "CatalogSearchEdit").placeholder_text != "Search resources, templates, URIs, MIME types...":
		return _failure("Resources tab should expose a localized resource search placeholder.")
	if _line_edit(prompts_tab, "CatalogSearchEdit").placeholder_text != "Search prompts, workflows, arguments...":
		return _failure("Prompts tab should expose a localized prompt search placeholder.")

	if not _has_group_item(resources_tab, "guides") or not _has_group_item(resources_tab, "resource_templates"):
		return _failure("Resources tree should render presentation groups including Guides and Resource Templates.")
	if not _has_entry_item(resources_tab, "resource", "godot-dotnet-mcp://guides/index"):
		return _failure("Resources tree should render canonical guide resources by URI.")
	if not _has_entry_item(resources_tab, "template", "godot-dotnet-mcp://scene/{path}"):
		return _failure("Resources tree should render resource templates by URI template.")
	if not _has_group_item(prompts_tab, "project_understanding") or not _has_group_item(prompts_tab, "runtime_validation"):
		return _failure("Prompts tree should render workflow presentation groups.")
	if not _has_entry_item(prompts_tab, "prompt", "godot.project_orientation"):
		return _failure("Prompts tree should render workflow prompts by name.")

	_select_entry(resources_tab, "resource", "godot-dotnet-mcp://guides/index")
	await tree.process_frame
	if _label_text(resources_tab, "PreviewTitle") != "Guide Index":
		return _failure("Selecting a resource tree row should update the detail panel title.")
	if not _text_edit_text(resources_tab, "PreviewText").contains("godot-dotnet-mcp://guides/index"):
		return _failure("Resource detail panel should include the selected protocol URI.")
	_button(resources_tab, "CopyIdButton").emit_signal("pressed")
	if recorder.copied_text != "godot-dotnet-mcp://guides/index" or recorder.copied_source != "Guide Index":
		return _failure("Copy ID should emit the selected resource URI and display title.")
	_button(resources_tab, "PreviewButton").emit_signal("pressed")
	if recorder.preview_kind != "resource" or recorder.preview_id != "godot-dotnet-mcp://guides/index":
		return _failure("Resource preview should emit the selected resource kind and URI.")

	_select_entry(resources_tab, "template", "godot-dotnet-mcp://scene/{path}")
	await tree.process_frame
	var path_input := resources_tab.find_child("ArgumentInput_path", true, false) as LineEdit
	if path_input == null:
		return _failure("Resource template detail panel should expose input controls for URI placeholders.")
	_button(resources_tab, "PreviewButton").emit_signal("pressed")
	if recorder.preview_kind != "template" or recorder.preview_id != "godot-dotnet-mcp://scene/{path}" or not recorder.preview_arguments.is_empty():
		return _failure("Template preview without arguments should still emit a template preview request for readable error feedback.")
	path_input.text = "tests/headless_suite_entry.tscn"
	path_input.emit_signal("text_changed", path_input.text)
	await tree.process_frame
	if not _text_edit_text(resources_tab, "PreviewText").contains("godot-dotnet-mcp://scene/tests/headless_suite_entry.tscn"):
		return _failure("Template detail panel should show the resolved URI after placeholder input.")
	_button(resources_tab, "PreviewButton").emit_signal("pressed")
	if recorder.preview_kind != "template" or str(recorder.preview_arguments.get("path", "")) != "tests/headless_suite_entry.tscn":
		return _failure("Template preview should emit placeholder argument values.")

	_select_entry(prompts_tab, "prompt", "godot.project_orientation")
	await tree.process_frame
	var goal_input := prompts_tab.find_child("ArgumentInput_goal", true, false) as LineEdit
	if goal_input == null:
		return _failure("Prompt detail panel should expose prompt argument inputs.")
	goal_input.text = "understand project"
	goal_input.emit_signal("text_changed", goal_input.text)
	_button(prompts_tab, "PreviewButton").emit_signal("pressed")
	if recorder.preview_kind != "prompt" or recorder.preview_id != "godot.project_orientation" or str(recorder.preview_arguments.get("goal", "")) != "understand project":
		return _failure("Prompt preview should emit current prompt argument values.")
	_button(prompts_tab, "ClearArgumentsButton").emit_signal("pressed")
	await tree.process_frame
	if str((prompts_tab.find_child("ArgumentInput_goal", true, false) as LineEdit).text) != "":
		return _failure("Clear should reset prompt argument input values.")

	var search := _line_edit(prompts_tab, "CatalogSearchEdit")
	search.text = "runtime"
	search.emit_signal("text_changed", search.text)
	await tree.process_frame
	if _has_entry_item(prompts_tab, "prompt", "godot.project_orientation"):
		return _failure("Prompt search should filter out non-matching workflow rows.")
	if not _has_entry_item(prompts_tab, "prompt", "godot.runtime_validation"):
		return _failure("Prompt search should keep matching workflow rows visible.")

	search.text = ""
	search.emit_signal("text_changed", search.text)
	await tree.process_frame
	var diagnostics_button := _button(resources_tab, "DiagnosticsViewButton")
	diagnostics_button.emit_signal("pressed")
	await tree.process_frame
	_select_entry(resources_tab, "resource", "godot-dotnet-mcp://state/editor")
	await tree.process_frame
	var diagnostics_text := _text_edit_text(resources_tab, "PreviewText")
	if not diagnostics_text.contains("Source: resources/list") or not diagnostics_text.contains("Visibility: public") or not diagnostics_text.contains("Icon: rejected"):
		return _failure("Resources Diagnostics view should expose source, visibility, and decoded icon status metadata.")

	var model_with_preview := model.duplicate(true)
	model_with_preview["mcp_catalog_preview"] = {
		"kind": "prompt",
		"id": "godot.runtime_validation",
		"success": true,
		"text": "user: Validate runtime behavior.",
		"arguments": {}
	}
	prompts_tab.apply_model(model_with_preview)
	await tree.process_frame
	_select_entry(prompts_tab, "prompt", "godot.runtime_validation")
	await tree.process_frame
	if not _text_edit_text(prompts_tab, "PreviewText").contains("Validate runtime behavior"):
		return _failure("Prompt detail panel should render matching preview results from the Dock model.")
	_button(prompts_tab, "CopyPreviewButton").emit_signal("pressed")
	if not recorder.copied_text.contains("Validate runtime behavior"):
		return _failure("Copy Preview should emit the rendered prompt preview text.")

	var resources_cache_error := _assert_icon_texture_cache_is_bounded(resources_tab, "Resources")
	if not resources_cache_error.is_empty():
		return _failure(resources_cache_error)

	await _cleanup(tree)
	return {"name": "mcp_catalog_tab_rendering_contracts", "success": true, "error": ""}


func _instantiate_tab(tree: SceneTree, mode: String):
	var instance = McpCatalogTabScene.instantiate()
	if instance == null:
		return null
	tree.root.add_child(instance)
	_instances.append(instance)
	await tree.process_frame
	instance.set_catalog_mode(mode)
	return instance


func _cleanup(tree: SceneTree) -> void:
	for instance in _instances:
		if is_instance_valid(instance):
			instance.queue_free()
	_instances.clear()
	await tree.process_frame


func _build_model() -> Dictionary:
	var model := _build_model_without_presentations()
	model["mcp_catalog_counts"] = {
		"resources": 3,
		"resource_templates": 1,
		"prompts": 3
	}
	model["mcp_resource_presentation"] = _build_resource_presentation(model)
	model["mcp_prompt_presentation"] = _build_prompt_presentation(model)
	return model


func _build_model_without_presentations() -> Dictionary:
	return {
		"localization": FakeLocalization.new(),
		"current_language": "en",
		"editor_scale": 1.0,
		"mcp_resources": [{
			"uri": "godot-dotnet-mcp://guides/index",
			"title": "Guide Index",
			"description": "Canonical guide catalog.",
			"mimeType": "application/json",
			"resource_kind": "guide",
			"icons": [_icon_metadata("guide")]
		}, {
			"uri": "godot-dotnet-mcp://state/editor",
			"title": "Editor State",
			"description": "Current editor state.",
			"mimeType": "application/json",
			"resource_kind": "state",
			"resource_group": "editor_state",
			"icons": [{"src": "data:text/plain;base64,%s" % Marshalls.raw_to_base64("not svg".to_utf8_buffer()), "mimeType": "text/plain", "sizes": ["any"]}]
		}, {
			"uri": "godot-dotnet-mcp://diagnostics/summary",
			"title": "Diagnostics Summary",
			"description": "Plugin diagnostics.",
			"mimeType": "application/json",
			"resource_kind": "diagnostic",
			"icons": [{"src": _oversized_icon_src(), "mimeType": "image/svg+xml", "sizes": ["any"]}]
		}],
		"mcp_resource_templates": [{
			"uri": "godot-dotnet-mcp://scene/{path}",
			"uriTemplate": "godot-dotnet-mcp://scene/{path}",
			"title": "Scene Resource",
			"description": "Inspect a scene by path.",
			"mimeType": "application/json",
			"resource_kind": "template",
			"is_template": true,
			"icons": [_icon_metadata("template")]
		}],
		"mcp_prompts": [{
			"name": "godot.project_orientation",
			"title": "Project Orientation",
			"description": "Orient an agent inside the current project.",
			"prompt_kind": "orientation",
			"arguments": [{"name": "goal", "description": "Optional goal."}, {"name": "include_scene", "description": "Optional scene flag."}],
			"icons": [_icon_metadata("orientation")]
		}, {
			"name": "godot.content_authoring",
			"title": "Content Authoring",
			"description": "Author content.",
			"prompt_kind": "authoring",
			"arguments": [{"name": "goal", "description": "Optional goal."}],
			"icons": [{"src": _non_svg_data_icon_src(), "mimeType": "image/svg+xml", "sizes": ["any"]}]
		}, {
			"name": "godot.runtime_validation",
			"title": "Runtime Validation",
			"description": "Validate runtime behavior.",
			"prompt_kind": "runtime",
			"arguments": [{"name": "scene_path", "description": "Optional scene path."}],
			"icons": [_icon_metadata("runtime")]
		}],
		"mcp_catalog_counts": {}
	}


func _build_resource_presentation(model: Dictionary) -> Dictionary:
	var resources := model.get("mcp_resources", []) as Array
	var templates := model.get("mcp_resource_templates", []) as Array
	return {
		"presentationVersion": 1,
		"view": "resource_catalog",
		"resourceTree": [{
			"id": "guides",
			"label_key": "mcp_resource_group_guides",
			"label": "Guides",
			"kind": "resource_group",
			"count": 1,
			"children": [_resource_node(resources[0] as Dictionary, "resource_entry")]
		}, {
			"id": "editor_state",
			"label_key": "mcp_resource_group_editor_state",
			"label": "Editor State",
			"kind": "resource_group",
			"count": 1,
			"children": [_resource_node(resources[1] as Dictionary, "resource_entry")]
		}, {
			"id": "advanced_resources",
			"label_key": "mcp_resource_group_advanced",
			"label": "Advanced Resources",
			"kind": "resource_group",
			"count": 1,
			"children": [_resource_node(resources[2] as Dictionary, "resource_entry")]
		}, {
			"id": "resource_templates",
			"label_key": "mcp_resource_group_templates",
			"label": "Resource Templates",
			"kind": "resource_group",
			"count": 1,
			"children": [_resource_node(templates[0] as Dictionary, "resource_template")]
		}]
	}


func _build_prompt_presentation(model: Dictionary) -> Dictionary:
	var prompts := model.get("mcp_prompts", []) as Array
	return {
		"presentationVersion": 1,
		"view": "prompt_catalog",
		"promptTree": [{
			"id": "project_understanding",
			"label_key": "mcp_prompt_group_project_understanding",
			"label": "Project Understanding",
			"kind": "prompt_group",
			"count": 1,
			"children": [_prompt_node(prompts[0] as Dictionary)]
		}, {
			"id": "editor_workflow",
			"label_key": "mcp_prompt_group_editor_workflow",
			"label": "Editor Workflow",
			"kind": "prompt_group",
			"count": 1,
			"children": [_prompt_node(prompts[1] as Dictionary)]
		}, {
			"id": "runtime_validation",
			"label_key": "mcp_prompt_group_runtime_validation",
			"label": "Runtime Validation",
			"kind": "prompt_group",
			"count": 1,
			"children": [_prompt_node(prompts[2] as Dictionary)]
		}]
	}


func _resource_node(entry: Dictionary, kind: String) -> Dictionary:
	var id := str(entry.get("uriTemplate", entry.get("uri", "")))
	return {
		"id": id,
		"label": str(entry.get("title", id)),
		"kind": kind,
		"resource_uri": id,
		"resource_kind": str(entry.get("resource_kind", "")),
		"resource_group": str(entry.get("resource_group", "")),
		"visibility": "public",
		"callability": "not_callable",
		"source": "resources/templates/list" if kind == "resource_template" else "resources/list",
		"metadata": {"description": str(entry.get("description", ""))},
		"entry": entry.duplicate(true),
		"children": []
	}


func _prompt_node(entry: Dictionary) -> Dictionary:
	var name := str(entry.get("name", ""))
	var children: Array[Dictionary] = []
	for arg in entry.get("arguments", []):
		if arg is Dictionary:
			children.append({"id": "%s/%s" % [name, str((arg as Dictionary).get("name", ""))], "kind": "prompt_argument", "metadata": (arg as Dictionary).duplicate(true)})
	return {
		"id": name,
		"label": str(entry.get("title", name)),
		"kind": "prompt_entry",
		"prompt_name": name,
		"prompt_kind": str(entry.get("prompt_kind", "")),
		"visibility": "public",
		"callability": "not_callable",
		"source": "prompts/list",
		"metadata": {"description": str(entry.get("description", ""))},
		"entry": entry.duplicate(true),
		"children": children
	}


func _icon_metadata(name: String) -> Dictionary:
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 16 16\"><title>%s</title><rect x=\"2\" y=\"2\" width=\"12\" height=\"12\" rx=\"2\" fill=\"currentColor\"/></svg>" % name.xml_escape()
	return {
		"src": "data:image/svg+xml;base64,%s" % Marshalls.raw_to_base64(svg.to_utf8_buffer()),
		"mimeType": "image/svg+xml",
		"sizes": ["any"]
	}


func _oversized_icon_src() -> String:
	var repeated := "<rect x=\"1\" y=\"1\" width=\"14\" height=\"14\" fill=\"currentColor\"/>".repeat(260)
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 16 16\">%s</svg>" % repeated
	return "data:image/svg+xml;base64,%s" % Marshalls.raw_to_base64(svg.to_utf8_buffer())


func _non_svg_data_icon_src() -> String:
	return "data:image/svg+xml;base64,%s" % Marshalls.raw_to_base64("not svg".to_utf8_buffer())


func _label_text(root: Node, name: String) -> String:
	var label := root.find_child(name, true, false) as Label
	return "" if label == null else label.text


func _button(root: Node, name: String) -> Button:
	return root.find_child(name, true, false) as Button


func _button_pressed(root: Node, name: String) -> bool:
	var button := _button(root, name)
	return button != null and button.button_pressed


func _line_edit(root: Node, name: String) -> LineEdit:
	return root.find_child(name, true, false) as LineEdit


func _text_edit_text(root: Node, name: String) -> String:
	var edit := root.find_child(name, true, false) as TextEdit
	return "" if edit == null else edit.text


func _tree(root: Node) -> Tree:
	return root.find_child("CatalogTree", true, false) as Tree


func _has_group_item(root: Node, group_id: String) -> bool:
	return _find_group_item(root, group_id) != null


func _has_entry_item(root: Node, kind: String, id: String) -> bool:
	return _find_entry_item(root, kind, id) != null


func _find_group_item(root: Node, group_id: String) -> TreeItem:
	var tree := _tree(root)
	if tree == null:
		return null
	return _find_tree_item(tree.get_root(), "group", group_id)


func _find_entry_item(root: Node, kind: String, id: String) -> TreeItem:
	var tree := _tree(root)
	if tree == null:
		return null
	return _find_tree_item(tree.get_root(), kind, id)


func _find_tree_item(item: TreeItem, kind: String, id: String) -> TreeItem:
	if item == null:
		return null
	var metadata = item.get_metadata(0)
	if metadata is Dictionary and str((metadata as Dictionary).get("kind", "")) == kind and str((metadata as Dictionary).get("id", "")) == id:
		return item
	var child := item.get_first_child()
	while child != null:
		var found := _find_tree_item(child, kind, id)
		if found != null:
			return found
		child = child.get_next()
	return null


func _select_entry(root: Node, kind: String, id: String) -> void:
	var item := _find_entry_item(root, kind, id)
	if item == null:
		return
	item.select(0)
	root.call("_on_tree_item_selected")


func _assert_icon_texture_cache_is_bounded(instance, label: String) -> String:
	var cache_limit := 64
	var prefix := "contract-%s-icon" % label.to_lower()
	for index in range(cache_limit + 8):
		var src := "%s-%03d" % [prefix, index]
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color(1.0, 1.0, 1.0, 1.0))
		instance.call("_store_icon_texture", src, ImageTexture.create_from_image(image))
	if int(instance._icon_texture_cache.size()) != cache_limit:
		return "%s tab protocol icon texture cache should be bounded to MAX_ICON_TEXTURE_CACHE_ENTRIES." % label
	if instance._icon_texture_cache.has("%s-000" % prefix):
		return "%s tab protocol icon texture cache should evict least-recently-used entries." % label
	return ""


func _verify_catalog_tab_uses_workbench_signatures() -> String:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/ui/mcp_catalog_tab.gd")
	if source.is_empty():
		return "MCP catalog tab source should be readable for rendering contract guards."
	var signature_start := source.find("func _build_signature")
	var scale_start := source.find("func _apply_editor_scale")
	if signature_start == -1 or scale_start == -1 or scale_start <= signature_start:
		return "MCP catalog tab should keep signature helpers before editor-scale rendering."
	var signature_section := source.substr(signature_start, scale_start - signature_start)
	if signature_section.find("JSON.stringify") != -1:
		return "MCP catalog tab signatures should avoid JSON serialization on refresh paths."
	for required in [
		"func _signature_value",
		"func _signature_scalar",
		"search=%s",
		"resource_presentation=%s",
		"prompt_presentation=%s",
		"template_argument_values=%s"
	]:
		if signature_section.find(required) == -1:
			return "MCP catalog tab signatures should cover workbench protocol inputs with lightweight deterministic parts: %s" % required
	if source.find("CatalogTree") == -1 or source.find("PreviewText") == -1:
		return "MCP catalog tab should render a Tree workbench and detail preview pane."
	return ""


func _failure(message: String) -> Dictionary:
	return {"name": "mcp_catalog_tab_rendering_contracts", "success": false, "error": message}
