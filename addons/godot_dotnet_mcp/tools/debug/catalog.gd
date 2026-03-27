@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "log_write",
			"description": "LOG WRITE: Write messages to Godot output.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["print", "warning", "error", "rich"]},
					"message": {"type": "string"},
					"limit": {"type": "integer"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "log_buffer",
			"description": "LOG BUFFER: Read or clear buffered MCP debug events.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_recent", "get_errors", "clear_buffer"]},
					"limit": {"type": "integer"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "runtime_bridge",
			"description": "RUNTIME BRIDGE: Read structured runtime bridge events.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_recent", "get_errors", "get_sessions", "get_summary", "clear_buffer", "get_recent_filtered", "get_errors_context", "get_scene_snapshot"]},
					"limit": {"type": "integer"},
					"level": {"type": "string", "enum": ["error", "warning", "info"]},
					"tail": {"type": "integer"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "dotnet",
			"description": "DOTNET DIAGNOSTICS: Run dotnet restore/build and return structured results.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["restore", "build"]},
					"path": {"type": "string"},
					"timeout_sec": {"type": "integer"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "performance",
			"description": "PERFORMANCE: Get performance metrics and monitor resource usage.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_fps", "get_memory", "get_monitors", "get_render_info"]}
				},
				"required": ["action"]
			}
		},
		{
			"name": "profiler",
			"description": "PROFILER: Control the built-in profiler.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["start", "stop", "is_active", "get_summary"]}
				},
				"required": ["action"]
			}
		},
		{
			"name": "editor_log",
			"description": "EDITOR LOG: Read or clear the Godot editor Output panel.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_output", "get_errors", "clear"]},
					"limit": {"type": "integer"},
					"include_warnings": {"type": "boolean"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "class_db",
			"description": "CLASS DATABASE: Query information about Godot classes.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_class_list", "get_class_info", "get_class_methods", "get_class_properties", "get_class_signals", "get_inheriters", "class_exists"]},
					"class_name": {"type": "string"},
					"include_inherited": {"type": "boolean"}
				},
				"required": ["action"]
			}
		}
	]
