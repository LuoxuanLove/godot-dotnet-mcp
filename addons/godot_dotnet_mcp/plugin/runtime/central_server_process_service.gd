@tool
extends RefCounted
class_name CentralServerProcessService

const CENTRAL_SERVER_DLL_NAME := "GodotDotnetMcp.CentralServer.dll"
const CENTRAL_SERVER_EXE_NAME := "GodotDotnetMcp.CentralServer.exe"
const DEFAULT_DOTNET_PATH := "C:/Program Files/dotnet/dotnet.exe"
const PROBE_INTERVAL_MS := 3000
const AUTO_START_RETRY_INTERVAL_MS := 15000
const LOCAL_INSTALL_RELATIVE_DIR := "GodotDotnetMcp/CentralServer/runtime"

var _plugin: EditorPlugin
var _settings: Dictionary = {}
var _pid := 0
var _status := "idle"
var _last_error := ""
var _last_command := ""
var _launch_info: Dictionary = {}
var _endpoint_reachable := false
var _last_probe_msec := 0
var _last_auto_start_attempt_msec := 0


func configure(plugin: EditorPlugin, settings: Dictionary) -> void:
	_plugin = plugin
	_settings = settings
	refresh_detection()


func tick() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_probe_msec >= PROBE_INTERVAL_MS:
		_probe_endpoint()
		_last_probe_msec = now

	if _pid > 0:
		if OS.is_process_running(_pid):
			if _status != "running":
				_status = "running"
			return
		_pid = 0
		if _status == "running" or _status == "starting":
			_status = "exited"
			if _endpoint_reachable:
				_status = "running"


func refresh_detection() -> Dictionary:
	_launch_info = _detect_launch_command()
	_probe_endpoint()
	return get_status()


func start_service() -> Dictionary:
	_last_auto_start_attempt_msec = Time.get_ticks_msec()
	_probe_endpoint()
	if _endpoint_reachable:
		_status = "running"
		_last_error = ""
		return get_status()

	if _pid > 0 and OS.is_process_running(_pid):
		_status = "running"
		return get_status()

	if _launch_info.is_empty():
		refresh_detection()
	if not bool(_launch_info.get("success", false)):
		_status = "launch_error"
		_last_error = str(_launch_info.get("message", "Central server launch command was not found."))
		return get_status()

	var executable_path := str(_launch_info.get("executable_path", "")).strip_edges()
	var arguments: PackedStringArray = _launch_info.get("arguments", PackedStringArray())
	var pid = OS.create_process(executable_path, arguments, false)
	if pid <= 0:
		_status = "launch_error"
		_last_error = "Failed to start central server process."
		return get_status()

	_pid = pid
	_status = "starting"
	_last_error = ""
	_last_command = str(_launch_info.get("display_command", ""))
	return get_status()


func stop_service() -> Dictionary:
	if _pid <= 0:
		_probe_endpoint()
		_status = "running" if _endpoint_reachable else "stopped"
		return get_status()

	var error := OS.kill(_pid)
	if error != OK:
		_status = "launch_error"
		_last_error = "Failed to stop central server process: %s" % error
		return get_status()

	_pid = 0
	_status = "stopped"
	_last_error = ""
	return get_status()


func get_status() -> Dictionary:
	if _launch_info.is_empty():
		refresh_detection()

	var install_dir = _get_local_install_dir()
	var local_install_ready = _has_runtime_in_dir(install_dir)
	var source_launch = _detect_source_launch_info()
	var source_runtime_available = bool(source_launch.get("success", false))
	var launch_available = bool(_launch_info.get("success", false))
	var launch_source = str(_launch_info.get("source", ""))
	var detected_command = str(_launch_info.get("display_command", ""))
	var message = _last_error
	if _endpoint_reachable and message.is_empty():
		message = "Central server endpoint is reachable."
	if message.is_empty():
		message = str(_launch_info.get("message", ""))

	return {
		"status": _status,
		"pid": _pid,
		"launch_available": launch_available,
		"launch_source": launch_source,
		"endpoint_reachable": _endpoint_reachable,
		"auto_launch_enabled": _is_auto_launch_enabled(),
		"local_endpoint": _build_endpoint(),
		"local_install_dir": install_dir,
		"local_install_ready": local_install_ready,
		"source_runtime_available": source_runtime_available,
		"install_available": source_runtime_available,
		"install_action": "upgrade" if local_install_ready else "install",
		"source_runtime_dir": str(source_launch.get("runtime_dir", "")),
		"detected_command": detected_command,
		"last_command": _last_command,
		"last_error": _last_error,
		"message": message
	}


