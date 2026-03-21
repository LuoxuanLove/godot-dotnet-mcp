@tool
extends RefCounted
class_name CentralServerProcessService

const CENTRAL_SERVER_DLL_NAME := "GodotDotnetMcp.CentralServer.dll"
const CENTRAL_SERVER_EXE_NAME := "GodotDotnetMcp.CentralServer.exe"
const DEFAULT_DOTNET_PATH := "C:/Program Files/dotnet/dotnet.exe"
const PROBE_INTERVAL_MS := 3000
const AUTO_START_RETRY_INTERVAL_MS := 15000
const LOCAL_INSTALL_RELATIVE_DIR := "GodotDotnetMcp/CentralServer/runtime"
const DOWNLOAD_CACHE_RELATIVE_DIR := "GodotDotnetMcp/CentralServer/downloads"
const LOG_RELATIVE_DIR := "GodotDotnetMcp/CentralServer/logs"
const INSTALL_METADATA_NAME := "central_server_install.json"
const SERVER_SHUTDOWN_PATH := "/api/server/shutdown"
const RELEASE_MANIFEST_PATH := "res://addons/godot_dotnet_mcp/central_server_release_manifest.json"
const BUNDLED_PACKAGE_DIR_PATH := "res://addons/godot_dotnet_mcp/central_server_packages"
const HTTP_REDIRECT_LIMIT := 5
const INSTALL_CLEAR_RETRY_COUNT := 60
const INSTALL_CLEAR_RETRY_DELAY_MS := 100

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
var _source_runtime_info: Dictionary = {}


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
	_source_runtime_info = _detect_install_source_info()
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

	var stop_result = _stop_owned_process()
	if not bool(stop_result.get("success", false)):
		return get_status()
	return get_status()


func get_status() -> Dictionary:
	if _launch_info.is_empty():
		refresh_detection()

	var install_dir = _get_local_install_dir()
	var install_manifest = _load_install_manifest(install_dir)
	var local_install_ready = _has_runtime_in_dir(install_dir)
	var source_launch = _source_runtime_info
	if source_launch.is_empty():
		source_launch = _detect_install_source_info()
		_source_runtime_info = source_launch
	var source_runtime_available = bool(source_launch.get("success", false))
	var launch_available = bool(_launch_info.get("success", false))
	var launch_source = str(_launch_info.get("source", ""))
	var client_launch = _build_client_stdio_launch_info()
	var detected_command = str(_launch_info.get("display_command", ""))
	var install_version = str(install_manifest.get("version", ""))
	var install_source_dir = str(install_manifest.get("source_runtime_dir", ""))
	var install_runtime_kind = str(install_manifest.get("runtime_kind", ""))
	var install_updated_at = int(install_manifest.get("installed_at_unix", 0))
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
		"launch_executable_path": str(_launch_info.get("executable_path", "")),
		"launch_arguments": Array(_launch_info.get("arguments", PackedStringArray())),
		"client_launch_available": bool(client_launch.get("success", false)),
		"client_executable_path": str(client_launch.get("executable_path", "")),
		"client_arguments": Array(client_launch.get("arguments", PackedStringArray())),
		"client_command": str(client_launch.get("display_command", "")),
		"log_dir": _get_log_dir(),
		"log_file_path": _get_log_file_path(),
		"endpoint_reachable": _endpoint_reachable,
		"auto_launch_enabled": _is_auto_launch_enabled(),
		"local_endpoint": _build_endpoint(),
		"local_install_dir": install_dir,
		"local_install_ready": local_install_ready,
		"install_version": install_version,
		"install_source_dir": install_source_dir,
		"install_runtime_kind": install_runtime_kind,
		"install_updated_at_unix": install_updated_at,
		"source_runtime_available": source_runtime_available,
		"install_available": source_runtime_available,
		"install_action": "upgrade" if local_install_ready else "install",
		"source_runtime_dir": str(source_launch.get("runtime_dir", "")),
		"source_runtime_version": str(source_launch.get("version", "")),
		"source_runtime_kind": str(source_launch.get("runtime_kind", "")),
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


func validate_client_transport(http_host: String = "127.0.0.1", http_port: int = 3000) -> Dictionary:
	var client_launch = _build_client_stdio_launch_info()
	if bool(client_launch.get("success", false)):
		return _validate_client_stdio_launch(client_launch)
	return _validate_http_transport(http_host, http_port)


