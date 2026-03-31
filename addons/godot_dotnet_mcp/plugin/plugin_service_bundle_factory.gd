@tool
extends RefCounted
class_name PluginServiceBundleFactory

const PluginRuntimeStateServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state_service.gd")
const PluginToolBridgeServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_tool_bridge_service.gd")
const SettingsStore = preload("res://addons/godot_dotnet_mcp/plugin/config/settings_store.gd")
const ToolCatalogService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_service.gd")
const CentralServerAttachServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_attach_service.gd")
const CentralServerProcessServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_process_service.gd")
const ClientConfigService = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd")
const ClientInstallDetectionService = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_detection_service.gd")
const ServerFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/server_feature.gd")
const ConfigFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/config_feature.gd")
const UserToolFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/user_tool_feature.gd")
const ReloadFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/reload_feature.gd")
const ToolProfileFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/tool_profile_feature.gd")
const ToolAccessFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/tool_access_feature.gd")
const SelfDiagnosticFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/self_diagnostic_feature.gd")
const UIStateFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/ui_state_feature.gd")
const DockPresenterScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_presenter.gd")
const DockModelServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_model_service.gd")
const UserToolService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_service.gd")
const UserToolWatchService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_watch_service.gd")

const SERVICE_BUNDLE_KEYS := [
	"settings_store",
	"runtime_state_service",
	"tool_bridge_service",
	"tool_catalog",
	"config_service",
	"client_install_detection_service",
	"server_feature",
	"config_feature",
	"user_tool_feature",
	"reload_feature",
	"tool_profile_feature",
	"tool_access_feature",
	"self_diagnostic_feature",
	"ui_state_feature",
	"dock_presenter",
	"dock_model_service",
	"user_tool_service",
	"user_tool_watch_service",
	"central_server_attach_service",
	"central_server_process_service"
]


func get_bundle_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in SERVICE_BUNDLE_KEYS:
		keys.append(str(key))
	return keys


func refresh_plugin_service_instances(plugin) -> void:
	if plugin == null:
		return

	plugin._settings_store = SettingsStore.new()
	plugin._runtime_state_service = PluginRuntimeStateServiceScript.new()
	plugin._runtime_state_service.configure(plugin._settings_store)
	plugin._tool_bridge_service = PluginToolBridgeServiceScript.new()
	plugin._tool_catalog = ToolCatalogService.new()
	plugin._config_service = ClientConfigService.new()
	plugin._client_install_detection_service = ClientInstallDetectionService.new()
	plugin._server_feature = ServerFeatureScript.new()
	plugin._config_feature = ConfigFeatureScript.new()
	plugin._user_tool_feature = UserToolFeatureScript.new()
	plugin._reload_feature = ReloadFeatureScript.new()
	plugin._tool_profile_feature = ToolProfileFeatureScript.new()
	plugin._tool_access_feature = ToolAccessFeatureScript.new()
	plugin._self_diagnostic_feature = SelfDiagnosticFeatureScript.new()
	plugin._ui_state_feature = UIStateFeatureScript.new()
	plugin._dock_presenter = DockPresenterScript.new()
	plugin._dock_model_service = DockModelServiceScript.new()
	plugin._user_tool_service = UserToolService.new()
	plugin._user_tool_watch_service = UserToolWatchService.new()
	plugin._central_server_attach_service = CentralServerAttachServiceScript.new()
	plugin._central_server_process_service = CentralServerProcessServiceScript.new()
