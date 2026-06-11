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
		"mcp_catalog_arguments": "Arguments"
	}

	func get_text(key: String) -> String:
		return str(TEXTS.get(key, key))


class CopyRecorder extends RefCounted:
	var copied_text := ""
	var copied_source := ""

	func on_copy_requested(text: String, source: String) -> void:
		copied_text = text
		copied_source = source


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
			"resource_kind": "guide"
		}, {
			"uri": "godot-dotnet-mcp://state/editor",
			"title": "Editor State",
			"description": "Current editor state.",
			"mimeType": "application/json",
			"resource_kind": "state"
		}],
		"mcp_resource_templates": [{
			"uri": "godot-dotnet-mcp://scene/{path}",
			"uriTemplate": "godot-dotnet-mcp://scene/{path}",
			"title": "Scene Resource",
			"description": "Inspect a scene by path.",
			"mimeType": "application/json",
			"resource_kind": "template",
			"is_template": true
		}],
		"mcp_prompts": [{
			"name": "godot.project_orientation",
			"title": "Project Orientation",
			"description": "Orient an agent inside the current project.",
			"prompt_kind": "orientation",
			"arguments": [{"name": "goal"}, {"name": "include_scene"}]
		}, {
			"name": "godot.runtime_validation",
			"title": "Runtime Validation",
			"description": "Validate runtime behavior.",
			"prompt_kind": "runtime",
			"arguments": [{"name": "scene"}]
		}],
		"mcp_catalog_counts": {
			"resources": 2,
			"resource_templates": 1,
			"prompts": 2
		}
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


func _find_label_containing(root: Node, text: String) -> Label:
	for node in root.find_children("*", "Label", true, false):
		if node is Label and (node as Label).text.contains(text):
			return node as Label
	return null


func _failure(message: String) -> Dictionary:
	return {"name": "mcp_catalog_tab_rendering_contracts", "success": false, "error": message}
