extends RefCounted

# {"name": "dap_debugger_contracts"}

const SystemExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/system/executor.gd")

const CONTRACT_SOURCE_PATH := "res://scripts/contract_player.gd"
const REQUEST_TIMEOUT_MS := 800

var _servers: Array = []


class FakeDapServer extends Node:
	var _server := TCPServer.new()
	var _client: StreamPeerTCP
	var _buffer := PackedByteArray()
	var _received_messages: Array[Dictionary] = []
	var _queued_messages: Array[Dictionary] = []
	var _failed_commands: Array[String] = []
	var _output_on_connect := false
	var _output_sent := false

	func start(port: int, output_on_connect: bool = false) -> bool:
		_output_on_connect = output_on_connect
		set_process(true)
		return _server.listen(port, "127.0.0.1") == OK

	func stop() -> void:
		set_process(false)
		if _client != null:
			_client.disconnect_from_host()
		_client = null
		if _server.is_listening():
			_server.stop()
		_buffer = PackedByteArray()
		_received_messages.clear()
		_queued_messages.clear()

	func _process(_delta: float) -> void:
		tick()

	func tick() -> void:
		if _client == null and _server.is_connection_available():
			_client = _server.take_connection()
			if _output_on_connect and not _output_sent:
				_queue_output("contract output one\n")
				_queue_output("contract output two\n")
				_output_sent = true

		if _client == null:
			return
		_client.poll()
		if _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_client = null
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

	func fail_next_command(command: String) -> void:
		_failed_commands.append(command)

	func _queue_output(output: String) -> void:
		_queue_message({
			"seq": 1 + _queued_messages.size(),
			"type": "event",
			"event": "output",
			"body": {
				"category": "stdout",
				"output": output
			}
		})

	func _drain_messages() -> void:
		while true:
			var message := _try_parse_frame()
			if message.is_empty():
				return
			_received_messages.append(message)
			_auto_respond(message)

	func _auto_respond(message: Dictionary) -> void:
		if str(message.get("type", "")) != "request":
			return
		var command := str(message.get("command", ""))
		var request_seq := int(message.get("seq", 0))
		if _failed_commands.has(command):
			_failed_commands.erase(command)
			_queue_message({
				"seq": 100 + request_seq,
				"type": "response",
				"request_seq": request_seq,
				"success": false,
				"command": command,
				"message": "contract failure"
			})
			return
		var body := {}
		match command:
			"setBreakpoints":
				body = {"breakpoints": _build_verified_breakpoints(message)}
			"stackTrace":
				body = {
					"stackFrames": [
						{
							"id": 7,
							"name": "_ready",
							"line": 42,
							"column": 1,
							"source": {"path": ProjectSettings.globalize_path(CONTRACT_SOURCE_PATH)}
						}
					],
					"totalFrames": 1
				}
			"continue":
				body = {"allThreadsContinued": true}
			_:
				body = {}
		_queue_message({
			"seq": 100 + request_seq,
			"type": "response",
			"request_seq": request_seq,
			"success": true,
			"command": command,
			"body": body
		})

	func _build_verified_breakpoints(message: Dictionary) -> Array[Dictionary]:
		var args = message.get("arguments", {})
		var raw_breakpoints = args.get("breakpoints", []) if args is Dictionary else []
		var breakpoints: Array[Dictionary] = []
		if not (raw_breakpoints is Array):
			return breakpoints
		for raw_breakpoint in raw_breakpoints:
			if not (raw_breakpoint is Dictionary):
				continue
			breakpoints.append({
				"verified": true,
				"line": int((raw_breakpoint as Dictionary).get("line", 0))
			})
		return breakpoints

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
	var DapExecutorScript = load("res://addons/godot_dotnet_mcp/tools/dap/executor.gd")
	if DapExecutorScript == null:
		return _failure("DAP executor script should load.")
	var dap_executor = DapExecutorScript.new()
	var dap_tools: Array[Dictionary] = dap_executor.get_tools()
	var dap_tool := _find_tool(dap_tools, "debugger")
	if dap_tool.is_empty():
		return _failure("DAP executor should expose the debugger atomic tool.")
	var action_schema: Dictionary = dap_tool.get("inputSchema", {}).get("properties", {}).get("action", {})
	for action in ["status", "set_breakpoint", "remove_breakpoint", "list_breakpoints", "pause", "continue", "step_over", "stack_trace", "output"]:
		if not (action_schema.get("enum", []) as Array).has(action):
			return _failure("DAP debugger schema should expose action '%s'." % action)

	var unavailable_port := _pick_free_port(26606)
	if unavailable_port < 0:
		return _failure("Could not reserve an unavailable DAP port probe.")
	var unavailable_result: Dictionary = await dap_executor.execute_async("debugger", {
		"action": "pause",
		"host": "127.0.0.1",
		"port": unavailable_port,
		"thread_id": 1,
		"timeout_ms": 180
	})
	var unavailable_check := _expect_unavailable(unavailable_result, "pause")
	if not bool(unavailable_check.get("success", false)):
		return unavailable_check

	var request_port := _pick_free_port(unavailable_port + 1)
	if request_port < 0:
		return _failure("Could not reserve a fake DAP request server port.")
	var request_server = _start_server(tree, request_port)
	if request_server == null:
		return _failure("Failed to start the fake DAP request server.")

	var set_result: Dictionary = await dap_executor.execute_async("debugger", {
		"action": "set_breakpoint",
		"host": "127.0.0.1",
		"port": request_port,
		"timeout_ms": REQUEST_TIMEOUT_MS,
		"source_path": CONTRACT_SOURCE_PATH,
		"line": 42
	})
	if not bool(set_result.get("success", false)):
		return _failure("DAP set_breakpoint should complete against a fake DAP server: %s" % str(set_result.get("error", "")))
	var set_request := _find_command(request_server.drain_messages(), "setBreakpoints")
	if set_request.is_empty():
		return _failure("DAP set_breakpoint should send a setBreakpoints request frame.")
	var set_args: Dictionary = set_request.get("arguments", {})
	var source: Dictionary = set_args.get("source", {})
	if str(source.get("path", "")).find("contract_player.gd") == -1:
		return _failure("DAP setBreakpoints request should include the source path.")
	var requested_breakpoints: Array = set_args.get("breakpoints", [])
	if requested_breakpoints.size() != 1 or int((requested_breakpoints[0] as Dictionary).get("line", 0)) != 42:
		return _failure("DAP setBreakpoints request should include the requested line.")

	var list_result: Dictionary = dap_executor.execute("debugger", {"action": "list_breakpoints"})
	if not bool(list_result.get("success", false)):
		return _failure("DAP list_breakpoints should return the local breakpoint store.")
	if int(list_result.get("data", {}).get("count", 0)) != 1:
		return _failure("DAP list_breakpoints should include the breakpoint added by set_breakpoint.")
	request_server.fail_next_command("setBreakpoints")
	var failed_set_result: Dictionary = await dap_executor.execute_async("debugger", {
		"action": "set_breakpoint",
		"host": "127.0.0.1",
		"port": request_port,
		"timeout_ms": REQUEST_TIMEOUT_MS,
		"source_path": CONTRACT_SOURCE_PATH,
		"line": 77
	})
	if bool(failed_set_result.get("success", false)):
		return _failure("DAP set_breakpoint should propagate failed DAP responses.")
	if str(failed_set_result.get("data", {}).get("error_type", "")) != "dap_response_failed":
		return _failure("DAP set_breakpoint failures should include data.error_type=dap_response_failed.")
	request_server.drain_messages()
	list_result = dap_executor.execute("debugger", {"action": "list_breakpoints"})
	var cached_breakpoints: Array = list_result.get("data", {}).get("breakpoints", [])
	if int(list_result.get("data", {}).get("count", 0)) != 1 or int((cached_breakpoints[0] as Dictionary).get("line", 0)) != 42:
		return _failure("DAP failed set_breakpoint should not mutate the local breakpoint cache.")

	var remove_result: Dictionary = await dap_executor.execute_async("debugger", {
		"action": "remove_breakpoint",
		"host": "127.0.0.1",
		"port": request_port,
		"timeout_ms": REQUEST_TIMEOUT_MS,
		"source_path": CONTRACT_SOURCE_PATH,
		"line": 42
	})
	if not bool(remove_result.get("success", false)):
		return _failure("DAP remove_breakpoint should complete against a fake DAP server: %s" % str(remove_result.get("error", "")))
	var remove_request := _find_command(request_server.drain_messages(), "setBreakpoints")
	if remove_request.is_empty():
		return _failure("DAP remove_breakpoint should send a clearing setBreakpoints request frame.")
	var remove_args: Dictionary = remove_request.get("arguments", {})
	if (remove_args.get("breakpoints", []) as Array).size() != 0:
		return _failure("DAP remove_breakpoint should clear the removed breakpoint from the request.")
	list_result = dap_executor.execute("debugger", {"action": "list_breakpoints"})
	if int(list_result.get("data", {}).get("count", 0)) != 0:
		return _failure("DAP successful remove_breakpoint should clear the local breakpoint cache.")

	var pause_result: Dictionary = await dap_executor.execute_async("debugger", {
		"action": "pause",
		"host": "127.0.0.1",
		"port": request_port,
		"timeout_ms": REQUEST_TIMEOUT_MS,
		"thread_id": 1
	})
	if not bool(pause_result.get("success", false)):
		return _failure("DAP pause should complete against a fake DAP server.")
	if _find_command(request_server.drain_messages(), "pause").is_empty():
		return _failure("DAP pause should send a pause request frame.")

	var stack_result: Dictionary = await dap_executor.execute_async("debugger", {
		"action": "stack_trace",
		"host": "127.0.0.1",
		"port": request_port,
		"timeout_ms": REQUEST_TIMEOUT_MS,
		"thread_id": 1
	})
	if not bool(stack_result.get("success", false)):
		return _failure("DAP stack_trace should complete against a fake DAP server.")
	var stack_body: Dictionary = stack_result.get("data", {}).get("response", {}).get("body", {})
	if (stack_body.get("stackFrames", []) as Array).is_empty():
		return _failure("DAP stack_trace should return stackFrames from the response body.")

	var output_port := _pick_free_port(request_port + 1)
	if output_port < 0:
		return _failure("Could not reserve a fake DAP output server port.")
	var output_server = _start_server(tree, output_port, true)
	if output_server == null:
		return _failure("Failed to start the fake DAP output server.")
	var output_result: Dictionary = await dap_executor.execute_async("debugger", {
		"action": "output",
		"host": "127.0.0.1",
		"port": output_port,
		"timeout_ms": 300
	})
	if not bool(output_result.get("success", false)):
		return _failure("DAP output should collect output events from a fake DAP server.")
	var output_lines: Array = output_result.get("data", {}).get("outputs", [])
	if output_lines.size() != 2:
		return _failure("DAP output should keep collecting output events until timeout.")
	if str((output_lines[0] as Dictionary).get("output", "")).find("contract output one") == -1 or str((output_lines[1] as Dictionary).get("output", "")).find("contract output two") == -1:
		return _failure("DAP output should preserve all output event payloads.")

	var system_executor = SystemExecutorScript.new()
	var system_tools: Array[Dictionary] = system_executor.get_tools()
	var system_tool := _find_tool(system_tools, "dap_debugger")
	if system_tool.is_empty():
		return _failure("System executor should expose the high-level system_dap_debugger tool.")
	var system_result: Dictionary = await system_executor.execute_async("dap_debugger", {
		"action": "pause",
		"host": "127.0.0.1",
		"port": unavailable_port,
		"thread_id": 1,
		"timeout_ms": 180
	})
	system_result = _expect_unavailable(system_result, "pause")
	if not bool(system_result.get("success", false)):
		return system_result

	return {
		"name": "dap_debugger_contracts",
		"success": true,
		"error": "",
		"details": {
			"dap_tool_count": dap_tools.size(),
			"request_port": request_port,
			"output_port": output_port,
			"stack_frame_count": (stack_body.get("stackFrames", []) as Array).size()
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	for server in _servers:
		if server != null and is_instance_valid(server):
			server.stop()
			if server.get_parent() != null:
				server.get_parent().remove_child(server)
			server.queue_free()
	_servers.clear()


func _start_server(tree: SceneTree, port: int, output_on_connect: bool = false):
	var server := FakeDapServer.new()
	tree.root.add_child(server)
	_servers.append(server)
	if not server.start(port, output_on_connect):
		return null
	return server


func _find_tool(tools: Array, name: String) -> Dictionary:
	for tool in tools:
		if tool is Dictionary and str((tool as Dictionary).get("name", "")) == name:
			return (tool as Dictionary)
	return {}


func _find_command(messages: Array, command: String) -> Dictionary:
	for message in messages:
		if message is Dictionary and str((message as Dictionary).get("command", "")) == command:
			return (message as Dictionary)
	return {}


func _expect_unavailable(result: Dictionary, action: String) -> Dictionary:
	if bool(result.get("success", false)):
		return _failure("DAP %s should return a structured dap_unavailable result when no endpoint is listening." % action)
	var data = result.get("data", {})
	if not (data is Dictionary):
		return _failure("DAP %s unavailable result should include structured data: %s" % [action, JSON.stringify(result)])
	if str((data as Dictionary).get("error_type", "")) != "dap_unavailable":
		return _failure("DAP %s unavailable result should set data.error_type=dap_unavailable: %s" % [action, JSON.stringify(result)])
	if str((data as Dictionary).get("endpoint", "")).find("127.0.0.1") == -1:
		return _failure("DAP %s unavailable result should include the endpoint." % action)
	return {"success": true}


func _pick_free_port(start_port: int) -> int:
	for port in range(start_port, start_port + 40):
		var probe := TCPServer.new()
		if probe.listen(port, "127.0.0.1") == OK:
			probe.stop()
			return port
	return -1


func _failure(message: String) -> Dictionary:
	return {
		"name": "dap_debugger_contracts",
		"success": false,
		"error": message
	}