func ensure_service_running() -> Dictionary:
	if not _is_auto_launch_enabled() or not _is_local_target():
		return get_status()

	_probe_endpoint()
	if _endpoint_reachable:
		_status = "running"
		_last_error = ""
		return get_status()

	if _pid > 0 and OS.is_process_running(_pid):
		_status = "running"
		return get_status()

	var now := Time.get_ticks_msec()
	if now - _last_auto_start_attempt_msec < AUTO_START_RETRY_INTERVAL_MS:
		return get_status()

	return start_service()


func install_or_update_service() -> Dictionary:
	var source_launch = _detect_source_launch_info()
	if not bool(source_launch.get("success", false)):
		return {
			"success": false,
			"status": "install_error",
			"message": str(source_launch.get("message", "No central server runtime is available for installation."))
		}

	if _pid > 0 and OS.is_process_running(_pid) and str(_launch_info.get("source", "")) == "local_install":
		return {
			"success": false,
			"status": "install_error",
			"message": "Stop the running local central server before upgrading it."
		}

	var bootstrap = _bootstrap_local_install(str(source_launch.get("runtime_dir", "")))
	_launch_info = _detect_launch_command()
	_probe_endpoint()

	var status = get_status()
	status["success"] = bool(bootstrap.get("success", false))
	status["status"] = "installed" if bool(bootstrap.get("success", false)) else "install_error"
	status["message"] = str(bootstrap.get("message", status.get("message", "")))
	return status


func _detect_launch_command() -> Dictionary:
	var explicit_command = str(_settings.get("central_server_command_path", "")).strip_edges()
	var explicit_args_raw = str(_settings.get("central_server_command_args", "")).strip_edges()

	if not explicit_command.is_empty():
		var explicit_args := PackedStringArray()
		if not explicit_args_raw.is_empty():
			explicit_args.append_array(explicit_args_raw.split(" ", false))
		return _make_launch_info(explicit_command, explicit_args, "settings")

	var installed_launch = _build_installed_launch_info()
	if bool(installed_launch.get("success", false)):
		return installed_launch

	var source_launch = _detect_source_launch_info()
	if bool(source_launch.get("success", false)):
		source_launch["message"] = "Using detected source central server runtime."
		return source_launch

	return {
		"success": false,
		"message": "No central server executable or DLL was detected."
	}


func _probe_endpoint() -> bool:
	if not _is_local_target():
		_endpoint_reachable = false
		return false

	var peer := StreamPeerTCP.new()
	var host := str(_settings.get("central_server_host", "127.0.0.1")).strip_edges()
	var port := int(_settings.get("central_server_port", 3020))
	var error := peer.connect_to_host(host, port)
	if error != OK:
		_endpoint_reachable = false
		return false

	var deadline := Time.get_ticks_msec() + 250
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() < deadline:
		OS.delay_msec(10)
		_poll_peer(peer)

	_endpoint_reachable = peer.get_status() == StreamPeerTCP.STATUS_CONNECTED
	if _endpoint_reachable and (_pid <= 0 or not OS.is_process_running(_pid)) and _status != "starting":
		_status = "running"
	elif not _endpoint_reachable and _pid <= 0 and _status == "running":
		_status = "idle"
	if peer.get_status() != StreamPeerTCP.STATUS_NONE:
		peer.disconnect_from_host()
	return _endpoint_reachable


func _poll_peer(peer: StreamPeerTCP) -> void:
	if peer == null:
		return
	if peer.has_method("poll"):
		peer.poll()


func _is_local_target() -> bool:
	var host := str(_settings.get("central_server_host", "127.0.0.1")).strip_edges().to_lower()
	return host == "127.0.0.1" or host == "localhost" or host == "::1"


