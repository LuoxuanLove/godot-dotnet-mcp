@tool
extends RefCounted
class_name PluginRuntimeState

var settings: Dictionary = {}
var custom_tool_profiles: Dictionary = {}
var current_cli_scope := "user"
var current_config_platform := "claude_desktop"
var current_tab := 0
var restore_focus := false
var needs_initial_tool_profile_apply := false
