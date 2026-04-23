@tool
extends EditorPlugin

const OnlyCaseEnvVar := "GODOT_PLUGIN_HARNESS_ONLY_CASE"
const TargetCaseName := "plugin_entrypoint_contracts"
const EntryPointContractTest = preload("res://tests/plugin_entrypoint_contract_test.gd")

var _started := false


func _enter_tree() -> void:
	if OS.get_environment(OnlyCaseEnvVar).strip_edges() != TargetCaseName:
		return
	call_deferred("_run_probe")


func _run_probe() -> void:
	if _started:
		return
	_started = true
	await get_tree().process_frame
	await get_tree().process_frame
	var case_instance = EntryPointContractTest.new()
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
