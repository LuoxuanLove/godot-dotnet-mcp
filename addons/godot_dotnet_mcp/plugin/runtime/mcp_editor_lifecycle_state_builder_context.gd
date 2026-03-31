@tool
extends RefCounted
class_name MCPEditorLifecycleStateBuilderContext

var get_plugin_host := Callable()


func dispose() -> void:
	get_plugin_host = Callable()
