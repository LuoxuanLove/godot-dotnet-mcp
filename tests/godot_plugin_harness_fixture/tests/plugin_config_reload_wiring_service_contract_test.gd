extends RefCounted

# {"name": "plugin_config_reload_wiring_service_contracts"}

const PluginConfigReloadWiringServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_config_reload_wiring_service.gd")


class FakeBaseControl:
	extends RefCounted

	var children: Array = []

	func add_child(child) -> void:
		children.append(child)


class FakeEditorInterface:
	extends RefCounted

	var base_control

	func get_base_control():
		return base_control


class FakeTimer:
	extends RefCounted

	signal timeout


class FakeTree:
	extends RefCounted

	var timer_delay := -1.0
	var timer := FakeTimer.new()

	func create_timer(delay: float):
		timer_delay = delay
		return timer


class FakeWatchService:
	extends RefCounted

	var calls: Array[String] = []
	var configured: Dictionary = {}

	func stop() -> void:
		calls.append("stop")

	func configure(plugin_host, reload_coordinator, user_tool_service, apply_external_user_tool_catalog_refresh: Callable = Callable()) -> void:
		calls.append("configure")
		configured = {
			"plugin_host": plugin_host,
			"reload_coordinator": reload_coordinator,
			"user_tool_service": user_tool_service,
			"apply_external_user_tool_catalog_refresh": apply_external_user_tool_catalog_refresh
		}

	func start() -> void:
		calls.append("start")


class FakeConfigActionService:
	extends RefCounted

	var configured_context: Dictionary = {}

	func configure(context) -> void:
		configured_context = (context as Dictionary).duplicate(true)


