@tool
extends EditorPlugin

const OnlyCaseEnvVar := "GODOT_PLUGIN_HARNESS_ONLY_CASE"
const EditorProbeCases := {
	"plugin_entrypoint_contracts": "res://tests/plugin_entrypoint_contract_test.gd",
	"plugin_update_settings_persistence_contracts": "res://tests/plugin_update_settings_persistence_contract_test.gd"
}

var _started := false


func _enter_tree() -> void:
	if not EditorProbeCases.has(OS.get_environment(OnlyCaseEnvVar).strip_edges()):
		return
	call_deferred("_run_probe")


func _run_probe() -> void:
	if _started:
		return
	_started = true
	await get_tree().process_frame
	await get_tree().process_frame
	var case_name := OS.get_environment(OnlyCaseEnvVar).strip_edges()
	var case_script = load(str(EditorProbeCases.get(case_name, "")))
	if case_script == null or not case_script.has_method("new"):
		print(JSON.stringify({"name": case_name, "success": false, "error": "Editor probe case script should load."}))
		get_tree().quit(1)
		return
	var case_instance = case_script.new()
	var result: Dictionary = await case_instance.run_case(get_tree())
	if case_instance.has_method("cleanup_case"):
		await case_instance.cleanup_case(get_tree())
	await _wait_for_editor_file_system_scan()
	print(JSON.stringify(result))
	get_tree().quit(0 if bool(result.get("success", false)) else 1)


func _wait_for_editor_file_system_scan() -> void:
	var editor_interface = get_editor_interface()
	if editor_interface == null:
		return
	var file_system = editor_interface.get_resource_filesystem()
	if file_system == null:
		return
	for _index in range(240):
		if not file_system.is_scanning():
			return
		await get_tree().process_frame


func _exit_tree() -> void:
	pass
