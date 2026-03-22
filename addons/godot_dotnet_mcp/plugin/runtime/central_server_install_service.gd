@tool
extends RefCounted
class_name CentralServerInstallService

var _runtime_files_service
var _http_redirect_limit := 5
var _install_clear_retry_count := 60
var _install_clear_retry_delay_ms := 100


func configure(runtime_files_service, options: Dictionary = {}) -> void:
	_runtime_files_service = runtime_files_service
	_http_redirect_limit = int(options.get("http_redirect_limit", _http_redirect_limit))
	_install_clear_retry_count = int(options.get("install_clear_retry_count", _install_clear_retry_count))
	_install_clear_retry_delay_ms = int(options.get("install_clear_retry_delay_ms", _install_clear_retry_delay_ms))


func install_from_source_launch(source_launch: Dictionary) -> Dictionary:
	match str(source_launch.get("source", "")):
		"bundled_release":
			return _install_bundled_release_package(source_launch)
		"remote_release":
			return _install_remote_release_package(source_launch)
		_:
			return _bootstrap_local_install(str(source_launch.get("runtime_dir", "")), source_launch)


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

	var manifest_error = _write_install_manifest(
		install_dir,
		_build_install_manifest(
			source_launch,
			normalized_source,
			str(source_launch.get("runtime_kind", "")),
			install_dir
		)
	)
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

	return _install_zip_package(
		zip_path,
		source_launch,
		package_url,
		"Central server local install was downloaded and installed from the remote release package."
	)


func _install_bundled_release_package(source_launch: Dictionary) -> Dictionary:
	var package_path = str(source_launch.get("package_path", source_launch.get("runtime_dir", ""))).strip_edges()
	if package_path.is_empty() or not FileAccess.file_exists(package_path):
		return {
			"success": false,
			"message": "Bundled central server release package was not found."
		}

	return _install_zip_package(
		package_path,
		source_launch,
		package_path,
		"Central server local install was installed from the bundled release package."
	)


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

	var manifest_error = _write_install_manifest(
		install_dir,
		_build_install_manifest(source_launch, source_reference, "zip", install_dir)
	)
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
	var normalized_install_dir = _normalize_path(install_dir)
	var install_parent = normalized_install_dir.get_base_dir()
	var ensure_parent = DirAccess.make_dir_recursive_absolute(install_parent)
	if ensure_parent != OK:
		return {
			"success": false,
			"message": "Failed to prepare the local central server install directory."
		}

	if not DirAccess.dir_exists_absolute(normalized_install_dir):
		return {
			"success": true
		}

	for _attempt in range(_install_clear_retry_count):
		var remove_error = _remove_tree(normalized_install_dir)
		if remove_error == OK or not DirAccess.dir_exists_absolute(normalized_install_dir):
			return {
				"success": true
			}
		OS.delay_msec(_install_clear_retry_delay_ms)

	return {
		"success": false,
		"message": "Failed to clear the previous local central server install. The existing service may still be shutting down."
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
	for _redirect_index in range(_http_redirect_limit):
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
	var normalized_target_dir = _normalize_path(target_dir)
	var ensure_dir = DirAccess.make_dir_recursive_absolute(normalized_target_dir)
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
		var normalized_entry = str(entry).replace("\\", "/").strip_edges()
		if normalized_entry.is_empty():
			continue
		if not _is_safe_zip_entry(normalized_entry):
			zip.close()
			return {
				"success": false,
				"message": "Central server release package contains an unsafe path entry."
			}
		var target_path = _normalize_path("%s/%s" % [normalized_target_dir, normalized_entry])
		if not _is_path_within_directory(normalized_target_dir, target_path):
			zip.close()
			return {
				"success": false,
				"message": "Central server release package contains an unsafe extraction target."
			}

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


func _build_install_manifest(source_launch: Dictionary, source_reference: String, runtime_kind: String, install_dir: String) -> Dictionary:
	return {
		"version": str(source_launch.get("version", "")),
		"source_runtime_dir": source_reference,
		"source_kind": str(source_launch.get("source", "")),
		"runtime_kind": runtime_kind,
		"install_dir": install_dir,
		"installed_at_unix": Time.get_unix_time_from_system()
	}


func _get_local_install_dir() -> String:
	if _runtime_files_service == null:
		return ""
	return _runtime_files_service.get_local_install_dir()


func _get_download_cache_dir() -> String:
	if _runtime_files_service == null:
		return ""
	return _runtime_files_service.get_download_cache_dir()


func _normalize_path(path_value: String) -> String:
	if _runtime_files_service == null:
		return path_value.strip_edges().replace("\\", "/").trim_suffix("/")
	return _runtime_files_service.normalize_path(path_value)


func _write_install_manifest(install_dir: String, manifest: Dictionary) -> int:
	if _runtime_files_service == null:
		return ERR_UNCONFIGURED
	return _runtime_files_service.write_install_manifest(install_dir, manifest)


func _is_safe_zip_entry(entry: String) -> bool:
	var normalized_entry = entry.replace("\\", "/").strip_edges()
	if normalized_entry.begins_with("/"):
		return false
	var trimmed_entry = normalized_entry.trim_suffix("/")
	for segment in trimmed_entry.split("/", false):
		if segment == "..":
			return false
		if segment.contains(":"):
			return false
	return true


func _is_path_within_directory(root_dir: String, candidate_path: String) -> bool:
	var normalized_root = _normalize_path(root_dir).to_lower()
	var normalized_candidate = _normalize_path(candidate_path).to_lower()
	return normalized_candidate == normalized_root or normalized_candidate.begins_with("%s/" % normalized_root)
