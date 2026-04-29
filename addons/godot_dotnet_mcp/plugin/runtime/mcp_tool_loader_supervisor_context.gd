@tool
extends RefCounted
class_name MCPToolLoaderSupervisorContext

var log := Callable()
var record_registration_issue := Callable()


func dispose() -> void:
	log = Callable()
	record_registration_issue = Callable()
