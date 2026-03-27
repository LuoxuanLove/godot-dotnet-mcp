@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "project_state",
			"description": "PROJECT STATE: Snapshot of current project health — file counts, runtime errors, compile errors, bridge status. Use first to orient before diagnosing. Returns: error_count, compile_error_count, recent_errors[], has_dotnet, running, runtime_bridge_status, scene_paths[], script_paths[]. Optional: error_limit (default 10).",
			"inputSchema": {
				"type": "object",
				"properties": {
					"error_limit": {"type": "integer", "description": "Max errors to include (default: 10)"},
					"include_runtime_health": {"type": "boolean", "description": "Include lightweight plugin runtime health summary, including lsp_diagnostics and tool_loader health (default: false)"}
				}
			}
		},
		{
			"name": "project_advise",
			"description": "PROJECT ADVISE: Actionable suggestions and next-tool recommendations based on live project state. Use when you need prioritized action items rather than raw data. Returns: suggestions[]{category, severity, message, tool_hint}, next_tools[]. Optional: goal (e.g. \"fix errors\", \"explore scene\") to refine recommendations.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"goal": {"type": "string", "description": "Goal context for workflow recommendations (default: general)"},
					"include_suggestions": {"type": "boolean", "description": "Include diagnostic suggestions (default: true)"},
					"include_workflow": {"type": "boolean", "description": "Include workflow next_tools recommendations (default: true)"}
				}
			}
		},
		{
			"name": "project_configure",
			"description": "PROJECT CONFIGURE: Read or modify project settings, autoloads, and input actions. Read actions: get_settings (requires: setting), list_autoloads, list_input_actions. Write actions: set_setting (requires: setting, value), add_autoload (requires: name, path), remove_autoload (requires: name). Call get_settings to inspect a path before modifying.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_settings", "set_setting", "list_autoloads", "add_autoload", "remove_autoload", "list_input_actions"], "description": "Configuration action to perform"},
					"setting": {"type": "string", "description": "Setting path for get_settings/set_setting"},
					"value": {"description": "New value for set_setting"},
					"name": {"type": "string", "description": "Autoload name for add/remove_autoload"},
					"path": {"type": "string", "description": "Script path for add_autoload"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "project_run",
			"description": "PROJECT RUN: Launch the project in the Godot editor. Runs the main scene by default; provide scene (.tscn path) to run a specific scene. Recommend checking project_state for compile errors before running. Pair with project_stop.",
			"inputSchema": {"type": "object", "properties": {"scene": {"type": "string", "description": "Custom scene to run (optional, runs main scene if omitted)"}}}
		},
		{
			"name": "project_stop",
			"description": "PROJECT STOP: Stop the currently running project in the editor. No parameters. Returns: stopped=true on success.",
			"inputSchema": {"type": "object", "properties": {}}
		},
		{
			"name": "runtime_diagnose",
			"description": "RUNTIME DIAGNOSE: Full error report with stacktraces — use when project_state shows error_count > 0 or compile_error_count > 0. Returns: has_errors, runtime_errors[]{message, script, line, stacktrace}, compile_errors[]{message, source_file, source_line}. Key options: tail (default 20, limits runtime error count), include_gd_errors=true adds GDScript Output panel errors (gd_errors[]{severity, message, file, line}), include_performance=true adds fps/memory snapshot.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"include_compile_errors": {"type": "boolean", "description": "Include .NET compile errors (default: true)"},
					"include_performance": {"type": "boolean", "description": "Include performance snapshot: FPS, memory, render info (default: false)"},
					"tail": {"type": "integer", "description": "Number of recent runtime errors to include (default: 20)"},
					"include_gd_errors": {"type": "boolean", "description": "Include GDScript errors/warnings from the editor Output panel (default: false)"}
				}
			}
		}
	]
