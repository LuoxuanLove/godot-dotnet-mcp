extends RefCounted


func resolve_plugin_host(server_context):
	if server_context != null and is_instance_valid(server_context) and server_context.has_method("get_parent"):
		var plugin = server_context.get_parent()
		if plugin != null and is_instance_valid(plugin):
			return plugin
	return null


func build_runtime_context(tool_loader, server_context, plugin_host, tool_activity_registry) -> Dictionary:
	return {
		"tool_loader": tool_loader,
		"server": server_context,
		"plugin_host": plugin_host,
		"tool_activity_registry": tool_activity_registry
	}


func build_executor_runtime_context(
	tool_loader,
	server_context,
	plugin_host,
	tool_activity_registry,
	category: String,
	entry: Dictionary,
	reason: String
) -> Dictionary:
	var context := build_runtime_context(tool_loader, server_context, plugin_host, tool_activity_registry)
	context["category"] = category
	context["reason"] = reason
	context["entry"] = entry.duplicate(true)
	return context


func configure_loaded_runtimes(runtime_by_category: Dictionary, context: Dictionary) -> int:
	var configured_count := 0
	for category in runtime_by_category.keys():
		var runtime = runtime_by_category.get(category, {})
		if not (runtime is Dictionary):
			continue
		var executor = (runtime as Dictionary).get("instance", null)
		if executor == null or not executor.has_method("configure_runtime"):
			continue
		executor.configure_runtime(context.duplicate())
		configured_count += 1
	return configured_count