func _is_auto_launch_enabled() -> bool:
	return bool(_settings.get("central_server_auto_launch", true))


func _build_endpoint() -> String:
	var host := str(_settings.get("central_server_host", "127.0.0.1")).strip_edges()
	var port := int(_settings.get("central_server_port", 3020))
	return "http://%s:%d/" % [host, port]


func _resolve_dotnet_path() -> String:
	var configured = str(_settings.get("central_server_dotnet_path", "")).strip_edges()
	if not configured.is_empty() and FileAccess.file_exists(configured):
		return configured

	var output: Array = []
	var exit_code := OS.execute("dotnet", PackedStringArray(["--version"]), output, true, false)
	if exit_code == 0:
		return "dotnet"

	if FileAccess.file_exists(DEFAULT_DOTNET_PATH):
		return DEFAULT_DOTNET_PATH

	return ""


func _make_launch_info(executable_path: String, arguments: PackedStringArray, source: String, message: String = "Central server launch command is ready.") -> Dictionary:
	var display = executable_path
	if not arguments.is_empty():
		display += " %s" % " ".join(arguments)
	return {
		"success": true,
		"source": source,
		"executable_path": executable_path,
		"arguments": arguments,
		"display_command": display,
		"message": message
	}


func _build_installed_launch_info() -> Dictionary:
	var install_dir = _get_local_install_dir()
	var installed_exe = "%s/%s" % [install_dir, CENTRAL_SERVER_EXE_NAME]
	if FileAccess.file_exists(installed_exe):
		return _make_launch_info(
			installed_exe,
			_build_attach_only_switches(),
			"local_install",
			"Using local installed central server runtime."
		)

	var dotnet_path = _resolve_dotnet_path()
	if dotnet_path.is_empty():
		return {
			"success": false,
			"message": "dotnet executable was not found for central server launch."
		}

	var installed_dll = "%s/%s" % [install_dir, CENTRAL_SERVER_DLL_NAME]
	if not FileAccess.file_exists(installed_dll):
		return {
			"success": false,
			"message": "Local central server install was not found."
		}

	return _make_launch_info(
		dotnet_path,
		_build_attach_only_args(installed_dll),
		"local_install",
		"Using local installed central server runtime."
	)


func _has_runtime_in_dir(runtime_dir: String) -> bool:
	var normalized_dir = _normalize_path(runtime_dir)
	if normalized_dir.is_empty():
		return false
	return FileAccess.file_exists("%s/%s" % [normalized_dir, CENTRAL_SERVER_EXE_NAME]) \
		or FileAccess.file_exists("%s/%s" % [normalized_dir, CENTRAL_SERVER_DLL_NAME])


func _detect_source_launch_info() -> Dictionary:
	var normalized_project_root = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var publish_dirs = [
		"%s/../godot-dotnet-mcp/central_server/bin/Debug/net8.0/win-x64/publish" % normalized_project_root,
		"%s/../godot-dotnet-mcp/central_server/bin/Release/net8.0/win-x64/publish" % normalized_project_root,
		"%s/addons/godot_dotnet_mcp/central_server" % normalized_project_root
	]
	for runtime_dir in publish_dirs:
		var candidate = "%s/%s" % [runtime_dir, CENTRAL_SERVER_EXE_NAME]
		if FileAccess.file_exists(candidate):
			var launch = _make_launch_info(candidate, _build_attach_only_switches(), "published_exe")
			launch["runtime_dir"] = runtime_dir
			launch["runtime_kind"] = "exe"
			return launch

	var dotnet_path = _resolve_dotnet_path()
	if dotnet_path.is_empty():
		return {
			"success": false,
			"message": "dotnet executable was not found for central server launch."
		}

	var runtime_dirs = [
		"%s/../godot-dotnet-mcp/central_server/bin/Debug/net8.0" % normalized_project_root,
		"%s/../godot-dotnet-mcp/central_server/bin/Release/net8.0" % normalized_project_root,
		"%s/addons/godot_dotnet_mcp/central_server" % normalized_project_root
	]
	for runtime_dir in runtime_dirs:
		var candidate = "%s/%s" % [runtime_dir, CENTRAL_SERVER_DLL_NAME]
		if not FileAccess.file_exists(candidate):
			continue
		var launch = _make_launch_info(dotnet_path, _build_attach_only_args(candidate), "dotnet_dll")
		launch["runtime_dir"] = runtime_dir
		launch["runtime_kind"] = "dll"
		return launch

	return {
		"success": false,
		"message": "No source central server runtime was detected."
	}


