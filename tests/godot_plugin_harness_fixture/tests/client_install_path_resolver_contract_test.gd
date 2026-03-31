extends RefCounted

const ClientInstallPathResolver = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_path_resolver.gd")


class FakeResolver extends ClientInstallPathResolver:
	var existing_files: Dictionary = {}
	var where_results: Dictionary = {}

	func _file_exists(path: String) -> bool:
		return existing_files.has(normalize_path(path))

	func _collect_where_paths(command_name: String) -> Array[String]:
		var results: Array[String] = []
		for value in where_results.get(command_name, []):
			results.append(normalize_path(str(value)))
		return results


func run_case(_tree: SceneTree) -> Dictionary:
	var resolver = FakeResolver.new()
	var first_changed = resolver.configure({
		"client_manual_paths": {
			"codex": " C:\\Tools\\Codex.exe "
		}
	})
	var second_changed = resolver.configure({
		"client_manual_paths": {
			"codex": "C:/Tools/Codex.exe"
		}
	})
	if not first_changed or second_changed:
		return _failure("Client install path resolver should normalize manual paths and only report changes when settings actually change.")

	resolver.existing_files["C:/Tools/Codex.exe"] = true
	var manual_result = resolver.resolve_executable_path("codex", [], ["codex"])
	if str(manual_result.get("path", "")) != "C:/Tools/Codex.exe" or not bool(manual_result.get("using_manual_path", false)):
		return _failure("Client install path resolver should prefer a valid manual path over automatic discovery.")

	var fallback_resolver = FakeResolver.new()
	fallback_resolver.configure({
		"client_manual_paths": {
			"cursor": "C:/Missing/Cursor.exe"
		}
	})
	fallback_resolver.existing_files["C:/Programs/Cursor/Cursor.exe"] = true
	var common_path_result = fallback_resolver.resolve_executable_path(
		"cursor",
		["C:/Programs/Cursor/Cursor.exe"],
		["cursor"]
	)
	if str(common_path_result.get("detected_via", "")) != "common_path":
		return _failure("Client install path resolver should fall back to common path candidates when the manual path is invalid.")
	if not bool(common_path_result.get("manual_path_invalid", false)):
		return _failure("Client install path resolver should preserve invalid manual-path state when automatic discovery takes over.")

	var where_resolver = FakeResolver.new()
	where_resolver.where_results["claude"] = ["C:/Shim/claude.exe"]
	var where_result = where_resolver.resolve_executable_path("claude_code", [], ["claude"])
	if str(where_result.get("path", "")) != "C:/Shim/claude.exe" or str(where_result.get("detected_via", "")) != "where":
		return _failure("Client install path resolver should fall back to where.exe aliases when direct candidates are unavailable.")

	return {
		"name": "client_install_path_resolver_contracts",
		"success": true,
		"error": "",
		"details": {
			"manual_path": str(manual_result.get("path", "")),
			"common_path": str(common_path_result.get("path", "")),
			"where_path": str(where_result.get("path", "")),
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_install_path_resolver_contracts",
		"success": false,
		"error": message,
	}
