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
		"mcp_catalog_arguments": "Arguments",
		"mcp_catalog_preview": "Preview",
		"mcp_catalog_preview_title": "Preview",
		"mcp_catalog_preview_empty": "Preview returned no text.",
		"mcp_catalog_preview_error": "Preview failed: %s",
		"mcp_catalog_copy_preview": "Copy Preview",
		"mcp_catalog_argument_placeholder": "Enter argument value",
		"mcp_catalog_template_preview_unavailable": "Provide a concrete resource URI from this template before reading it."
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

	if _label_text(resources_tab, "HeaderCounts") != "Resources: 2 | Templates: 1":
		return _failure("Resources tab should render resource/template counts from the Dock protocol model.")
	if _label_text(prompts_tab, "HeaderCounts") != "Prompts: 2":
		return _failure("Prompts tab should render prompt counts from the Dock protocol model.")
	if not resources_tab.find_child("ResourcesCard", true, false).visible or not resources_tab.find_child("TemplatesCard", true, false).visible or resources_tab.find_child("PromptsCard", true, false).visible:
		return _failure("Resources tab should show Resources and Resource Templates while hiding Prompts.")
	if prompts_tab.find_child("ResourcesCard", true, false).visible or prompts_tab.find_child("TemplatesCard", true, false).visible or not prompts_tab.find_child("PromptsCard", true, false).visible:
		return _failure("Prompts tab should show Prompts while hiding resource sections.")
	if _find_entry_card(resources_tab, "resource", "godot-dotnet-mcp://guides/index") == null:
		return _failure("Resources tab should render canonical guide resources by URI.")
	if _find_entry_card(resources_tab, "template", "godot-dotnet-mcp://scene/{path}") == null:
		return _failure("Resources tab should render resource templates by URI template.")
	if _find_entry_card(prompts_tab, "prompt", "godot.project_orientation") == null:
		return _failure("Prompts tab should render workflow prompts by name.")
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
	if _find_label_containing(resources_tab, "application/json") == null:
		return _failure("Resources tab should display resource mime type metadata.")
	if _find_label_containing(prompts_tab, "goal, include_scene") == null:
		return _failure("Prompts tab should display prompt argument metadata.")
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


func _build_model() -> Dictionary:
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
			"icons": [{"src": "data:text/plain;base64,%s" % Marshalls.raw_to_base64("not svg".to_utf8_buffer()), "mimeType": "text/plain", "sizes": ["any"]}]
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
			"name": "godot.runtime_validation",
			"title": "Runtime Validation",
			"description": "Validate runtime behavior.",
			"prompt_kind": "runtime",
			"arguments": [{"name": "scene"}],
			"icons": [_icon_metadata("runtime")]
		}],
		"mcp_catalog_counts": {
			"resources": 2,
			"resource_templates": 1,
			"prompts": 2
		}
	}


func _icon_metadata(name: String) -> Dictionary:
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 16 16\"><title>%s</title><rect x=\"2\" y=\"2\" width=\"12\" height=\"12\" rx=\"2\" fill=\"currentColor\"/></svg>" % name.xml_escape()
	return {
		"src": "data:image/svg+xml;base64,%s" % Marshalls.raw_to_base64(svg.to_utf8_buffer()),
		"mimeType": "image/svg+xml",
		"sizes": ["any"]
	}


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


func _find_label_containing(root: Node, text: String) -> Label:
	for node in root.find_children("*", "Label", true, false):
		if node is Label and (node as Label).text.contains(text):
			return node as Label
	return null


func _failure(message: String) -> Dictionary:
	return {"name": "mcp_catalog_tab_rendering_contracts", "success": false, "error": message}