func _bootstrap_local_install(source_dir: String) -> Dictionary:
	var normalized_source = _normalize_path(source_dir)
	if normalized_source.is_empty() or not DirAccess.dir_exists_absolute(normalized_source):
		return {
			"success": false,
			"message": "Central server source runtime directory is missing."
		}

	var install_dir = _get_local_install_dir()
	var install_parent = install_dir.get_base_dir()
	var ensure_parent = DirAccess.make_dir_recursive_absolute(install_parent)
	if ensure_parent != OK:
		return {
			"success": false,
			"message": "Failed to prepare local central server install directory."
		}

	if DirAccess.dir_exists_absolute(install_dir):
		var remove_error = _remove_tree(install_dir)
		if remove_error != OK:
			return {
				"success": false,
				"message": "Failed to clear previous local central server install."
			}

	var copy_error = _copy_directory_recursive(normalized_source, install_dir)
	if copy_error != OK:
		return {
			"success": false,
			"message": "Failed to copy central server runtime into the local install directory."
		}

	return {
		"success": true,
		"install_dir": install_dir,
		"message": "Central server local install was bootstrapped."
	}


func _copy_directory_recursive(source_dir: String, target_dir: String) -> int:
	var ensure_dir = DirAccess.make_dir_recursive_absolute(target_dir)
	if ensure_dir != OK:
		return ensure_dir

	var dir = DirAccess.open(source_dir)
	if dir == null:
		return ERR_CANT_OPEN

	dir.list_dir_begin()
	while true:
		var entry = dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue

		var source_path = "%s/%s" % [source_dir, entry]
		var target_path = "%s/%s" % [target_dir, entry]
		if dir.current_is_dir():
			var nested_error = _copy_directory_recursive(source_path, target_path)
			if nested_error != OK:
				dir.list_dir_end()
				return nested_error
			continue

		var copy_error = DirAccess.copy_absolute(source_path, target_path)
		if copy_error != OK:
			dir.list_dir_end()
			return copy_error
	dir.list_dir_end()
	return OK


func _remove_tree(path: String) -> int:
	var normalized_path = _normalize_path(path)
	var dir = DirAccess.open(normalized_path)
	if dir == null:
		return OK

	dir.list_dir_begin()
	while true:
		var entry = dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue

		var child_path = "%s/%s" % [normalized_path, entry]
		if dir.current_is_dir():
			var nested_error = _remove_tree(child_path)
			if nested_error != OK:
				dir.list_dir_end()
				return nested_error
			continue

		var remove_file_error = DirAccess.remove_absolute(child_path)
		if remove_file_error != OK:
			dir.list_dir_end()
			return remove_file_error
	dir.list_dir_end()
	return DirAccess.remove_absolute(normalized_path)


func _build_attach_only_args(dll_path: String) -> PackedStringArray:
	var arguments := PackedStringArray([dll_path])
	arguments.append_array(_build_attach_only_switches())
	return arguments


func _build_attach_only_switches() -> PackedStringArray:
	var attach_host = str(_settings.get("central_server_host", "127.0.0.1")).strip_edges()
	var attach_port = int(_settings.get("central_server_port", 3020))
	return PackedStringArray(["--attach-only", "--attach-host", attach_host, "--attach-port", str(attach_port)])


func _get_local_install_dir() -> String:
	var base_dir = OS.get_environment("LOCALAPPDATA").strip_edges()
	if base_dir.is_empty():
		base_dir = ProjectSettings.globalize_path("user://godot_dotnet_mcp/central_server")
	return _normalize_path("%s/%s" % [base_dir.replace("\\", "/").trim_suffix("/"), LOCAL_INSTALL_RELATIVE_DIR])


func _normalize_path(path_value: String) -> String:
	return path_value.strip_edges().replace("\\", "/").trim_suffix("/")
