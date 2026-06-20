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
	return {"name": "plugin_update_sync_mirror_service_contracts", "success": true, "error": ""}


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_update_sync_mirror_service_contracts", "success": false, "error": message, "details": details}
