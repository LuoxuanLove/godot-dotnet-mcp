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
		"mcp_catalog_template_preview_unavailable": "Provide a concrete resource URI from this template before reading it.",
		"mcp_catalog_view_catalog": "Catalog",
		"mcp_catalog_view_diagnostics": "Diagnostics",
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


class CopyRecorder extends RefCounted:
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
	var source_guard := _verify_catalog_tab_uses_lightweight_signatures()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var resources_tab = await _instantiate_tab(tree, "resources")
	if resources_tab == null:
		return _failure("MCP catalog rendering test could not instantiate the Resources tab.")
	var prompts_tab = await _instantiate_tab(tree, "prompts")
	if prompts_tab == null:
		return _failure("MCP catalog rendering test could not instantiate the Prompts tab.")
	var recorder := CopyRecorder.new()
	resources_tab.copy_requested.connect(Callable(recorder, "on_copy_requested"))
	prompts_tab.copy_requested.connect(Callable(recorder, "on_copy_requested"))
	resources_tab.preview_requested.connect(Callable(recorder, "on_preview_requested"))
	prompts_tab.preview_requested.connect(Callable(recorder, "on_preview_requested"))
	var model := _build_model()
	resources_tab.apply_model(model)
	prompts_tab.apply_model(model)
	await tree.process_frame

	if _label_text(resources_tab, "HeaderCounts") != "Resources: 3 | Templates: 1":
		return _failure("Resources tab should render resource/template counts from the Dock protocol model.")
	if _label_text(prompts_tab, "HeaderCounts") != "Prompts: 3":
		return _failure("Prompts tab should render prompt counts from the Dock protocol model.")
	if not resources_tab.find_child("ResourcesCard", true, false).visible or not resources_tab.find_child("TemplatesCard", true, false).visible or resources_tab.find_child("PromptsCard", true, false).visible:
		return _failure("Resources tab should show Resources and Resource Templates while hiding Prompts.")
	if prompts_tab.find_child("ResourcesCard", true, false).visible or prompts_tab.find_child("TemplatesCard", true, false).visible or not prompts_tab.find_child("PromptsCard", true, false).visible:
		return _failure("Prompts tab should show Prompts while hiding resource sections.")
	var catalog_button := resources_tab.find_child("CatalogViewButton", true, false) as Button
	var diagnostics_button := resources_tab.find_child("DiagnosticsViewButton", true, false) as Button
	if catalog_button == null or diagnostics_button == null:
		return _failure("MCP catalog tabs should expose Catalog and Diagnostics view buttons.")
	if not catalog_button.button_pressed or diagnostics_button.button_pressed:
		return _failure("MCP catalog tabs should default to the Catalog view.")
	resources_tab.size = Vector2(320, 640)
	resources_tab.call("_apply_responsive_layout")
	await tree.process_frame
	if catalog_button.custom_minimum_size.x <= 0.0 or diagnostics_button.custom_minimum_size.x <= 0.0:
		return _failure("MCP catalog view buttons should keep stable minimum widths in narrow Dock layouts.")
	if catalog_button.tooltip_text != "Catalog" or diagnostics_button.tooltip_text != "Diagnostics":
		return _failure("MCP catalog view buttons should expose localized tooltips for clipped narrow labels.")
	if _find_entry_card(resources_tab, "resource", "godot-dotnet-mcp://guides/index") == null:
		return _failure("Resources tab should render canonical guide resources by URI.")
	if _find_entry_card(resources_tab, "template", "godot-dotnet-mcp://scene/{path}") == null:
		return _failure("Resources tab should render resource templates by URI template.")
	if _find_entry_card(prompts_tab, "prompt", "godot.project_orientation") == null:
		return _failure("Prompts tab should render workflow prompts by name.")
	if not _group_contains_entry_card(resources_tab, "guides", "resource", "godot-dotnet-mcp://guides/index"):
		return _failure("Resources tab should render guide resources inside the Guides presentation group.")
	if not _group_contains_entry_card(resources_tab, "editor_state", "resource", "godot-dotnet-mcp://state/editor"):
		return _failure("Resources tab should render editor state resources inside the Editor State presentation group.")
	if not _group_contains_entry_card(resources_tab, "advanced_resources", "resource", "godot-dotnet-mcp://diagnostics/summary"):
		return _failure("Resources tab should render diagnostics resources inside the Advanced Resources presentation group.")
	if not _group_contains_entry_card(resources_tab, "resource_templates", "template", "godot-dotnet-mcp://scene/{path}"):
		return _failure("Resources tab should render templates inside the Resource Templates presentation group.")
	if not _group_contains_entry_card(prompts_tab, "project_understanding", "prompt", "godot.project_orientation"):
		return _failure("Prompts tab should render orientation prompts inside the Project Understanding presentation group.")
	if not _group_contains_entry_card(prompts_tab, "runtime_validation", "prompt", "godot.runtime_validation"):
		return _failure("Prompts tab should render runtime prompts inside the Runtime Validation presentation group.")
	if _find_protocol_icon(resources_tab, "resource", "godot-dotnet-mcp://guides/index") == null:
		return _failure("Resources tab should render MCP resource icons from protocol metadata.")
	if _find_protocol_icon(resources_tab, "template", "godot-dotnet-mcp://scene/{path}") == null:
		return _failure("Resources tab should render MCP resource template icons from protocol metadata.")
	if _find_protocol_icon(prompts_tab, "prompt", "godot.project_orientation") == null:
		return _failure("Prompts tab should render MCP prompt icons from protocol metadata.")
	var invalid_icon := _find_protocol_icon(resources_tab, "resource", "godot-dotnet-mcp://state/editor")
	if invalid_icon == null or not (invalid_icon is Label):
		return _failure("Resources tab should render invalid protocol icons as bounded fallback labels.")
	if (invalid_icon as Control).custom_minimum_size.x > 24.0:
		return _failure("Protocol icon fallback should keep a bounded width in compact Dock layouts.")
	var oversized_icon := _find_protocol_icon(resources_tab, "resource", "godot-dotnet-mcp://diagnostics/summary")
	if oversized_icon == null or not (oversized_icon is Label):
		return _failure("Resources tab should reject oversized protocol icon metadata before SVG loading.")
	var non_svg_icon := _find_protocol_icon(prompts_tab, "prompt", "godot.content_authoring")
	if non_svg_icon == null or not (non_svg_icon is Label):
		return _failure("Prompts tab should reject decoded non-SVG protocol icon metadata before SVG loading.")
	if _find_label_containing(resources_tab, "application/json") == null:
		return _failure("Resources tab should display resource mime type metadata.")
	if _find_label_containing(prompts_tab, "goal, include_scene") == null:
		return _failure("Prompts tab should display prompt argument metadata.")
	diagnostics_button.emit_signal("pressed")
	await tree.process_frame
	if catalog_button.button_pressed or not diagnostics_button.button_pressed:
		return _failure("MCP catalog view buttons should stay mutually exclusive after switching to Diagnostics.")
	if _find_label_containing(resources_tab, "Source: resources/list") == null or _find_label_containing(resources_tab, "Visibility: public") == null:
		return _failure("Resources Diagnostics view should expose source and visibility metadata from presentation nodes.")
	if _find_label_containing(resources_tab, "Group: editor_state") == null:
		return _failure("Resources Diagnostics view should expose resource group metadata.")
	catalog_button.emit_signal("pressed")
	await tree.process_frame
	var prompt_catalog_button := prompts_tab.find_child("CatalogViewButton", true, false) as Button
	var prompt_diagnostics_button := prompts_tab.find_child("DiagnosticsViewButton", true, false) as Button
	if prompt_catalog_button == null or prompt_diagnostics_button == null:
		return _failure("Prompts tab should expose Catalog and Diagnostics view buttons.")
	prompt_diagnostics_button.emit_signal("pressed")
	await tree.process_frame
	if _find_label_containing(prompts_tab, "Source: prompts/list") == null or _find_label_containing(prompts_tab, "Arguments: 2") == null:
		return _failure("Prompts Diagnostics view should expose prompt source and argument count metadata.")
	prompt_catalog_button.emit_signal("pressed")
	await tree.process_frame
	var copy_button := _find_entry_card(prompts_tab, "prompt", "godot.project_orientation").find_child("CopyIdButton", true, false) as Button
	if copy_button == null:
		return _failure("MCP catalog entries should expose copy buttons for protocol identifiers.")
	copy_button.emit_signal("pressed")
	if recorder.copied_text != "godot.project_orientation" or recorder.copied_source != "Project Orientation":
		return _failure("MCP catalog copy buttons should emit the protocol identifier and display title.")
	var resource_preview_button := _find_entry_card(resources_tab, "resource", "godot-dotnet-mcp://guides/index").find_child("PreviewButton", true, false) as Button
	if resource_preview_button == null:
		return _failure("Resource cards should expose a read/preview button.")
	resource_preview_button.emit_signal("pressed")
	if recorder.preview_kind != "resource" or recorder.preview_id != "godot-dotnet-mcp://guides/index":
		return _failure("Resource preview buttons should request resources/read for the selected URI.")
	if _find_label_containing(resources_tab, "concrete resource URI") == null:
		return _failure("Resource templates should explain that preview requires a concrete URI.")
	var prompt_card := _find_entry_card(prompts_tab, "prompt", "godot.project_orientation")
	var goal_input := prompt_card.find_child("ArgumentInput_goal", true, false) as LineEdit
	if goal_input == null:
		return _failure("Prompt cards should render simple argument inputs from MCP prompt metadata.")
	goal_input.text = "map the project"
	goal_input.emit_signal("text_changed", "map the project")
	var prompt_preview_button := prompt_card.find_child("PreviewButton", true, false) as Button
	if prompt_preview_button == null:
		return _failure("Prompt cards should expose a preview button.")
	prompt_preview_button.emit_signal("pressed")
	if recorder.preview_kind != "prompt" or recorder.preview_id != "godot.project_orientation" or str(recorder.preview_arguments.get("goal", "")) != "map the project":
		return _failure("Prompt preview should emit the prompt name and current argument values.")
	var preview_model := _build_model()
	preview_model["mcp_catalog_preview"] = {
		"kind": "prompt",
		"id": "godot.project_orientation",
		"title": "Project Orientation",
		"success": true,
		"text": "Use resources/list before editing.",
		"arguments": {"goal": "map the project"}
	}
	prompts_tab.apply_model(preview_model)
	await tree.process_frame
	var preview_text := _find_label_containing(prompts_tab, "Use resources/list before editing.")
	if preview_text == null:
		return _failure("Prompt preview results should render generated prompts/get text.")
	var copy_preview_button := _find_entry_card(prompts_tab, "prompt", "godot.project_orientation").find_child("CopyPreviewButton", true, false) as Button
	if copy_preview_button == null:
		return _failure("Rendered preview results should expose a copy generated text button.")
	copy_preview_button.emit_signal("pressed")
	if recorder.copied_text != "Use resources/list before editing.":
		return _failure("Copy Preview should emit generated prompt text.")
	var resource_preview_model := _build_model()
	resource_preview_model["mcp_catalog_preview"] = {
		"kind": "resource",
		"id": "godot-dotnet-mcp://guides/index",
		"title": "Guide Index",
		"description": "Canonical guide catalog.",
		"success": true,
		"text": "{\"guides\":[]}",
		"mimeType": "application/json"
	}
	resources_tab.apply_model(resource_preview_model)
	await tree.process_frame
	var resource_preview_text := _find_label_containing(resources_tab, "{\"guides\":[]}")
	if resource_preview_text == null:
		return _failure("Resource preview results should render resources/read text.")
	copy_preview_button = _find_entry_card(resources_tab, "resource", "godot-dotnet-mcp://guides/index").find_child("CopyPreviewButton", true, false) as Button
	if copy_preview_button == null:
		return _failure("Rendered resource previews should expose a copy preview button.")
	copy_preview_button.emit_signal("pressed")
	if recorder.copied_text != "{\"guides\":[]}" or not recorder.copied_source.contains("Guide Index"):
		return _failure("Resource Copy Preview should emit resource text and the resource title.")
	goal_input = _find_entry_card(prompts_tab, "prompt", "godot.project_orientation").find_child("ArgumentInput_goal", true, false) as LineEdit
	goal_input.text = "map the runtime"
	goal_input.emit_signal("text_changed", "map the runtime")
	await tree.process_frame
	if _find_label_containing(prompts_tab, "Use resources/list before editing.") != null:
		return _failure("Prompt preview results should disappear immediately when current argument values no longer match the generated preview.")
	copy_preview_button = _find_entry_card(prompts_tab, "prompt", "godot.project_orientation").find_child("CopyPreviewButton", true, false) as Button
	if copy_preview_button != null:
		return _failure("Stale generated prompt text should not remain copyable immediately after prompt arguments change.")
	var resource_icon_cache_error := _assert_icon_texture_cache_is_bounded(resources_tab, "Resources")
	if not resource_icon_cache_error.is_empty():
		return _failure(resource_icon_cache_error)
	var prompt_icon_cache_error := _assert_icon_texture_cache_is_bounded(prompts_tab, "Prompts")
	if not prompt_icon_cache_error.is_empty():
		return _failure(prompt_icon_cache_error)

	return {"name": "mcp_catalog_tab_rendering_contracts", "success": true, "error": ""}


