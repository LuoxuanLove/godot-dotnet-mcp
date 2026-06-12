@tool
extends RefCounted

## Builds MCPToolLoader service context dictionaries from shared state and callables.
## The loader still owns the concrete operations; this service owns the wiring maps.

var _state_store


func configure(state_store) -> void:
	_state_store = state_store


func build_catalog_projection_context(callbacks: Dictionary) -> Dictionary:
	if _state_store != null and _state_store.has_method("build_catalog_projection_context"):
		return _state_store.build_catalog_projection_context(callbacks)
	return callbacks.duplicate(true)


func build_reload_context(callbacks: Dictionary) -> Dictionary:
	if _state_store != null and _state_store.has_method("build_reload_context"):
		return _state_store.build_reload_context(callbacks)
	return callbacks.duplicate(true)


func build_user_reload_context(callbacks: Dictionary) -> Dictionary:
	return build_reload_context(callbacks)


func build_runtime_state_context(callbacks: Dictionary) -> Dictionary:
	if _state_store != null and _state_store.has_method("build_runtime_state_context"):
		return _state_store.build_runtime_state_context(callbacks)
	return callbacks.duplicate(true)


func build_lifecycle_context(callbacks: Dictionary) -> Dictionary:
	if _state_store != null and _state_store.has_method("build_lifecycle_context"):
		return _state_store.build_lifecycle_context(callbacks)
	return callbacks.duplicate(true)
