@tool
extends Node

var _plugin_id := ""
var _phase := 0
var _editor_interface


func configure(plugin_id: String, editor_interface) -> void:
	_plugin_id = plugin_id
	_editor_interface = editor_interface


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _process(_delta: float) -> void:
	var editor_interface = _get_editor_interface()
	if editor_interface == null or _plugin_id.is_empty():
		queue_free()
		return

	match _phase:
		0:
			editor_interface.set_plugin_enabled(_plugin_id, false)
			_phase = 1
		1:
			editor_interface.set_plugin_enabled(_plugin_id, true)
			queue_free()


func _get_editor_interface():
	if _editor_interface != null and is_instance_valid(_editor_interface):
		return _editor_interface
	return null
