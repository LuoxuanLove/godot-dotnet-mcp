@tool
extends "res://addons/godot_dotnet_mcp/plugin.gd"

class FakeEditorInterface extends RefCounted:
	var _base_control: Control


	func _init(base_control: Control) -> void:
		_base_control = base_control


	func get_base_control() -> Control:
		return _base_control


	func get_editor_scale() -> float:
		return 1.0


class FakeServerController extends "res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_controller.gd":

	var _fake_server: Node = Node.new()
	var _attached_plugin = null
	var _attached_settings: Dictionary = {}
	var _running := false


	func _init() -> void:
		_fake_server.name = "FakeServerControllerServer"


	func attach(plugin, settings: Dictionary) -> void:
		_attached_plugin = plugin
		_attached_settings = settings.duplicate(true)


	func detach() -> void:
		_running = false
		_attached_plugin = null
		_attached_settings = {}
		if _fake_server != null and is_instance_valid(_fake_server):
			_fake_server.free()
		_fake_server = null


	func start(_settings: Dictionary, _reason: String = "manual") -> bool:
		_running = true
		return true


	func get_server() -> Node:
		return _fake_server


var base_control: Control
var fake_editor_interface: FakeEditorInterface
var autoload_install_calls: Array[Dictionary] = []
var autoload_remove_calls: Array[String] = []
var debugger_add_calls: Array = []
var debugger_remove_calls: Array = []
var dock_add_calls: Array[Dictionary] = []
var dock_remove_calls: Array[Control] = []


func _init(base_control_in: Control) -> void:
	base_control = base_control_in
	fake_editor_interface = FakeEditorInterface.new(base_control_in)
	_server_controller = FakeServerController.new()


@warning_ignore("native_method_override")
func get_editor_interface():
	return fake_editor_interface


@warning_ignore("native_method_override")
func _create_server_controller():
	return FakeServerController.new()


@warning_ignore("native_method_override")
func _restore_pending_focus_snapshot_if_needed() -> void:
	return


@warning_ignore("native_method_override")
func add_autoload_singleton(name: String, path: String) -> void:
	autoload_install_calls.append({"name": name, "path": path})
	ProjectSettings.set_setting("autoload/%s" % name, path)


@warning_ignore("native_method_override")
func remove_autoload_singleton(name: String) -> void:
	autoload_remove_calls.append(name)
	ProjectSettings.set_setting("autoload/%s" % name, "")


@warning_ignore("native_method_override")
func add_debugger_plugin(plugin) -> void:
	debugger_add_calls.append(plugin)


@warning_ignore("native_method_override")
func remove_debugger_plugin(plugin) -> void:
	debugger_remove_calls.append(plugin)


@warning_ignore("native_method_override")
func add_control_to_dock(slot: int, dock: Control, shortcut = null) -> void:
	dock_add_calls.append({"slot": slot, "dock": dock})
	if dock.get_parent() != null:
		dock.get_parent().remove_child(dock)
	if base_control != null:
		base_control.add_child(dock)


@warning_ignore("native_method_override")
func remove_control_from_docks(dock: Control) -> void:
	dock_remove_calls.append(dock)
	if dock.get_parent() != null:
		dock.get_parent().remove_child(dock)