func cleanup_case(tree: SceneTree) -> void:
	for instance in _instances:
		if instance != null and is_instance_valid(instance):
			instance.queue_free()
	_instances.clear()
	await tree.process_frame


func _instantiate_tab(tree: SceneTree, mode: String):
	var instance = McpCatalogTabScene.instantiate()
	if instance == null:
		return null
	tree.root.add_child(instance)
	_instances.append(instance)
	await tree.process_frame
	instance.set_catalog_mode(mode)
	return instance


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
	var retained_key := "%s-%03d" % [prefix, cache_limit + 7]
	if not instance._icon_texture_cache.has(retained_key):
		return "%s tab protocol icon texture cache should retain recently inserted icons." % label
	var refreshed_key := "%s-%03d" % [prefix, cache_limit - 1]
	instance.call("_store_icon_texture", refreshed_key, instance._icon_texture_cache.get(refreshed_key))
	instance.call("_store_icon_texture", "%s-new" % prefix, ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8)))
	if not instance._icon_texture_cache.has(refreshed_key):
		return "%s tab protocol icon texture cache hits should refresh LRU order." % label
	return ""


func _verify_catalog_tab_uses_lightweight_signatures() -> String:
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
		"resources=%s",
		"prompt_presentation=%s",
		"argument_values=%s"
	]:
		if signature_section.find(required) == -1:
			return "MCP catalog tab signatures should cover protocol model inputs with lightweight deterministic parts: %s" % required
	return ""


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
			"arguments": [{"name": "goal"}, {"name": "include_scene"}],
			"icons": [_icon_metadata("orientation")]
		}, {
			"name": "godot.content_authoring",
			"title": "Content Authoring",
			"description": "Author content.",
			"prompt_kind": "authoring",
			"arguments": [{"name": "goal"}],
			"icons": [{"src": _non_svg_data_icon_src(), "mimeType": "image/svg+xml", "sizes": ["any"]}]
		}, {
			"name": "godot.runtime_validation",
			"title": "Runtime Validation",
			"description": "Validate runtime behavior.",
			"prompt_kind": "runtime",
			"arguments": [{"name": "scene"}],
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


func _find_entry_card(root: Node, kind: String, id: String) -> Control:
	for node in root.find_children("*", "PanelContainer", true, false):
		if not (node is Control):
			continue
		var control := node as Control
		if str(control.get_meta("mcp_catalog_kind", "")) == kind and str(control.get_meta("mcp_catalog_id", "")) == id:
			return control
	return null


func _find_protocol_icon(root: Node, kind: String, id: String) -> Control:
	var card := _find_entry_card(root, kind, id)
	if card == null:
		return null
	var icon := card.find_child("ProtocolIcon", true, false)
	if not (icon is Control):
		return null
	if str((icon as Control).get_meta("mcp_icon_src", "")).is_empty():
		return null
	return icon as Control


func _group_contains_entry_card(root: Node, group_id: String, kind: String, id: String) -> bool:
	var group := _find_group_section(root, group_id)
	if group == null:
		return false
	for node in group.find_children("*", "PanelContainer", true, false):
		if not (node is Control):
			continue
		var control := node as Control
		if str(control.get_meta("mcp_catalog_kind", "")) == kind and str(control.get_meta("mcp_catalog_id", "")) == id:
			return true
	return false


func _find_group_section(root: Node, group_id: String) -> Control:
	for node in root.find_children("*", "VBoxContainer", true, false):
		if node is Control and str((node as Control).get_meta("mcp_catalog_group_id", "")) == group_id:
			return node as Control
	return null


func _find_label_containing(root: Node, text: String) -> Label:
	for node in root.find_children("*", "Label", true, false):
		if node is Label and (node as Label).text.contains(text):
			return node as Label
	return null


func _failure(message: String) -> Dictionary:
	return {"name": "mcp_catalog_tab_rendering_contracts", "success": false, "error": message}
