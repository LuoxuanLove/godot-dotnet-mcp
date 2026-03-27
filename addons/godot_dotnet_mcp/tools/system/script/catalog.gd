@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "bindings_audit",
			"description": "BINDINGS AUDIT: Audit C# [Export]/[Signal]/NodePath binding consistency against scene references. C# only (.cs). Provide script to audit one file, scene to audit its scripts, or omit both to scan all .cs in project. Returns: total_issues, results[]{kind, issues[]{severity, type, message}}. Use when runtime_diagnose shows C# binding errors.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"script": {"type": "string", "description": "C# script path (optional)"},
					"scene": {"type": "string", "description": "Scene path (optional)"},
					"include_warnings": {"type": "boolean", "description": "Include warnings (default: true)"}
				}
			}
		},
		{
			"name": "script_analyze",
			"description": "SCRIPT ANALYZE: Inspect a .gd or .cs script — class structure, methods, exports, signals, variables, and scene references. Returns: class_name, base_type, methods[], exports[], signals[], variables[], scene_refs[], issues[]. For .gd files: include_diagnostics=true adds background diagnostics{available, pending, parse_errors[]{severity, message, line, column}, error_count} via Godot LSP using the saved file content on disk. The first call may return pending while LSP work finishes in the background. Unsaved editor buffer changes are not included. Requires: script path.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"script": {"type": "string", "description": "Script path (res://..., .gd or .cs)"},
					"include_diagnostics": {"type": "boolean", "description": "Include GDScript static diagnostics via Godot LSP (default: false, .gd only)"}
				},
				"required": ["script"]
			}
		},
		{
			"name": "script_patch",
			"description": "SCRIPT PATCH: Add or edit members in a .gd or .cs script. Add ops: add_method, add_export, add_variable (both); add_signal (.gd only). Edit ops: replace_method_body (replace function body, keep signature), delete_member (remove declaration; member_type: function/variable/signal/auto), rename_member (rename declaration only, not references; new_name required). dry_run=true (default) previews — check op_previews[]{op, valid, name} before applying. Returns: applied_ops[], failed_ops[]{op, error} when dry_run=false. Requires: script and ops[].",
			"inputSchema": {
				"type": "object",
				"properties": {
					"script": {"type": "string", "description": "Script path (res://...)"},
					"ops": {
						"type": "array",
						"description": "List of patch operations",
						"items": {
							"type": "object",
							"properties": {
								"op": {"type": "string", "enum": ["add_method", "add_export", "add_signal", "add_variable", "replace_method_body", "delete_member", "rename_member"]},
								"name": {"type": "string", "description": "Member name (old name for rename_member)"},
								"type": {"type": "string", "description": "Type annotation"},
								"default_value": {"type": "string", "description": "Default value expression"},
								"body": {"type": "string", "description": "Method body (for add_method / replace_method_body)"},
								"params": {"type": "array", "description": "Parameters for add_method/add_signal"},
								"hint": {"type": "string", "description": "Export hint for add_export"},
								"onready": {"type": "boolean", "description": "Add @onready for add_variable"},
								"member_type": {"type": "string", "description": "Member type for delete_member: function, variable, signal, auto (default: auto)"},
								"new_name": {"type": "string", "description": "New name for rename_member"}
							},
							"required": ["op", "name"]
						}
					},
					"dry_run": {"type": "boolean", "description": "Preview without executing (default: true)"}
				},
				"required": ["script", "ops"]
			}
		}
	]