func open_install_directory() -> Dictionary:
	var install_dir = _get_local_install_dir()
	if not DirAccess.dir_exists_absolute(install_dir):
		return {
			"success": false,
			"message": "The local central server install directory does not exist yet."
		}
	return _shell_open_target(install_dir, "Opened the local central server install directory.")


func open_log_location() -> Dictionary:
	var log_file_path = _get_log_file_path()
	if FileAccess.file_exists(log_file_path):
		return _shell_open_target(log_file_path, "Opened the local central server log file.")

	var log_dir = _get_log_dir()
	var ensure_dir = DirAccess.make_dir_recursive_absolute(log_dir)
	if ensure_dir != OK:
		return {
			"success": false,
			"message": "Failed to prepare the local central server log directory."
		}
	return _shell_open_target(log_dir, "Opened the local central server log directory.")


func install_or_update_service() -> Dictionary:
	var source_launch = _source_runtime_info
	if source_launch.is_empty():
		source_launch = _detect_install_source_info()
		_source_runtime_info = source_launch
	if not bool(source_launch.get("success", false)):
		return {
			"success": false,
			"status": "install_error",
			"message": str(source_launch.get("message", "No central server runtime is available for installation."))
		}

	var restart_after_install := false
	if _endpoint_reachable and _pid <= 0 and str(_launch_info.get("source", "")) == "local_install":
		var remote_shutdown_result = _request_endpoint_shutdown()
		if not bool(remote_shutdown_result.get("success", false)):
			return {
				"success": false,
				"status": "install_error",
				"message": str(remote_shutdown_result.get("message", "Failed to stop the running local central server before upgrade."))
			}
		restart_after_install = true

	if _pid > 0 and OS.is_process_running(_pid):
		if str(_launch_info.get("source", "")) != "local_install":
			return {
				"success": false,
				"status": "install_error",
				"message": "Stop the running local central server before upgrading it."
			}
		var stop_result = _stop_owned_process()
		if not bool(stop_result.get("success", false)):
			return {
				"success": false,
				"status": "install_error",
				"message": str(stop_result.get("message", "Failed to stop the running local central server before upgrade."))
			}
		restart_after_install = true

	var bootstrap: Dictionary
	match str(source_launch.get("source", "")):
		"bundled_release":
			bootstrap = _install_bundled_release_package(source_launch)
		"remote_release":
			bootstrap = _install_remote_release_package(source_launch)
		_:
			bootstrap = _bootstrap_local_install(str(source_launch.get("runtime_dir", "")), source_launch)
	_source_runtime_info = _detect_install_source_info()
	_launch_info = _detect_launch_command()
	_probe_endpoint()

	var status = get_status()
	status["success"] = bool(bootstrap.get("success", false))
	status["status"] = "installed" if bool(bootstrap.get("success", false)) else "install_error"
	status["message"] = str(bootstrap.get("message", status.get("message", "")))
	status["restart_after_install"] = restart_after_install
	if restart_after_install and bool(bootstrap.get("success", false)):
		var restart_status = start_service()
		status["restart_status"] = restart_status
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

	var source_launch = _source_runtime_info
	if source_launch.is_empty():
		source_launch = _detect_install_source_info()
		_source_runtime_info = source_launch

	var dev_launch = _detect_dev_runtime_source_info()
	if bool(dev_launch.get("success", false)):
		dev_launch["message"] = "Using detected source central server runtime."
		return dev_launch

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


