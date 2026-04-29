extends RefCounted

const LspClientScript = preload("res://addons/godot_dotnet_mcp/tools/system/lsp_client.gd")
const TEMP_ROOT := "res://tests_tmp/lsp_client_contracts"


class FakeLspServer extends RefCounted:
	var _server := TCPServer.new()
	var _client: StreamPeerTCP
	var _buffer := PackedByteArray()
	var _received_messages: Array[Dictionary] = []
	var _queued_messages: Array[Dictionary] = []
	var _port := 0

	func start(port: int) -> bool:
		_port = port
		return _server.listen(port, "127.0.0.1") == OK

	func stop() -> void:
		if _client != null:
			_client.disconnect_from_host()
		_client = null
		if _server.is_listening():
			_server.stop()
		_buffer = PackedByteArray()
		_received_messages.clear()
		_queued_messages.clear()

	func tick() -> void:
		if _client == null and _server.is_connection_available():
			_client = _server.take_connection()
		if _client == null:
			return
		_client.poll()
		if _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return
		var available := _client.get_available_bytes()
		if available > 0:
			var packet := _client.get_data(available)
			if int(packet[0]) == OK and packet[1] is PackedByteArray:
				_buffer.append_array(packet[1] as PackedByteArray)
				_drain_messages()
		while not _queued_messages.is_empty():
			_send_message(_queued_messages[0])
			_queued_messages.remove_at(0)

	func drain_messages() -> Array[Dictionary]:
		var copy := _received_messages.duplicate(true)
		_received_messages.clear()
		return copy

	func queue_initialize_response(request_id: int) -> void:
		_queue_message({
			"jsonrpc": "2.0",
			"id": request_id,
			"result": {
				"capabilities": {}
			}
		})

	func queue_publish_diagnostics(uri: String, diagnostics: Array) -> void:
		_queue_message({
			"jsonrpc": "2.0",
			"method": "textDocument/publishDiagnostics",
			"params": {
				"uri": uri,
				"diagnostics": diagnostics
			}
		})

	func close_client() -> void:
		if _client != null:
			_client.disconnect_from_host()
		_client = null

	func _queue_message(message: Dictionary) -> void:
		_queued_messages.append(message.duplicate(true))

	func _send_message(message: Dictionary) -> void:
		if _client == null or _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return
		var body := JSON.stringify(message)
		var body_bytes := body.to_utf8_buffer()
		var header := ("Content-Length: %d\r\n\r\n" % body_bytes.size()).to_utf8_buffer()
		var frame := PackedByteArray()
		frame.append_array(header)
		frame.append_array(body_bytes)
		_client.put_data(frame)

	func _drain_messages() -> void:
		while true:
			var message := _try_parse_frame()
			if message.is_empty():
				return
			_received_messages.append(message)

	func _try_parse_frame() -> Dictionary:
		if _buffer.size() < 4:
			return {}
		var header_end := -1
		for index in range(_buffer.size() - 3):
			if _buffer[index] == 13 and _buffer[index + 1] == 10 and _buffer[index + 2] == 13 and _buffer[index + 3] == 10:
				header_end = index + 4
				break
		if header_end == -1:
			return {}
		var header := _buffer.slice(0, header_end).get_string_from_utf8()
		var content_length := -1
		for line in header.split("\r\n"):
			if line.to_lower().begins_with("content-length:"):
				content_length = int(line.substr(line.find(":") + 1).strip_edges())
				break
		if content_length < 0:
			_buffer = PackedByteArray()
			return {}
		if _buffer.size() - header_end < content_length:
			return {}
		var body_bytes := _buffer.slice(header_end, header_end + content_length)
		_buffer = _buffer.slice(header_end + content_length)
		var json := JSON.new()
		if json.parse(body_bytes.get_string_from_utf8()) != OK:
			return {}
		var data = json.get_data()
		if data is Dictionary:
			return (data as Dictionary).duplicate(true)
		return {}


