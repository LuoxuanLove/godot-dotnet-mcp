extends RefCounted

const DiagnosticsServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd")


class FakeDiagnosticsClient extends RefCounted:
	var start_calls := 0
	var cancel_calls := 0
	var active := false
	var finish_on_tick := true
	var _status: Dictionary = {}

	func start_diagnostics(script_path: String, source_code: String, _timeout_ms: int) -> Dictionary:
		start_calls += 1
		active = true
		_status = {
			"available": false,
			"pending": true,
			"finished": false,
			"state": "connecting",
			"phase": "connecting",
			"script": script_path,
			"source_hash": str(source_code.hash()),
			"parse_errors": [],
			"error_count": 0,
			"warning_count": 0
		}
		return _status.duplicate(true)

	func has_active_request() -> bool:
		return active

	func tick(_delta: float) -> void:
		if not active or not finish_on_tick:
			return
		active = false
		_status = {
			"available": true,
			"pending": false,
			"finished": true,
			"state": "ready",
			"phase": "ready",
			"parse_errors": [],
			"error_count": 0,
			"warning_count": 0
		}

	func get_status() -> Dictionary:
		return _status.duplicate(true)

	func get_debug_snapshot() -> Dictionary:
		return {
			"start_calls": start_calls,
			"cancel_calls": cancel_calls,
			"active": active
		}

	func cancel() -> void:
		cancel_calls += 1
		active = false


var _service = null
var _factory_mode := "single"
var _single_client: FakeDiagnosticsClient
var _created_clients: Array[FakeDiagnosticsClient] = []


func run_case(_tree: SceneTree) -> Dictionary:
	_service = DiagnosticsServiceScript.new()
	_factory_mode = "single"
	_single_client = FakeDiagnosticsClient.new()
	_created_clients.clear()
	_service.set_client_factory_for_testing(Callable(self, "_create_client"))

	var first: Dictionary = _service.request_diagnostics("res://scripts/alpha.gd", "extends Node\n")
	if not bool(first.get("pending", false)):
		return _failure("Diagnostics service should return a pending status for a fresh request.")
	if _single_client.start_calls != 1:
		return _failure("Diagnostics service should start exactly one client request for the initial call.")

	var reused: Dictionary = _service.request_diagnostics("res://scripts/alpha.gd", "extends Node\n")
	if not bool(reused.get("pending", false)) and not bool(reused.get("finished", false)):
		return _failure("Diagnostics service should reuse the active request for the same script content instead of issuing a second request.")
	if _single_client.start_calls != 1:
		return _failure("Diagnostics service should not start a second request for the same active key.")

	_service.tick(0.0)
	var summary: Dictionary = _service.get_status_summary()
	if not bool(summary.get("available", false)) or not bool(summary.get("finished", false)):
		return _failure("Diagnostics service did not commit the finished client status after tick().")

	var cached: Dictionary = _service.request_diagnostics("res://scripts/alpha.gd", "extends Node\n")
	if not bool(cached.get("available", false)):
		return _failure("Diagnostics service should serve a finished result from cache for the same script content.")
	if _single_client.start_calls != 1:
		return _failure("Diagnostics service cache hit should not start a new client request.")

	_service.clear()
	var cleared_snapshot: Dictionary = _service.get_debug_snapshot()
	if int(cleared_snapshot.get("cache_entry_count", -1)) != 0:
		return _failure("Diagnostics service clear() should remove all cached entries.")

	_factory_mode = "replace"
	_created_clients.clear()
	_service.set_client_factory_for_testing(Callable(self, "_create_client"))
	var first_replace: Dictionary = _service.request_diagnostics("res://scripts/alpha.gd", "extends Node\n")
	if not bool(first_replace.get("pending", false)):
		return _failure("Diagnostics service replacement scenario should begin with a pending status.")
	var replace_result: Dictionary = _service.request_diagnostics("res://scripts/beta.gd", "extends Node\nvar speed := 1\n")
	if not bool(replace_result.get("pending", false)):
		return _failure("Diagnostics service should queue the replacement request after canceling the stale active request.")
	if _created_clients.size() != 2:
		return _failure("Diagnostics service should create a new client instance when replacing a stale active request.")
	if _created_clients[0].cancel_calls != 1:
		return _failure("Diagnostics service should cancel the stale active request before starting a replacement.")

	return {
		"name": "gdscript_lsp_diagnostics_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"cache_served": bool(cached.get("available", false)),
			"replaced_client_count": _created_clients.size()
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _service != null and _service.has_method("clear"):
		_service.clear()
	_service = null
	_single_client = null
	_created_clients.clear()


func _create_client():
	if _factory_mode == "single":
		return _single_client
	var client := FakeDiagnosticsClient.new()
	client.finish_on_tick = false
	_created_clients.append(client)
	return client


func _failure(message: String) -> Dictionary:
	return {
		"name": "gdscript_lsp_diagnostics_service_contracts",
		"success": false,
		"error": message
	}
