@tool
extends RefCounted


func start_refs_request(
	request_parent: Node,
	request_name: String,
	url: String,
	headers: PackedStringArray,
	completed_callback: Callable,
	endpoint_config
) -> Dictionary:
	return start_request(
		request_parent,
		request_name,
		url,
		headers,
		completed_callback,
		float(endpoint_config.get_refs_http_timeout()),
		int(endpoint_config.get_refs_body_size_limit())
	)


func start_small_refs_request(
	request_parent: Node,
	request_name: String,
	url: String,
	headers: PackedStringArray,
	completed_callback: Callable,
	endpoint_config
) -> Dictionary:
	return start_request(
		request_parent,
		request_name,
		url,
		headers,
		completed_callback,
		float(endpoint_config.get_refs_http_timeout()),
		65536
	)


func start_sync_archive_request(
	request_parent: Node,
	request_name: String,
	url: String,
	headers: PackedStringArray,
	completed_callback: Callable,
	endpoint_config,
	archive_path: String
) -> Dictionary:
	return start_request(
		request_parent,
		request_name,
		url,
		headers,
		completed_callback,
		float(endpoint_config.get_sync_http_timeout()),
		int(endpoint_config.get_sync_body_size_limit()),
		archive_path
	)


func start_request(
	request_parent: Node,
	request_name: String,
	url: String,
	headers: PackedStringArray,
	completed_callback: Callable,
	timeout: float,
	body_size_limit: int,
	download_file: String = ""
) -> Dictionary:
	if request_parent == null:
		return {"success": false, "error": FAILED, "message": "No active update request host.", "request_node": null}
	var request_node := HTTPRequest.new()
	configure_request_node(request_node, request_name, timeout, body_size_limit, download_file)
	request_parent.add_child(request_node)
	request_node.request_completed.connect(Callable(self, "_free_completed_request").bind(request_node), CONNECT_ONE_SHOT)
	if completed_callback.is_valid():
		request_node.request_completed.connect(completed_callback, CONNECT_ONE_SHOT)
	var error := request_node.request(url, headers)
	if error != OK:
		request_node.queue_free()
		return {"success": false, "error": error, "message": "Failed to start update HTTP request.", "request_node": null}
	return {"success": true, "error": OK, "message": "", "request_node": request_node}


func configure_request_node(request_node: HTTPRequest, request_name: String, timeout: float, body_size_limit: int, download_file: String = "") -> void:
	request_node.name = request_name
	request_node.timeout = timeout
	request_node.body_size_limit = body_size_limit
	if not download_file.is_empty():
		request_node.download_file = download_file


func _free_completed_request(
	_result: int,
	_response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray,
	request_node: HTTPRequest
) -> void:
	if request_node != null and is_instance_valid(request_node):
		request_node.queue_free()
