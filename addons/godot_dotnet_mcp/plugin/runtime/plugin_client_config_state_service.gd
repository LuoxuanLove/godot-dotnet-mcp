@tool
extends RefCounted
class_name PluginClientConfigStateService

const ClientInstallDetectionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_detection_service.gd")

var _client_install_detection_service = null
var _client_executable_dialog: FileDialog


func dispose() -> void:
	remove_client_executable_dialog()
	_client_install_detection_service = null


func get_client_install_detection_service():
	if _client_install_detection_service == null:
		_client_install_detection_service = ClientInstallDetectionServiceScript.new()
	return _client_install_detection_service


func get_client_install_statuses(settings: Dictionary) -> Dictionary:
	var detection_service = get_client_install_detection_service()
	configure_client_install_detection_service(settings)
	return detection_service.detect_all()


func invalidate_client_install_status_cache() -> void:
	if _client_install_detection_service == null:
		return
	_client_install_detection_service.invalidate_cache()


func configure_client_install_detection_service(settings: Dictionary) -> void:
	if _client_install_detection_service == null:
		return
	_client_install_detection_service.configure(settings)


func configure_client_executable_dialog(editor_interface, on_file_selected: Callable):
	if _client_executable_dialog != null and is_instance_valid(_client_executable_dialog):
		return _client_executable_dialog
	if editor_interface == null:
		return null
	var base_control = editor_interface.get_base_control()
	if base_control == null:
		return null
	_client_executable_dialog = FileDialog.new()
	_client_executable_dialog.name = "ClientExecutableDialog"
	_client_executable_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_client_executable_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_client_executable_dialog.filters = PackedStringArray([
		"*.exe ; Executable",
		"*.cmd ; Command Script",
		"*.bat ; Batch Script",
		"* ; All Files"
	])
	if on_file_selected.is_valid():
		_client_executable_dialog.file_selected.connect(on_file_selected)
	base_control.add_child(_client_executable_dialog)
	return _client_executable_dialog


func remove_client_executable_dialog() -> void:
	if _client_executable_dialog != null and is_instance_valid(_client_executable_dialog):
		for connection in _client_executable_dialog.file_selected.get_connections():
			var callable: Callable = connection.get("callable", Callable())
			if callable.is_valid():
				_client_executable_dialog.file_selected.disconnect(callable)
		var parent = _client_executable_dialog.get_parent()
		if parent != null:
			parent.remove_child(_client_executable_dialog)
		_client_executable_dialog.queue_free()
	_client_executable_dialog = null


func get_client_executable_dialog():
	return _client_executable_dialog
