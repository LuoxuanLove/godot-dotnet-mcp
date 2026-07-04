extends RefCounted

# {"name": "plugin_path_csharp_registration_probe"}

const PROJECT_PROBE_PATH := "res://ProbeProjectScript.cs"
const INTERNAL_DOTNET_BRIDGE_DIR := "res://addons/godot_dotnet_mcp/.dotnet_bridge"
const INTERNAL_ROSLYN_SOURCE_DIR := "res://addons/godot_dotnet_mcp/.roslyn_source"
const RUNTIME_BUNDLE_DIR := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn_runtime"


func run_case(_tree: SceneTree) -> Dictionary:
	var project_script = load(PROJECT_PROBE_PATH)
	if project_script == null or not (project_script is Script):
		return _failure("Project-path C# probe could not be loaded")
	if not (project_script as Script).can_instantiate():
		return _failure("Project-path C# probe should still be compiled by the host project.")

	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(INTERNAL_DOTNET_BRIDGE_DIR)):
		return _failure("Installable addon stage should not expose internal .dotnet_bridge sources.")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(INTERNAL_ROSLYN_SOURCE_DIR)):
		return _failure("Installable addon stage should not expose internal .roslyn_source sources.")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/godot_dotnet_mcp/dotnet_bridge")):
		return _failure("Installable addon stage should not expose legacy dotnet_bridge sources.")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/godot_dotnet_mcp/plugin/runtime/roslyn")):
		return _failure("Installable addon stage should not expose plugin/runtime/roslyn sources.")

	if not FileAccess.file_exists("%s/GodotDotnetMcp.PluginBridge.dll" % RUNTIME_BUNDLE_DIR):
		return _failure("Runtime bundle DLL should remain Godot-visible for the exported Roslyn process.")
	if not FileAccess.file_exists("%s/roslyn-runtime-manifest.json" % RUNTIME_BUNDLE_DIR):
		return _failure("Runtime manifest should remain Godot-visible for the exported Roslyn process.")

	return {
		"name": "plugin_path_csharp_registration_probe",
		"success": true,
		"error": "",
		"details": {
			"project_can_instantiate": true,
			"installable_internal_sources_removed": true,
			"runtime_bundle_visible": true
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_path_csharp_registration_probe",
		"success": false,
		"error": message,
		"details": {}
	}
