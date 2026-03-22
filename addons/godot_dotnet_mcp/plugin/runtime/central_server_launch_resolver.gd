@tool
extends RefCounted
class_name CentralServerLaunchResolver

var _settings: Dictionary = {}
var _runtime_files_service
var _central_server_dll_name := "GodotDotnetMcp.CentralServer.dll"
var _central_server_exe_name := "GodotDotnetMcp.CentralServer.exe"
var _default_dotnet_path := "C:/Program Files/dotnet/dotnet.exe"
var _release_manifest_path := "res://addons/godot_dotnet_mcp/central_server_release_manifest.json"
var _bundled_package_dir_path := "res://addons/godot_dotnet_mcp/central_server_packages"


func configure(settings: Dictionary, runtime_files_service, options: Dictionary = {}) -> void:
	_settings = settings
	_runtime_files_service = runtime_files_service
	_central_server_dll_name = str(options.get("central_server_dll_name", _central_server_dll_name))
	_central_server_exe_name = str(options.get("central_server_exe_name", _central_server_exe_name))
	_default_dotnet_path = str(options.get("default_dotnet_path", _default_dotnet_path))
	_release_manifest_path = str(options.get("release_manifest_path", _release_manifest_path))
	_bundled_package_dir_path = str(options.get("bundled_package_dir_path", _bundled_package_dir_path))


func detect_launch_command(source_runtime_info: Dictionary = {}) -> Dictionary:
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

	if source_runtime_info.is_empty():
		detect_install_source_info()

	var dev_launch = _detect_dev_runtime_source_info()
	if bool(dev_launch.get("success", false)):
		dev_launch["message"] = "Using detected source central server runtime."
		return dev_launch

	return {
		"success": false,
		"message": "No central server executable or DLL was detected."
	}


func build_client_stdio_launch_info(launch_info: Dictionary) -> Dictionary:
	var executable_path = str(launch_info.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		return {
			"success": false,
			"message": "No client stdio command is available."
		}

	var source = str(launch_info.get("source", "")).strip_edges()
	var raw_arguments = launch_info.get("arguments", PackedStringArray())
	var arguments := PackedStringArray()
	if raw_arguments is PackedStringArray:
		arguments = raw_arguments
	elif raw_arguments is Array:
		arguments.append_array(raw_arguments)

	var client_arguments := _build_client_stdio_args(arguments)
	if source == "settings":
		return _make_launch_info(executable_path, client_arguments, source, "Using configured central server stdio command.")

	return _make_launch_info(executable_path, client_arguments, source, "Using local central server stdio command.")


func has_runtime_in_dir(runtime_dir: String) -> bool:
	var normalized_dir = _normalize_path(runtime_dir)
	if normalized_dir.is_empty():
		return false
	return FileAccess.file_exists("%s/%s" % [normalized_dir, _central_server_exe_name]) \
		or FileAccess.file_exists("%s/%s" % [normalized_dir, _central_server_dll_name])


func detect_install_source_info() -> Dictionary:
	var bundled_release = _detect_bundled_release_info()
	if bool(bundled_release.get("success", false)):
		return bundled_release

	var remote_release = _detect_remote_release_info()
	if bool(remote_release.get("success", false)):
		return remote_release

	return _detect_dev_runtime_source_info()


func _resolve_dotnet_path() -> String:
	var configured = str(_settings.get("central_server_dotnet_path", "")).strip_edges()
	if not configured.is_empty() and FileAccess.file_exists(configured):
		return configured

	var output: Array = []
	var exit_code := OS.execute("dotnet", PackedStringArray(["--version"]), output, true, false)
	if exit_code == 0:
		return "dotnet"

	if FileAccess.file_exists(_default_dotnet_path):
		return _default_dotnet_path

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
	var install_dir = _runtime_files_service.get_local_install_dir()
	var installed_exe = "%s/%s" % [install_dir, _central_server_exe_name]
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

	var installed_dll = "%s/%s" % [install_dir, _central_server_dll_name]
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
	installed_dll_launch["version"] = str(_runtime_files_service.load_install_manifest(install_dir).get("version", ""))
	return installed_dll_launch


func _detect_dev_runtime_source_info() -> Dictionary:
	var normalized_project_root = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var publish_dirs = [
		"%s/../godot-dotnet-mcp/central_server/bin/Debug/net8.0/win-x64/publish" % normalized_project_root,
		"%s/../godot-dotnet-mcp/central_server/bin/Release/net8.0/win-x64/publish" % normalized_project_root,
		"%s/addons/godot_dotnet_mcp/central_server" % normalized_project_root
	]
	for runtime_dir in publish_dirs:
		var candidate = "%s/%s" % [runtime_dir, _central_server_exe_name]
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
			var candidate = "%s/%s" % [runtime_dir, _central_server_dll_name]
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


func _build_attach_only_args(dll_path: String) -> PackedStringArray:
	var arguments := PackedStringArray([dll_path])
	arguments.append_array(_build_attach_only_switches())
	return arguments


func _build_attach_only_switches() -> PackedStringArray:
	var attach_host = str(_settings.get("central_server_host", "127.0.0.1")).strip_edges()
	var attach_port = int(_settings.get("central_server_port", 3020))
	var arguments := PackedStringArray(["--attach-only", "--attach-host", attach_host, "--attach-port", str(attach_port)])
	var log_file_path = _runtime_files_service.get_log_file_path()
	if not log_file_path.is_empty():
		arguments.append_array(PackedStringArray(["--log-file", log_file_path]))
	return arguments


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

	var package_path = ProjectSettings.globalize_path("%s/%s" % [_bundled_package_dir_path, asset_name]).replace("\\", "/")
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
	if not ResourceLoader.exists(_release_manifest_path):
		return {}
	var file = FileAccess.open(_release_manifest_path, FileAccess.READ)
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


func _normalize_path(path_value: String) -> String:
	if _runtime_files_service != null and _runtime_files_service.has_method("normalize_path"):
		return _runtime_files_service.normalize_path(path_value)
	return path_value.strip_edges().replace("\\", "/").trim_suffix("/")