func run_case(tree: SceneTree) -> Dictionary:
	_prepare_temp_root()
	var gd_path := TEMP_ROOT.path_join("sample_contract.gd")
	var source_code := "extends Node\nfunc _ready() -> void:\n\tpass\n"
	_write_text(gd_path, source_code)

	var success_port := _pick_free_port(26105)
	if success_port < 0:
		return _failure("Could not reserve a TCP port for the fake success LSP server.")
	var success_server := FakeLspServer.new()
	if not success_server.start(success_port):
		return _failure("Failed to start the fake success LSP server.")
	var success_client = LspClientScript.new()
	success_client.set_endpoint_for_testing("127.0.0.1", success_port)
	success_client.start_diagnostics(gd_path, source_code, 1000)
	var success_status: Dictionary = await _drive_success_case(tree, success_server, success_client)
	success_server.stop()
	if not bool(success_status.get("available", false)):
		return _failure("LSP client did not finish the initialize + publishDiagnostics flow successfully.")
	if int(success_status.get("error_count", 0)) != 1 or int(success_status.get("warning_count", 0)) != 1:
		return _failure("LSP client did not preserve publishDiagnostics severity counts.")

	var cancel_port := _pick_free_port(success_port + 1)
	if cancel_port < 0:
		return _failure("Could not reserve a TCP port for the fake cancel/retry LSP server.")
	var cancel_server := FakeLspServer.new()
	if not cancel_server.start(cancel_port):
		return _failure("Failed to start the fake cancel/retry LSP server.")
	var cancel_client = LspClientScript.new()
	cancel_client.set_endpoint_for_testing("127.0.0.1", cancel_port)
	cancel_client.start_diagnostics(gd_path, source_code, 1000)
	cancel_client.cancel()
	var cancel_status: Dictionary = cancel_client.get_status()
	cancel_server.stop()
	if cancel_client.has_active_request() or str(cancel_status.get("state", "")) != "idle":
		return _failure("LSP client cancel() should clear the active request and reset the state to idle.")

	var retry_port := _pick_free_port(cancel_port + 1)
	if retry_port < 0:
		return _failure("Could not reserve a TCP port for the fake retry LSP server.")
	var retry_server := FakeLspServer.new()
	if not retry_server.start(retry_port):
		return _failure("Failed to start the fake retry LSP server.")
	cancel_client.set_endpoint_for_testing("127.0.0.1", retry_port)
	cancel_client.start_diagnostics(gd_path, source_code, 1000)
	var retry_status: Dictionary = await _drive_success_case(tree, retry_server, cancel_client)
	retry_server.stop()
	if not bool(retry_status.get("available", false)):
		return _failure("LSP client should recover and succeed after cancel() followed by a fresh retry.")

	var timeout_port := _pick_free_port(retry_port + 1)
	if timeout_port < 0:
		return _failure("Could not reserve a TCP port for the fake timeout LSP server.")
	var timeout_server := FakeLspServer.new()
	if not timeout_server.start(timeout_port):
		return _failure("Failed to start the fake timeout LSP server.")
	var timeout_client = LspClientScript.new()
	timeout_client.set_endpoint_for_testing("127.0.0.1", timeout_port)
	timeout_client.start_diagnostics(gd_path, source_code, 120)
	var timeout_status: Dictionary = await _drive_timeout_case(tree, timeout_server, timeout_client)
	timeout_server.stop()
	if bool(timeout_status.get("available", false)) or str(timeout_status.get("error", "")).find("No diagnostics received within timeout") == -1:
		return _failure("LSP client should fail with a timeout when publishDiagnostics never arrives.")

	var failed_port := _pick_free_port(timeout_port + 1)
	if failed_port < 0:
		return _failure("Could not reserve a TCP port for the fake connection failure probe.")
	var failed_client = LspClientScript.new()
	failed_client.set_endpoint_for_testing("127.0.0.1", failed_port)
	failed_client.start_diagnostics(gd_path, source_code, 250)
	var failure_status: Dictionary = await _drive_connection_failure_case(tree, failed_client)
	var failure_message := str(failure_status.get("error", ""))
	if bool(failure_status.get("available", false)) or (
		failure_message.find("Cannot connect") == -1
		and failure_message.find("connection failed") == -1
		and failure_message.find("connection timeout") == -1
	):
		return _failure("LSP client should report a connection failure when no LSP endpoint is listening.")
	if failure_message.find("connection timeout") != -1 and failure_message.find("250ms") == -1:
		return _failure("LSP client connection timeout errors should reflect the effective request timeout instead of a hard-coded duration.")

	var restart_port := _pick_free_port(failed_port + 1)
	if restart_port < 0:
		return _failure("Could not reserve a TCP port for the fake restart-after-failure LSP server.")
	var restart_server := FakeLspServer.new()
	if not restart_server.start(restart_port):
		return _failure("Failed to start the fake restart-after-failure LSP server.")
	failed_client.set_endpoint_for_testing("127.0.0.1", restart_port)
	failed_client.start_diagnostics(gd_path, source_code, 1000)
	var restarted_status: Dictionary = await _drive_success_case(tree, restart_server, failed_client)
	restart_server.stop()
	if not bool(restarted_status.get("available", false)):
		return _failure("LSP client should recover after a failed request and complete a subsequent retry successfully.")

	return {
		"name": "lsp_client_contracts",
		"success": true,
		"error": "",
		"details": {
			"cancel_state": str(cancel_status.get("state", "")),
			"success_error_count": int(success_status.get("error_count", 0)),
			"success_warning_count": int(success_status.get("warning_count", 0)),
			"retry_available": bool(retry_status.get("available", false)),
			"timeout_error": str(timeout_status.get("error", "")),
			"failure_error": failure_message,
			"restart_available": bool(restarted_status.get("available", false))
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_remove_tree(TEMP_ROOT)


func _drive_success_case(tree: SceneTree, server: FakeLspServer, client) -> Dictionary:
	var initialize_sent := false
	var diagnostics_sent := false
	for _index in range(40):
		server.tick()
		for message in server.drain_messages():
			if str(message.get("method", "")) == "initialize" and not initialize_sent:
				server.queue_initialize_response(int(message.get("id", 1)))
				initialize_sent = true
			elif str(message.get("method", "")) == "textDocument/didOpen" and not diagnostics_sent:
				var params = message.get("params", {})
				var text_document = params.get("textDocument", {}) if params is Dictionary else {}
				var uri := str((text_document as Dictionary).get("uri", ""))
				server.queue_publish_diagnostics(uri, [
					{
						"severity": 1,
						"message": "Contract error",
						"range": {
							"start": {"line": 0, "character": 0},
							"end": {"line": 0, "character": 5}
						}
					},
					{
						"severity": 2,
						"message": "Contract warning",
						"range": {
							"start": {"line": 1, "character": 0},
							"end": {"line": 1, "character": 4}
						}
					}
				])
				diagnostics_sent = true
		client.tick(0.0)
		var status: Dictionary = client.get_status()
		if bool(status.get("finished", false)):
			return status
		await tree.process_frame
	return client.get_status()


func _drive_timeout_case(tree: SceneTree, server: FakeLspServer, client) -> Dictionary:
	var initialize_sent := false
	for _index in range(12):
		server.tick()
		for message in server.drain_messages():
			if str(message.get("method", "")) == "initialize" and not initialize_sent:
				server.queue_initialize_response(int(message.get("id", 1)))
				initialize_sent = true
		client.tick(0.0)
		var status: Dictionary = client.get_status()
		if bool(status.get("finished", false)):
			return status
		await tree.create_timer(0.03).timeout
	return client.get_status()


func _drive_connection_failure_case(tree: SceneTree, client) -> Dictionary:
	for _index in range(12):
		client.tick(0.0)
		var status: Dictionary = client.get_status()
		if bool(status.get("finished", false)):
			return status
		await tree.create_timer(0.03).timeout
	return client.get_status()


func _pick_free_port(start_port: int) -> int:
	for port in range(start_port, start_port + 20):
		var probe := TCPServer.new()
		if probe.listen(port, "127.0.0.1") == OK:
			probe.stop()
			return port
	return -1


func _prepare_temp_root() -> void:
	_remove_tree(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))


func _write_text(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create LSP client contract fixture: %s" % path)
		return
	file.store_string(content)
	file.close()


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var dir = DirAccess.open(absolute_path)
	if dir == null:
		DirAccess.remove_absolute(absolute_path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path := absolute_path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree(ProjectSettings.localize_path(child_path))
			else:
				DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "lsp_client_contracts",
		"success": false,
		"error": message
	}
