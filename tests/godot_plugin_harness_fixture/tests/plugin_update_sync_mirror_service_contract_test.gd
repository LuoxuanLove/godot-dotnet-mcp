extends RefCounted

# {"name": "plugin_update_sync_mirror_service_contracts"}

const PluginUpdateSyncMirrorServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_sync_mirror_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var service = PluginUpdateSyncMirrorServiceScript.new()
	if service.normalize_relative_path(" tools//node\\executor.gd ") != "tools/node/executor.gd":
		return _failure("PluginUpdateSyncMirrorService should normalize archive-relative paths.")
	for skipped_path in [
		"",
		"/absolute.gd",
		"../escape.gd",
		"tools/../escape.gd",
		"C:/absolute.gd",
		".git/config",
		"custom_tools/user.gd",
		".import/cache",
		"dotnet_bridge/bin/bridge.dll",
		"dotnet_bridge/obj/cache.tmp",
		"ui/generated.png.import"
	]:
		if not service.should_skip_path(str(skipped_path)):
			return _failure("PluginUpdateSyncMirrorService should skip unsafe or preserved path: %s" % str(skipped_path))
	if service.should_skip_path("tools/node/executor.gd"):
		return _failure("PluginUpdateSyncMirrorService should keep safe plugin files.")
	var files := PackedStringArray([
		"godot-dotnet-mcp-ref/README.md",
		"godot-dotnet-mcp-ref/addons/godot_dotnet_mcp/plugin.gd"
	])
	if service.find_archive_addon_prefix(files) != "godot-dotnet-mcp-ref/addons/godot_dotnet_mcp/":
		return _failure("PluginUpdateSyncMirrorService should find addon prefix inside GitHub archives.")
	if not service.validate_archive_files({"plugin.cfg": true, "plugin.gd": true, "ui/mcp_dock.tscn": true}).is_empty():
		return _failure("PluginUpdateSyncMirrorService should accept complete plugin archives.")
	if service.validate_archive_files({"plugin.cfg": true, "plugin.gd": true}).find("ui/mcp_dock.tscn") == -1:
		return _failure("PluginUpdateSyncMirrorService should report missing required archive files.")
	if not service.is_path_inside_root("res://addons/godot_dotnet_mcp", "res://addons/godot_dotnet_mcp/tools/node/executor.gd"):
		return _failure("PluginUpdateSyncMirrorService should allow paths inside the addon root.")
	if service.is_path_inside_root("res://addons/godot_dotnet_mcp", "res://addons/other/plugin.gd"):
		return _failure("PluginUpdateSyncMirrorService should reject paths outside the addon root.")
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_sync_mirror_service.gd")
	for required in [
		"_remember_rollback_state(",
		"_rollback_written_files(",
		"_sync_error_after_rollback(",
		"rollback_error",
		"ROLLBACK_CREATED_DIRS_KEY",
		"_remember_created_directories(",
		"errors.append(",
		"verify_error := FileAccess.get_open_error()",
		"recovered"
	]:
		if source.find(required) == -1:
			return _failure("PluginUpdateSyncMirrorService should expose rollback-backed mirror sync internals: %s" % required)
	var rollback_state := {}
	var target_path := "res://tests_tmp/plugin_update_sync_mirror_service_contract/restore_target.gd"
	var survivor_path := "res://tests_tmp/plugin_update_sync_mirror_service_contract/survivor.gd"
	_remove_tree("res://tests_tmp/plugin_update_sync_mirror_service_contract")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_path.get_base_dir()))
	_write_text(target_path, "old")
	_write_text(survivor_path, "old survivor")
	var remember_result: Dictionary = service._remember_rollback_state(rollback_state, target_path)
	if not bool(remember_result.get("success", false)):
		_remove_tree("res://tests_tmp/plugin_update_sync_mirror_service_contract")
		return _failure("PluginUpdateSyncMirrorService test could not prepare rollback state.", remember_result)
	var survivor_remember_result: Dictionary = service._remember_rollback_state(rollback_state, survivor_path)
	if not bool(survivor_remember_result.get("success", false)):
		_remove_tree("res://tests_tmp/plugin_update_sync_mirror_service_contract")
		return _failure("PluginUpdateSyncMirrorService test could not prepare survivor rollback state.", survivor_remember_result)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_path))
	_write_text(survivor_path, "changed survivor")
	var failure_result: Dictionary = service._sync_error_after_rollback("forced failure", rollback_state)
	if bool(failure_result.get("success", true)) or not bool(failure_result.get("dirty", false)) or bool(failure_result.get("recovered", true)):
		_remove_tree("res://tests_tmp/plugin_update_sync_mirror_service_contract")
		return _failure("PluginUpdateSyncMirrorService should mark failed rollback attempts dirty and unrecovered.", failure_result)
	if str(failure_result.get("rollback_error", "")).is_empty():
		_remove_tree("res://tests_tmp/plugin_update_sync_mirror_service_contract")
		return _failure("PluginUpdateSyncMirrorService should include rollback failure diagnostics.", failure_result)
	if str(FileAccess.get_file_as_string(survivor_path)) != "old survivor":
		_remove_tree("res://tests_tmp/plugin_update_sync_mirror_service_contract")
		return _failure("PluginUpdateSyncMirrorService should continue best-effort rollback after one restore fails.", failure_result)
	var directory_rollback_state := {}
	var created_dir := "res://tests_tmp/plugin_update_sync_mirror_service_contract/new/nested"
	service._remember_created_directories(directory_rollback_state, "res://tests_tmp/plugin_update_sync_mirror_service_contract", created_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(created_dir))
	var directory_result: Dictionary = service._sync_error_after_rollback("forced directory rollback", directory_rollback_state)
	if bool(directory_result.get("dirty", true)) or not bool(directory_result.get("recovered", false)):
		_remove_tree("res://tests_tmp/plugin_update_sync_mirror_service_contract")
		return _failure("PluginUpdateSyncMirrorService should report clean recovery when only created directories are removed.", directory_result)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://tests_tmp/plugin_update_sync_mirror_service_contract/new")):
		_remove_tree("res://tests_tmp/plugin_update_sync_mirror_service_contract")
		return _failure("PluginUpdateSyncMirrorService should remove empty directories created by a failed mirror write.")
	_remove_tree("res://tests_tmp/plugin_update_sync_mirror_service_contract")
	return {"name": "plugin_update_sync_mirror_service_contracts", "success": true, "error": ""}


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			_remove_tree(path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	_remove_tree("res://tests_tmp/plugin_update_sync_mirror_service_contract")
	return {"name": "plugin_update_sync_mirror_service_contracts", "success": false, "error": message, "details": details}
