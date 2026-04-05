extends RefCounted

const PluginServiceBundleFactory = preload("res://addons/godot_dotnet_mcp/plugin/plugin_service_bundle_factory.gd")


class FakePlugin extends RefCounted:
	var _settings_store = null
	var _runtime_state_service = null
	var _tool_bridge_service = null
	var _tool_catalog = null
	var _config_service = null
	var _client_install_detection_service = null
	var _server_feature = null
	var _config_feature = null
	var _user_tool_feature = null
	var _reload_feature = null
	var _tool_profile_feature = null
	var _tool_access_feature = null
	var _self_diagnostic_feature = null
	var _ui_state_feature = null
	var _dock_presenter = null
	var _dock_model_service = null
	var _user_tool_service = null
	var _user_tool_watch_service = null
	var _central_server_attach_service = null
	var _runtime_process_service = null


func run_case(_tree: SceneTree) -> Dictionary:
	var factory = PluginServiceBundleFactory.new()
	var plugin = FakePlugin.new()
	factory.refresh_plugin_service_instances(plugin)
	for key in factory.get_bundle_keys():
		if plugin.get("_%s" % key) == null:
			return _failure("PluginServiceBundleFactory should create non-null service instances.")

	return {
		"name": "plugin_service_bundle_factory_contracts",
		"success": true,
		"error": "",
		"details": {
			"bundle_key_count": factory.get_bundle_keys().size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_service_bundle_factory_contracts",
		"success": false,
		"error": message
	}