class FakePluginContext:
	extends RefCounted

	var base_control := FakeBaseControl.new()
	var editor_interface := FakeEditorInterface.new()
	var tree := FakeTree.new()
	var inside_tree := true
	var callback_calls := 0
	var schedule_calls := 0

	func _init() -> void:
		editor_interface.base_control = base_control

	func build() -> Dictionary:
		return {
			"plugin_id": "godot_dotnet_mcp",
			"plugin_host": self,
			"server_controller": RefCounted.new(),
			"state": RefCounted.new(),
			"localization": RefCounted.new(),
			"config_service": RefCounted.new(),
			"client_install_detection_service": RefCounted.new(),
			"user_tool_service": RefCounted.new(),
			"get_editor_interface": Callable(self, "get_editor_interface"),
			"is_inside_tree": Callable(self, "is_inside_tree"),
			"get_tree": Callable(self, "get_tree"),
			"schedule_plugin_reenable": Callable(self, "schedule_plugin_reenable"),
			"complete_plugin_reenable_schedule": Callable(self, "complete_plugin_reenable_schedule"),
			"apply_external_user_tool_catalog_refresh": Callable(self, "apply_external_user_tool_catalog_refresh"),
			"get_client_install_statuses": Callable(self, "get_client_install_statuses"),
			"invalidate_client_install_status_cache": Callable(self, "invalidate_client_install_status_cache"),
			"configure_client_install_detection_service": Callable(self, "configure_client_install_detection_service"),
			"refresh_dock": Callable(self, "refresh_dock"),
			"save_settings": Callable(self, "save_settings"),
			"show_message": Callable(self, "show_message"),
			"show_confirmation": Callable(self, "show_confirmation"),
			"ensure_client_executable_dialog": Callable(self, "ensure_client_executable_dialog"),
			"get_client_executable_dialog": Callable(self, "get_client_executable_dialog")
		}

	func get_editor_interface():
		return editor_interface

	func is_inside_tree() -> bool:
		return inside_tree

	func get_tree():
		return tree

	func complete_plugin_reenable_schedule() -> void:
		callback_calls += 1

	func schedule_plugin_reenable() -> bool:
		schedule_calls += 1
		return true

	func apply_external_user_tool_catalog_refresh(_paths: Array[String], _reason: String = "external_watch") -> void:
		pass

	func get_client_install_statuses() -> Dictionary:
		return {}

	func invalidate_client_install_status_cache() -> void:
		pass

	func configure_client_install_detection_service() -> void:
		pass

	func refresh_dock() -> void:
		pass

	func save_settings() -> void:
		pass

	func show_message(_message: String) -> void:
		pass

	func show_confirmation(_message: String, on_confirmed: Callable) -> void:
		if on_confirmed.is_valid():
			on_confirmed.call()

	func ensure_client_executable_dialog() -> void:
		pass

	func get_client_executable_dialog():
		return null


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _assert_plugin_entrypoint_uses_config_reload_wiring_service()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = PluginConfigReloadWiringServiceScript.new()
	var fake := FakePluginContext.new()
	if not service.schedule_plugin_reenable_deferred(fake.build()):
		return _failure("Deferred plugin re-enable scheduling should succeed when editor interface and tree are available.")
	if not is_equal_approx(fake.tree.timer_delay, 0.05):
		return _failure("Config/reload wiring service should preserve the short tree-stabilization delay before plugin re-enable scheduling.", {"delay": fake.tree.timer_delay})
	if fake.base_control.children.size() != 0:
		return _failure("Deferred plugin re-enable scheduling should not attach the coordinator until the timer fires.")
	fake.tree.timer.timeout.emit()
	if fake.callback_calls != 1:
		return _failure("Deferred plugin re-enable scheduling should connect the timer to the plugin completion callback.")

	var fallback := FakePluginContext.new()
	fallback.inside_tree = false
	if not service.schedule_plugin_reenable_deferred(fallback.build()):
		return _failure("Plugin re-enable scheduling should fall back to immediate scheduling when the plugin is outside the tree.")
	if fallback.schedule_calls != 1:
		return _failure("Plugin re-enable deferred fallback should call the plugin-owned schedule callback exactly once.")
	if fallback.base_control.children.size() != 0:
		return _failure("Plugin re-enable deferred fallback should not bypass the plugin-owned schedule callback.")

	var watch := FakeWatchService.new()
	var watch_result = service.configure_user_tool_watch_service(watch, fake.build())
	if watch_result != watch:
		return _failure("Config/reload wiring should reuse the existing user-tool watch service instance.")
	if watch.calls != ["stop", "configure", "start"]:
		return _failure("User-tool watch service should preserve stop/configure/start order.", {"calls": watch.calls})
	if watch.configured.get("reload_coordinator", null) != null:
		return _failure("User-tool watch wiring should use the external refresh callback path instead of creating a reload coordinator fallback.")
	var callback: Callable = watch.configured.get("apply_external_user_tool_catalog_refresh", Callable())
	if not callback.is_valid():
		return _failure("User-tool watch wiring should provide the external catalog refresh callback.")

	var action_service := FakeConfigActionService.new()
	var action_result = service.configure_config_tab_action_service(action_service, fake.build())
	if action_result != action_service:
		return _failure("Config/reload wiring should reuse the existing config tab action service instance.")
	for required_key in [
		"state",
		"localization",
		"config_service",
		"client_install_detection_service",
		"get_client_install_statuses",
		"invalidate_client_install_status_cache",
		"configure_client_install_detection_service",
		"refresh_dock",
		"save_settings",
		"show_message",
		"show_confirmation",
		"ensure_client_executable_dialog",
		"get_client_executable_dialog"
	]:
		if not action_service.configured_context.has(required_key):
			return _failure("Config tab action wiring should preserve required context key: %s" % required_key)

	return {
		"name": "plugin_config_reload_wiring_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"config_context_keys": action_service.configured_context.size(),
			"defer_delay": fake.tree.timer_delay,
			"watch_calls": watch.calls.size()
		}
	}


func _assert_plugin_entrypoint_uses_config_reload_wiring_service() -> String:
	var source_path := "res://addons/godot_dotnet_mcp/plugin.gd"
	if not FileAccess.file_exists(source_path):
		return "Plugin entrypoint source should exist for config/reload wiring guard."
	var source := FileAccess.get_file_as_string(source_path)
	for required in [
		"PluginConfigReloadWiringServiceScript",
		"_config_reload_wiring_service.schedule_plugin_reenable(",
		"_config_reload_wiring_service.schedule_plugin_reenable_deferred(",
		"_config_reload_wiring_service.configure_user_tool_watch_service(",
		"_config_reload_wiring_service.configure_config_tab_action_service("
	]:
		if source.find(required) == -1:
			return "Plugin entrypoint should delegate config/reload wiring through PluginConfigReloadWiringService: %s" % required
	for forbidden in [
		"PluginReloadCoordinator = preload",
		"ConfigTabActionServiceScript = preload",
		"UserToolWatchServiceScript = preload",
		"PluginReloadCoordinator.new()",
		"coordinator.request_reload(",
		"coordinator.request_reload_by_script(",
		"coordinator.request_reload_all(",
		"ConfigTabActionServiceScript.new()",
		"UserToolWatchServiceScript.new()"
	]:
		if source.find(forbidden) != -1:
			return "Plugin entrypoint should not own config/reload wiring primitive directly: %s" % forbidden
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {
		"name": "plugin_config_reload_wiring_service_contracts",
		"success": false,
		"error": message,
		"details": details
	}