func _build_client_stdio_launch_info() -> Dictionary:
	var executable_path = str(_launch_info.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		return {
			"success": false,
			"message": "No client stdio command is available."
		}

	var source = str(_launch_info.get("source", "")).strip_edges()
	var raw_arguments = _launch_info.get("arguments", PackedStringArray())
	var arguments := PackedStringArray()
	if raw_arguments is PackedStringArray:
		arguments = raw_arguments
	elif raw_arguments is Array:
		arguments.append_array(raw_arguments)

	var client_arguments := _build_client_stdio_args(arguments)
	if source == "settings":
		return _make_launch_info(executable_path, client_arguments, source, "Using configured central server stdio command.")

	return _make_launch_info(executable_path, client_arguments, source, "Using local central server stdio command.")


func _build_client_stdio_args(arguments: PackedStringArray) -> PackedStringArray:
	var client_arguments := PackedStringArray()
	var skip_next := false
	for index in range(arguments.size()):
		if skip_next:
			skip_next = false
			continue
		var argument = str(arguments[index])
		if argument == "--attach-only":
			continue
		if argument == "--attach-host" or argument == "--attach-port" or argument == "--log-file":
			skip_next = true
			continue
		client_arguments.append(argument)

	if not client_arguments.has("--stdio"):
		client_arguments.append("--stdio")
	return client_arguments


func _build_installed_launch_info() -> Dictionary:
	var install_dir = _get_local_install_dir()
	var installed_exe = "%s/%s" % [install_dir, CENTRAL_SERVER_EXE_NAME]
	if FileAccess.file_exists(installed_exe):
		var installed_exe_launch = _make_launch_info(
			installed_exe,
			_build_attach_only_switches(),
			"local_install",
			"Using local installed central server runtime."
		)
		installed_exe_launch["version"] = _probe_runtime_version(installed_exe, "exe")
		return installed_exe_launch

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

	var installed_dll_launch = _make_launch_info(
		dotnet_path,
		_build_attach_only_args(installed_dll),
		"local_install",
		"Using local installed central server runtime."
	)
	installed_dll_launch["version"] = str(_load_install_manifest(install_dir).get("version", ""))
	return installed_dll_launch


func _has_runtime_in_dir(runtime_dir: String) -> bool:
	var normalized_dir = _normalize_path(runtime_dir)
	if normalized_dir.is_empty():
		return false
	return FileAccess.file_exists("%s/%s" % [normalized_dir, CENTRAL_SERVER_EXE_NAME]) \
		or FileAccess.file_exists("%s/%s" % [normalized_dir, CENTRAL_SERVER_DLL_NAME])


func _detect_install_source_info() -> Dictionary:
	var bundled_release = _detect_bundled_release_info()
	if bool(bundled_release.get("success", false)):
		return bundled_release

	var remote_release = _detect_remote_release_info()
	if bool(remote_release.get("success", false)):
		return remote_release

	return _detect_dev_runtime_source_info()


func _detect_dev_runtime_source_info() -> Dictionary:
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
			launch["version"] = _probe_runtime_version(candidate, "exe")
			return launch

	var dotnet_path = _resolve_dotnet_path()
	if not dotnet_path.is_empty():
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
			launch["version"] = _probe_runtime_version(candidate, "dll", dotnet_path)
			return launch

	return {
		"success": false,
		"message": "No development central server runtime was detected."
	}


func _bootstrap_local_install(source_dir: String, source_launch: Dictionary = {}) -> Dictionary:
	var normalized_source = _normalize_path(source_dir)
	if normalized_source.is_empty() or not DirAccess.dir_exists_absolute(normalized_source):
		return {
			"success": false,
			"message": "Central server source runtime directory is missing."
		}

	var install_dir = _get_local_install_dir()
	var prepare_result = _prepare_install_directory(install_dir)
	if not bool(prepare_result.get("success", false)):
		return prepare_result

	var copy_error = _copy_directory_recursive(normalized_source, install_dir)
	if copy_error != OK:
		return {
			"success": false,
			"message": "Failed to copy central server runtime into the local install directory."
		}

	var manifest = {
		"version": str(source_launch.get("version", "")),
		"source_runtime_dir": normalized_source,
		"source_kind": str(source_launch.get("source", "")),
		"runtime_kind": str(source_launch.get("runtime_kind", "")),
		"install_dir": install_dir,
		"installed_at_unix": Time.get_unix_time_from_system()
	}
	var manifest_error = _write_install_manifest(install_dir, manifest)
	if manifest_error != OK:
		return {
			"success": false,
			"message": "Failed to write local central server install metadata."
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
	var arguments := PackedStringArray(["--attach-only", "--attach-host", attach_host, "--attach-port", str(attach_port)])
	var log_file_path = _get_log_file_path()
	if not log_file_path.is_empty():
		arguments.append_array(PackedStringArray(["--log-file", log_file_path]))
	return arguments


func _get_local_install_dir() -> String:
	var base_dir = OS.get_environment("LOCALAPPDATA").strip_edges()
	if base_dir.is_empty():
		base_dir = ProjectSettings.globalize_path("user://godot_dotnet_mcp/central_server")
	return _normalize_path("%s/%s" % [base_dir.replace("\\", "/").trim_suffix("/"), LOCAL_INSTALL_RELATIVE_DIR])


func _normalize_path(path_value: String) -> String:
	return path_value.strip_edges().replace("\\", "/").trim_suffix("/")


func _detect_remote_release_info() -> Dictionary:
	if not bool(_settings.get("central_server_release_enabled", true)):
		return {
			"success": false,
			"message": "Remote central server release downloads are disabled."
		}

	var manifest = _load_release_manifest()
	if manifest.is_empty():
		return {
			"success": false,
			"message": "Remote central server release manifest was not found."
		}

	var package_url = _build_remote_release_url(manifest)
	if package_url.is_empty():
		return {
			"success": false,
			"message": "Remote central server release URL is not configured."
		}

	return {
		"success": true,
		"source": "remote_release",
		"runtime_dir": package_url,
		"runtime_kind": "zip",
		"version": str(manifest.get("version", "")).strip_edges(),
		"package_url": package_url,
		"message": "Using remote central server release package."
	}


func _detect_bundled_release_info() -> Dictionary:
	var manifest = _load_release_manifest()
	if manifest.is_empty():
		return {
			"success": false,
			"message": "Bundled central server release manifest was not found."
		}

	var asset_name = _build_release_asset_name(manifest)
	if asset_name.is_empty():
		return {
			"success": false,
			"message": "Bundled central server release asset name is not configured."
		}

	var package_path = ProjectSettings.globalize_path("%s/%s" % [BUNDLED_PACKAGE_DIR_PATH, asset_name]).replace("\\", "/")
	if not FileAccess.file_exists(package_path):
		return {
			"success": false,
			"message": "Bundled central server release package was not found."
		}

	return {
		"success": true,
		"source": "bundled_release",
		"runtime_dir": package_path,
		"runtime_kind": "zip",
		"version": str(manifest.get("version", "")).strip_edges(),
		"package_path": package_path,
		"message": "Using bundled central server release package."
	}


func _load_release_manifest() -> Dictionary:
	if not ResourceLoader.exists(RELEASE_MANIFEST_PATH):
		return {}
	var file = FileAccess.open(RELEASE_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _build_remote_release_url(manifest: Dictionary) -> String:
	var explicit_url = str(_settings.get("central_server_release_url", "")).strip_edges()
	if not explicit_url.is_empty():
		return explicit_url

	var asset_name = _build_release_asset_name(manifest)
	if asset_name.is_empty():
		return ""

	var version = str(manifest.get("version", "")).strip_edges()
	var owner = str(manifest.get("repo_owner", "")).strip_edges()
	var repo = str(manifest.get("repo_name", "")).strip_edges()
	var tag_template = str(manifest.get("tag_template", "")).strip_edges()
	if version.is_empty() or owner.is_empty() or repo.is_empty() or tag_template.is_empty():
		return ""

	var tag = tag_template.replace("{version}", version)
	return "https://github.com/%s/%s/releases/download/%s/%s" % [owner, repo, tag, asset_name]


func _build_release_asset_name(manifest: Dictionary) -> String:
	var version = str(manifest.get("version", "")).strip_edges()
	var asset_template = str(manifest.get("asset_name_template", "")).strip_edges()
	if version.is_empty() or asset_template.is_empty():
		return ""
	return asset_template.replace("{version}", version)


func _get_download_cache_dir() -> String:
	var base_dir = OS.get_environment("LOCALAPPDATA").strip_edges()
	if base_dir.is_empty():
		base_dir = ProjectSettings.globalize_path("user://godot_dotnet_mcp/central_server")
	return _normalize_path("%s/%s" % [base_dir.replace("\\", "/").trim_suffix("/"), DOWNLOAD_CACHE_RELATIVE_DIR])


func _get_log_dir() -> String:
	var base_dir = OS.get_environment("LOCALAPPDATA").strip_edges()
	if base_dir.is_empty():
		base_dir = ProjectSettings.globalize_path("user://godot_dotnet_mcp/central_server")
	return _normalize_path("%s/%s" % [base_dir.replace("\\", "/").trim_suffix("/"), LOG_RELATIVE_DIR])


func _get_log_file_path() -> String:
	return "%s/central_server.log" % _get_log_dir()


func _install_remote_release_package(source_launch: Dictionary) -> Dictionary:
	var package_url = str(source_launch.get("package_url", source_launch.get("runtime_dir", ""))).strip_edges()
	if package_url.is_empty():
		return {
			"success": false,
			"message": "Remote central server release URL is empty."
		}

	var download_dir = _get_download_cache_dir()
	var ensure_download_dir = DirAccess.make_dir_recursive_absolute(download_dir)
	if ensure_download_dir != OK:
		return {
			"success": false,
			"message": "Failed to prepare the central server download cache directory."
		}

	var zip_path = "%s/central_server_release.zip" % download_dir
	if FileAccess.file_exists(zip_path):
		DirAccess.remove_absolute(zip_path)

	var download_result = _download_remote_package(package_url, zip_path)
	if not bool(download_result.get("success", false)):
		return download_result

	return _install_zip_package(zip_path, source_launch, package_url, "Central server local install was downloaded and installed from the remote release package.")


func _install_bundled_release_package(source_launch: Dictionary) -> Dictionary:
	var package_path = str(source_launch.get("package_path", source_launch.get("runtime_dir", ""))).strip_edges()
	if package_path.is_empty() or not FileAccess.file_exists(package_path):
		return {
			"success": false,
			"message": "Bundled central server release package was not found."
		}

	return _install_zip_package(package_path, source_launch, package_path, "Central server local install was installed from the bundled release package.")


func _install_zip_package(zip_path: String, source_launch: Dictionary, source_reference: String, success_message: String) -> Dictionary:
	if zip_path.is_empty() or not FileAccess.file_exists(zip_path):
		return {
			"success": false,
			"message": "Central server release package was not found."
		}

	var install_dir = _get_local_install_dir()
	var prepare_result = _prepare_install_directory(install_dir)
	if not bool(prepare_result.get("success", false)):
		return prepare_result

	var extract_result = _extract_zip_to_directory(zip_path, install_dir)
	if not bool(extract_result.get("success", false)):
		return extract_result

	var manifest = {
		"version": str(source_launch.get("version", "")),
		"source_runtime_dir": source_reference,
		"source_kind": str(source_launch.get("source", "")),
		"runtime_kind": "zip",
		"install_dir": install_dir,
		"installed_at_unix": Time.get_unix_time_from_system()
	}
	var manifest_error = _write_install_manifest(install_dir, manifest)
	if manifest_error != OK:
		return {
			"success": false,
			"message": "Failed to write local central server install metadata."
		}

	return {
		"success": true,
		"install_dir": install_dir,
		"message": success_message
	}


func _prepare_install_directory(install_dir: String) -> Dictionary:
	var install_parent = install_dir.get_base_dir()
	var ensure_parent = DirAccess.make_dir_recursive_absolute(install_parent)
	if ensure_parent != OK:
		return {
			"success": false,
			"message": "Failed to prepare the local central server install directory."
		}

	if not DirAccess.dir_exists_absolute(install_dir):
		return {
			"success": true
		}

	for _attempt in range(INSTALL_CLEAR_RETRY_COUNT):
		var remove_error = _remove_tree(install_dir)
		if remove_error == OK or not DirAccess.dir_exists_absolute(install_dir):
			return {
				"success": true
			}
		OS.delay_msec(INSTALL_CLEAR_RETRY_DELAY_MS)

	return {
		"success": false,
		"message": "Failed to clear the previous local central server install. The existing service may still be shutting down."
	}


func _parse_http_url(url: String) -> Dictionary:
	var normalized = url.strip_edges()
	var is_https = normalized.begins_with("https://")
	var scheme = "https://" if is_https else "http://"
	if not normalized.begins_with(scheme):
		return {}

	var without_scheme = normalized.trim_prefix(scheme)
	var slash_index = without_scheme.find("/")
	var host_port = without_scheme if slash_index < 0 else without_scheme.substr(0, slash_index)
	var path = "/" if slash_index < 0 else without_scheme.substr(slash_index)
	var host = host_port
	var port = 443 if is_https else 80
	var colon_index = host_port.rfind(":")
	if colon_index > 0 and not host_port.contains("]"):
		host = host_port.substr(0, colon_index)
		port = int(host_port.substr(colon_index + 1))
	return {
		"secure": is_https,
		"host": host,
		"port": port,
		"path": path
	}


func _download_remote_package(url: String, target_path: String) -> Dictionary:
	var current_url = url
	for _redirect_index in range(HTTP_REDIRECT_LIMIT):
		var parsed = _parse_http_url(current_url)
		if parsed.is_empty():
			return {
				"success": false,
				"message": "Remote central server release URL is invalid."
			}

		var client := HTTPClient.new()
		var tls_options = TLSOptions.client() if bool(parsed.get("secure", false)) else null
		var connect_error = client.connect_to_host(str(parsed.get("host", "")), int(parsed.get("port", 0)), tls_options)
		if connect_error != OK:
			return {
				"success": false,
				"message": "Failed to connect to the remote central server release endpoint."
			}

		var connect_deadline := Time.get_ticks_msec() + 5000
		while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
			client.poll()
			if Time.get_ticks_msec() >= connect_deadline:
				return {
					"success": false,
					"message": "Timed out while connecting to the remote central server release endpoint."
				}
			OS.delay_msec(10)

		if client.get_status() != HTTPClient.STATUS_CONNECTED:
			return {
				"success": false,
				"message": "Failed to connect to the remote central server release endpoint."
			}

		var request_error = client.request(
			HTTPClient.METHOD_GET,
			str(parsed.get("path", "/")),
			PackedStringArray(["User-Agent: GodotDotnetMcp", "Accept: application/octet-stream"])
		)
		if request_error != OK:
			return {
				"success": false,
				"message": "Failed to request the remote central server release package."
			}

		var response_deadline := Time.get_ticks_msec() + 10000
		while client.get_status() == HTTPClient.STATUS_REQUESTING:
			client.poll()
			if Time.get_ticks_msec() >= response_deadline:
				return {
					"success": false,
					"message": "Timed out while requesting the remote central server release package."
				}
			OS.delay_msec(10)

		if not client.has_response():
			return {
				"success": false,
				"message": "The remote central server release endpoint did not return a response."
			}

		var response_code = client.get_response_code()
		var response_headers = client.get_response_headers_as_dictionary()
		if response_code in [301, 302, 303, 307, 308]:
			var location = str(response_headers.get("Location", response_headers.get("location", ""))).strip_edges()
			if location.is_empty():
				return {
					"success": false,
					"message": "Remote central server release redirect did not include a Location header."
				}
			current_url = location
			continue

		if response_code < 200 or response_code >= 300:
			return {
				"success": false,
				"message": "Remote central server release download failed with HTTP status %d." % response_code
			}

		var file = FileAccess.open(target_path, FileAccess.WRITE)
		if file == null:
			return {
				"success": false,
				"message": "Failed to open the local download cache for the central server release package."
			}

		while client.get_status() == HTTPClient.STATUS_BODY:
			client.poll()
			var chunk = client.read_response_body_chunk()
			if chunk.is_empty():
				OS.delay_msec(10)
				continue
			file.store_buffer(chunk)
		file.close()
		return {
			"success": true,
			"message": "Remote central server release package downloaded."
		}

	return {
		"success": false,
		"message": "Remote central server release download exceeded the redirect limit."
	}


func _extract_zip_to_directory(zip_path: String, target_dir: String) -> Dictionary:
	var ensure_dir = DirAccess.make_dir_recursive_absolute(target_dir)
	if ensure_dir != OK:
		return {
			"success": false,
			"message": "Failed to prepare the local central server install directory."
		}

	var zip := ZIPReader.new()
	var open_error = zip.open(zip_path)
	if open_error != OK:
		return {
			"success": false,
			"message": "Failed to open the downloaded central server release package."
		}

	for entry in zip.get_files():
		var normalized_entry = str(entry).replace("\\", "/")
		var target_path = "%s/%s" % [target_dir, normalized_entry]
		if normalized_entry.ends_with("/"):
			var dir_error = DirAccess.make_dir_recursive_absolute(target_path.trim_suffix("/"))
			if dir_error != OK:
				zip.close()
				return {
					"success": false,
					"message": "Failed to prepare directories while extracting the central server release package."
				}
			continue

		var target_parent = target_path.get_base_dir()
		var ensure_parent = DirAccess.make_dir_recursive_absolute(target_parent)
		if ensure_parent != OK:
			zip.close()
			return {
				"success": false,
				"message": "Failed to prepare directories while extracting the central server release package."
			}

		var data = zip.read_file(normalized_entry)
		var file = FileAccess.open(target_path, FileAccess.WRITE)
		if file == null:
			zip.close()
			return {
				"success": false,
				"message": "Failed to extract files from the central server release package."
			}
		file.store_buffer(data)
		file.close()

	zip.close()
	return {
		"success": true,
		"message": "Central server release package extracted successfully."
	}


func _request_endpoint_shutdown(wait_timeout_msec: int = 3000) -> Dictionary:
	var host := str(_settings.get("central_server_host", "127.0.0.1")).strip_edges()
	var port := int(_settings.get("central_server_port", 3020))
	var peer := StreamPeerTCP.new()
	var connect_error := peer.connect_to_host(host, port)
	if connect_error != OK:
		return {
			"success": false,
			"message": "Failed to connect to the local central server control endpoint."
		}

	var connect_deadline := Time.get_ticks_msec() + 500
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() < connect_deadline:
		OS.delay_msec(10)
		_poll_peer(peer)

	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		if peer.get_status() != StreamPeerTCP.STATUS_NONE:
			peer.disconnect_from_host()
		return {
			"success": false,
			"message": "Failed to connect to the local central server control endpoint."
		}

	var request = "POST %s HTTP/1.1\r\nHost: %s:%d\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}" % [SERVER_SHUTDOWN_PATH, host, port]
	var request_bytes = request.to_utf8_buffer()
	var write_error := peer.put_data(request_bytes)
	if write_error != OK:
		peer.disconnect_from_host()
		return {
			"success": false,
			"message": "Failed to send shutdown request to the local central server."
		}

	var response_deadline := Time.get_ticks_msec() + 1000
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and Time.get_ticks_msec() < response_deadline:
		_poll_peer(peer)
		var available = peer.get_available_bytes()
		if available > 0:
			peer.get_data(available)
			break
		OS.delay_msec(10)

	if peer.get_status() != StreamPeerTCP.STATUS_NONE:
		peer.disconnect_from_host()

	var shutdown_deadline := Time.get_ticks_msec() + wait_timeout_msec
	while Time.get_ticks_msec() < shutdown_deadline:
		if not _probe_endpoint():
			_status = "stopped"
			_last_error = ""
			return {
				"success": true,
				"message": "Local central server stopped through the control endpoint."
			}
		OS.delay_msec(25)

	_last_error = "Timed out while waiting for the local central server to stop."
	return {
		"success": false,
		"message": _last_error
	}


func _validate_client_stdio_launch(client_launch: Dictionary) -> Dictionary:
	var executable_path = str(client_launch.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		return {
			"success": false,
			"message": "No local central server stdio command is available for validation."
		}

	var validation_arguments := PackedStringArray()
	var raw_arguments = client_launch.get("arguments", PackedStringArray())
	if raw_arguments is PackedStringArray:
		validation_arguments = raw_arguments
	elif raw_arguments is Array:
		validation_arguments.append_array(raw_arguments)

	var filtered_arguments := PackedStringArray()
	for argument in validation_arguments:
		if str(argument) == "--stdio":
			continue
		filtered_arguments.append(str(argument))
	filtered_arguments.append("--health")

	var output: Array = []
	var exit_code := OS.execute(executable_path, filtered_arguments, output, true, false)
	if exit_code != 0:
		return {
			"success": false,
			"message": "Local central server health validation failed."
		}

	var payload_text = str(output[0]).strip_edges() if not output.is_empty() else ""
	var parsed = JSON.parse_string(payload_text)
	if parsed is Dictionary and str((parsed as Dictionary).get("status", "")).strip_edges() == "ok":
		return {
			"success": true,
			"mode": "stdio",
			"message": "Local central server stdio command validated successfully.",
			"payload": parsed,
			"command": str(client_launch.get("display_command", ""))
		}

	return {
		"success": false,
		"message": "Local central server health validation returned an unexpected response.",
		"payload_text": payload_text
	}


func _validate_http_transport(http_host: String, http_port: int) -> Dictionary:
	var peer := StreamPeerTCP.new()
	var connect_error := peer.connect_to_host(http_host, http_port)
	if connect_error != OK:
		return {
			"success": false,
			"message": "Failed to connect to the embedded HTTP MCP endpoint."
		}

	var connect_deadline := Time.get_ticks_msec() + 500
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() < connect_deadline:
		OS.delay_msec(10)
		_poll_peer(peer)

	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		if peer.get_status() != StreamPeerTCP.STATUS_NONE:
			peer.disconnect_from_host()
		return {
			"success": false,
			"message": "Failed to connect to the embedded HTTP MCP endpoint."
		}

	var request = "GET /health HTTP/1.1\r\nHost: %s:%d\r\nConnection: close\r\n\r\n" % [http_host, http_port]
	var write_error := peer.put_data(request.to_utf8_buffer())
	if write_error != OK:
		peer.disconnect_from_host()
		return {
			"success": false,
			"message": "Failed to query the embedded HTTP MCP endpoint."
		}

	var response_buffer := PackedByteArray()
	var response_deadline := Time.get_ticks_msec() + 1500
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and Time.get_ticks_msec() < response_deadline:
		_poll_peer(peer)
		var available = peer.get_available_bytes()
		if available > 0:
			var chunk = peer.get_data(available)
			if int(chunk[0]) == OK:
				response_buffer.append_array(chunk[1])
		else:
			OS.delay_msec(10)
	if peer.get_status() != StreamPeerTCP.STATUS_NONE:
		peer.disconnect_from_host()

	var response_text = response_buffer.get_string_from_utf8()
	if response_text.contains("200 OK"):
		return {
			"success": true,
			"mode": "http",
			"message": "Embedded HTTP MCP endpoint validated successfully.",
			"endpoint": "http://%s:%d/mcp" % [http_host, http_port]
		}

	return {
		"success": false,
		"message": "Embedded HTTP MCP endpoint validation returned an unexpected response.",
		"response": response_text
	}


func _stop_owned_process(wait_timeout_msec: int = 3000) -> Dictionary:
	if _pid <= 0:
		_status = "stopped"
		_last_error = ""
		_endpoint_reachable = false
		return {
			"success": true,
			"message": "Local central server is already stopped."
		}

	var stopping_pid := _pid
	var error := OS.kill(stopping_pid)
	if error != OK:
		_status = "launch_error"
		_last_error = "Failed to stop central server process: %s" % error
		return {
			"success": false,
			"message": _last_error
		}

	var deadline := Time.get_ticks_msec() + wait_timeout_msec
	while OS.is_process_running(stopping_pid) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(25)

	if OS.is_process_running(stopping_pid):
		_status = "launch_error"
		_last_error = "Timed out while stopping the local central server process."
		return {
			"success": false,
			"message": _last_error
		}

	_pid = 0
	_status = "stopped"
	_last_error = ""
	_endpoint_reachable = false
	_last_probe_msec = 0
	return {
		"success": true,
		"message": "Local central server stopped."
	}


func _shell_open_target(target_path: String, success_message: String) -> Dictionary:
	var normalized_path = str(target_path).strip_edges()
	if normalized_path.is_empty():
		return {
			"success": false,
			"message": "Failed to open the requested local central server path."
		}

	if OS.get_name() == "Windows":
		var absolute_path = ProjectSettings.globalize_path(normalized_path)
		var pid := 0
		if FileAccess.file_exists(absolute_path):
			pid = OS.create_process("explorer.exe", PackedStringArray(["/select,%s" % absolute_path]), false)
		elif DirAccess.dir_exists_absolute(absolute_path):
			pid = OS.create_process("explorer.exe", PackedStringArray([absolute_path]), false)
		if pid > 0:
			return {
				"success": true,
				"message": success_message,
				"path": absolute_path
			}
		if not absolute_path.is_empty():
			return {
				"success": false,
				"message": "Failed to open the requested local central server path."
			}

	var open_error = OS.shell_open(normalized_path)
	if open_error != OK:
		return {
			"success": false,
			"message": "Failed to open the requested local central server path."
		}
	return {
		"success": true,
		"message": success_message,
		"path": normalized_path
	}


func _probe_runtime_version(runtime_path: String, runtime_kind: String, dotnet_path: String = "") -> String:
	var output: Array = []
	var exit_code := ERR_UNAVAILABLE
	match runtime_kind:
		"exe":
			exit_code = OS.execute(runtime_path, PackedStringArray(["--version"]), output, true, false)
		"dll":
			if dotnet_path.is_empty():
				return ""
			exit_code = OS.execute(dotnet_path, PackedStringArray([runtime_path, "--version"]), output, true, false)
		_:
			return ""

	if exit_code != 0 or output.is_empty():
		return ""
	return str(output[0]).strip_edges()


func _get_install_metadata_path(install_dir: String) -> String:
	return "%s/%s" % [_normalize_path(install_dir), INSTALL_METADATA_NAME]


func _write_install_manifest(install_dir: String, manifest: Dictionary) -> int:
	var metadata_path = _get_install_metadata_path(install_dir)
	var file = FileAccess.open(metadata_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(manifest, "\t"))
	return OK


func _load_install_manifest(install_dir: String) -> Dictionary:
	var metadata_path = _get_install_metadata_path(install_dir)
	if not FileAccess.file_exists(metadata_path):
		return {}
	var file = FileAccess.open(metadata_path, FileAccess.READ)
	if file == null:
		return {}
	var raw = file.get_as_text()
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed
	return {}
