extends RefCounted

var _process_service
var _attach_service
var _localization
var _dock_presenter
var _show_message := Callable()
var _show_confirmation := Callable()
var _refresh_dock := Callable()


func configure(
	process_service,
	attach_service,
	localization,
	dock_presenter,
	callbacks: Dictionary
) -> void:
	_process_service = process_service
	_attach_service = attach_service
	_localization = localization
	_dock_presenter = dock_presenter
	_show_message = callbacks.get("show_message", Callable())
	_show_confirmation = callbacks.get("show_confirmation", Callable())
	_refresh_dock = callbacks.get("refresh_dock", Callable())


func handle_detect_requested() -> void:
	if _process_service == null:
		return
	var status = _process_service.refresh_detection()
	_call_refresh_dock()
	_call_show_message(_resolve_process_feedback(status, "detect"))


func handle_install_requested() -> void:
	if _process_service == null:
		return
	var preview = _process_service.refresh_detection()
	if not bool(preview.get("install_available", false)):
		_call_show_message(_resolve_process_feedback(preview, "detect"))
		return
	_call_show_confirmation(_build_install_confirmation(preview), Callable(self, "_perform_install"))


func handle_start_requested() -> void:
	if _process_service == null:
		return
	var status = _process_service.start_service()
	_call_refresh_dock()
	if str(status.get("status", "")) == "launch_error":
		_call_show_message(_resolve_process_feedback(status, "start"))
		return
	_request_attach_soon()
	_call_show_message(_resolve_process_feedback(status, "start"))


func handle_stop_requested() -> void:
	if _process_service == null:
		return
	var status = _process_service.stop_service()
	_call_refresh_dock()
	if str(status.get("status", "")) == "launch_error":
		_call_show_message(_resolve_process_feedback(status, "stop_error"))
		return
	_call_show_message(_resolve_process_feedback(status, "stop_success"))


func handle_open_install_dir_requested() -> void:
	if _process_service == null:
		return
	var result = _process_service.open_install_directory()
	if not bool(result.get("success", false)):
		_call_show_message(_get_localized_text("central_server_open_install_dir_failed"))
		return
	_call_show_message(_get_localized_text("central_server_open_install_dir_success"))


func handle_open_logs_requested() -> void:
	if _process_service == null:
		return
	var result = _process_service.open_log_location()
	if not bool(result.get("success", false)):
		_call_show_message(_get_localized_text("central_server_open_logs_failed"))
		return
	_call_show_message(_get_localized_text("central_server_open_logs_success"))


func _perform_install() -> void:
	if _process_service == null:
		return
	var status = _process_service.install_or_update_service()
	_call_refresh_dock()
	if not bool(status.get("success", false)):
		_call_show_message(_resolve_process_feedback(status, "install_error"))
		return

	var running_status = _process_service.ensure_service_running()
	_request_attach_soon()
	var success_message = _resolve_process_feedback(status, "install_success")
	var install_details = _build_install_details(status)
	if install_details.is_empty():
		_call_show_message(success_message)
	else:
		_call_show_message("%s\n\n%s" % [success_message, install_details])
	if str(running_status.get("status", "")) == "launch_error":
		_call_show_message(_resolve_process_feedback(running_status, "start"))


func _request_attach_soon() -> void:
	if _attach_service != null:
		_attach_service.request_attach_soon()


func _resolve_process_feedback(status: Dictionary, action: String) -> String:
	if _dock_presenter != null:
		return _dock_presenter.resolve_central_server_process_feedback(status, action, _localization)
	return str(status.get("message", ""))


func _build_install_confirmation(status: Dictionary) -> String:
	if _dock_presenter != null:
		return _dock_presenter.build_central_server_install_confirmation(status, _localization)
	return str(status.get("message", ""))


func _build_install_details(status: Dictionary) -> String:
	if _dock_presenter != null:
		return _dock_presenter.build_central_server_install_details(status, _localization)
	return ""


func _get_localized_text(key: String) -> String:
	if _localization == null:
		return key
	return _localization.get_text(key)


func _call_show_message(message: String) -> void:
	if _show_message.is_valid():
		_show_message.call(message)


func _call_show_confirmation(message: String, on_confirmed: Callable) -> void:
	if _show_confirmation.is_valid():
		_show_confirmation.call(message, on_confirmed)
		return
	if on_confirmed.is_valid():
		on_confirmed.call()


func _call_refresh_dock() -> void:
	if _refresh_dock.is_valid():
		_refresh_dock.call()
