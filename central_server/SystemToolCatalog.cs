using System.Text.Json;
using System.Text.Json.Nodes;

namespace GodotDotnetMcp.CentralServer;

internal static class SystemToolCatalog
{
    private static readonly IReadOnlyList<SystemToolDefinition> Definitions =
    [
        new(
            "system_project_state",
            "PROJECT STATE: Snapshot of current project health — file counts, runtime errors, compile errors, bridge status. Use first to orient before diagnosing. Returns: error_count, compile_error_count, recent_errors[], has_dotnet, running, runtime_bridge_status, scene_paths[], script_paths[]. Optional: error_limit (default 10).",
            """
            {
              "type": "object",
              "properties": {
                "error_limit": { "type": "integer", "description": "Max errors to include (default: 10)" },
                "include_runtime_health": { "type": "boolean", "description": "Include lightweight plugin runtime health summary, including lsp_diagnostics and tool_loader health (default: false)" }
              }
            }
            """),
        new(
            "system_project_advise",
            "PROJECT ADVISE: Actionable suggestions and next-tool recommendations based on live project state. Use when you need prioritized action items rather than raw data. Returns: suggestions[]{category, severity, message, tool_hint}, next_tools[]. Optional: goal (e.g. \"fix errors\", \"explore scene\") to refine recommendations.",
            """
            {
              "type": "object",
              "properties": {
                "goal": { "type": "string", "description": "Goal context for workflow recommendations (default: general)" },
                "include_suggestions": { "type": "boolean", "description": "Include diagnostic suggestions (default: true)" },
                "include_workflow": { "type": "boolean", "description": "Include workflow next_tools recommendations (default: true)" }
              }
            }
            """),
        new(
            "system_project_configure",
            "PROJECT CONFIGURE: Read or modify project settings, autoloads, and input actions. Read actions: get_settings (requires: setting), list_autoloads, list_input_actions. Write actions: set_setting (requires: setting, value), add_autoload (requires: name, path), remove_autoload (requires: name). Call get_settings to inspect a path before modifying.",
            """
            {
              "type": "object",
              "properties": {
                "action": {
                  "type": "string",
                  "enum": ["get_settings", "set_setting", "list_autoloads", "add_autoload", "remove_autoload", "list_input_actions"],
                  "description": "Configuration action to perform"
                },
                "setting": { "type": "string", "description": "Setting path for get_settings/set_setting" },
                "value": { "description": "New value for set_setting" },
                "name": { "type": "string", "description": "Autoload name for add/remove_autoload" },
                "path": { "type": "string", "description": "Script path for add_autoload" }
              },
              "required": ["action"]
            }
            """),
        new(
            "system_project_run",
            "PROJECT RUN: Launch the project in the Godot editor. Runs the main scene by default; provide scene (.tscn path) to run a specific scene. Recommend checking project_state for compile errors before running. Pair with project_stop.",
            """
            {
              "type": "object",
              "properties": {
                "scene": { "type": "string", "description": "Custom scene to run (optional, runs main scene if omitted)" }
              }
            }
            """),
        new(
            "system_project_stop",
            "PROJECT STOP: Stop the currently running project in the editor. No parameters. Returns: stopped=true on success.",
            """
            {
              "type": "object",
              "properties": {}
            }
            """),
        new(
            "system_runtime_diagnose",
            "RUNTIME DIAGNOSE: Full error report with stacktraces — use when project_state shows error_count > 0 or compile_error_count > 0. Returns: has_errors, runtime_errors[]{message, script, line, stacktrace}, compile_errors[]{message, source_file, source_line}. Key options: tail (default 20, limits runtime error count), include_gd_errors=true adds GDScript Output panel errors (gd_errors[]{severity, message, file, line}), include_performance=true adds fps/memory snapshot.",
            """
            {
              "type": "object",
              "properties": {
                "include_compile_errors": { "type": "boolean", "description": "Include .NET compile errors (default: true)" },
                "include_performance": { "type": "boolean", "description": "Include performance snapshot: FPS, memory, render info (default: false)" },
                "tail": { "type": "integer", "description": "Number of recent runtime errors to include (default: 20)" },
                "include_gd_errors": { "type": "boolean", "description": "Include GDScript errors/warnings from the editor Output panel (default: false)" }
              }
            }
            """),
        new(
            "system_scene_validate",
            "SCENE VALIDATE: Quick integrity check of a .tscn file — structural errors and missing file references. Lighter than scene_analyze; use first to confirm a scene is loadable. Returns: valid, issues[]{severity, type, message}, missing_dependencies[]. Requires: scene (.tscn path).",
            """
            {
              "type": "object",
              "properties": {
                "scene": { "type": "string", "description": "Scene path (res://..., .tscn)" }
              },
              "required": ["scene"]
            }
            """),
        new(
            "system_scene_analyze",
            "SCENE ANALYZE: Deep inspection of a .tscn — node count, attached scripts with class_name/base_type, signal bindings, and structural issues. Use after scene_validate passes, or when debugging binding mismatches. Returns: node_count, binding_count, scripts[]{path, class_name, base_type}, issues[]. Requires: scene (.tscn path).",
            """
            {
              "type": "object",
              "properties": {
                "scene": { "type": "string", "description": "Scene path (res://..., .tscn)" }
              },
              "required": ["scene"]
            }
            """),
        new(
            "system_scene_patch",
            "SCENE PATCH: Apply structured edits to a .tscn file. Ops: add_node, remove_node, set_property, attach_script, reparent_node, rename_node, update_property. dry_run=true (default) previews without saving — always confirm first. Returns: op_previews[]{op, valid} (dry_run), applied_ops[], failed_ops[] (applied). Note: update_property verifies the property exists before writing (use set_property to force-write). Requires: scene and ops[].",
            """
            {
              "type": "object",
              "properties": {
                "scene": { "type": "string", "description": "Scene path (res://..., .tscn)" },
                "ops": {
                  "type": "array",
                  "description": "List of patch operations",
                  "items": {
                    "type": "object",
                    "properties": {
                      "op": { "type": "string", "enum": ["add_node", "remove_node", "set_property", "attach_script", "reparent_node", "rename_node", "update_property"] },
                      "name": { "type": "string" },
                      "type": { "type": "string" },
                      "parent_path": { "type": "string" },
                      "node_path": { "type": "string" },
                      "property": { "type": "string" },
                      "value": {},
                      "script": { "type": "string" },
                      "new_parent": { "type": "string" },
                      "new_name": { "type": "string", "description": "New name (used by rename_node)" }
                    },
                    "required": ["op"]
                  }
                },
                "dry_run": { "type": "boolean", "description": "Preview without executing (default: true)" }
              },
              "required": ["scene", "ops"]
            }
            """),
        new(
            "system_bindings_audit",
            "BINDINGS AUDIT: Audit C# [Export]/[Signal]/NodePath binding consistency against scene references. C# only (.cs). Provide script to audit one file, scene to audit its scripts, or omit both to scan all .cs in project. Returns: total_issues, results[]{kind, issues[]{severity, type, message}}. Use when runtime_diagnose shows C# binding errors.",
            """
            {
              "type": "object",
              "properties": {
                "script": { "type": "string", "description": "C# script path (optional)" },
                "scene": { "type": "string", "description": "Scene path (optional)" },
                "include_warnings": { "type": "boolean", "description": "Include warnings (default: true)" }
              }
            }
            """),
        new(
            "system_script_analyze",
            "SCRIPT ANALYZE: Inspect a .gd or .cs script — class structure, methods, exports, signals, variables, and scene references. Returns: class_name, base_type, methods[], exports[], signals[], variables[], scene_refs[], issues[]. For .gd files: include_diagnostics=true adds background diagnostics{available, pending, parse_errors[]{severity, message, line, column}, error_count} via Godot LSP using the saved file content on disk. The first call may return pending while LSP work finishes in the background. Unsaved editor buffer changes are not included. Requires: script path.",
            """
            {
              "type": "object",
              "properties": {
                "script": { "type": "string", "description": "Script path (res://..., .gd or .cs)" },
                "include_diagnostics": { "type": "boolean", "description": "Include GDScript static diagnostics via Godot LSP (default: false, .gd only)" }
              },
              "required": ["script"]
            }
            """),
        new(
            "system_script_patch",
            "SCRIPT PATCH: Add or edit members in a .gd or .cs script. Add ops: add_method, add_export, add_variable (both); add_signal (.gd only). Edit ops: replace_method_body (replace function body, keep signature), delete_member (remove declaration; member_type: function/variable/signal/auto), rename_member (rename declaration only, not references; new_name required). dry_run=true (default) previews — check op_previews[]{op, valid, name} before applying. Returns: applied_ops[], failed_ops[]{op, error} when dry_run=false. Requires: script and ops[].",
            """
            {
              "type": "object",
              "properties": {
                "script": { "type": "string", "description": "Script path (res://...)" },
                "ops": {
                  "type": "array",
                  "description": "List of patch operations",
                  "items": {
                    "type": "object",
                    "properties": {
                      "op": { "type": "string", "enum": ["add_method", "add_export", "add_signal", "add_variable", "replace_method_body", "delete_member", "rename_member"] },
                      "name": { "type": "string", "description": "Member name (old name for rename_member)" },
                      "type": { "type": "string", "description": "Type annotation" },
                      "default_value": { "type": "string", "description": "Default value expression" },
                      "body": { "type": "string", "description": "Method body (for add_method / replace_method_body)" },
                      "params": { "type": "array", "description": "Parameters for add_method/add_signal" },
                      "hint": { "type": "string", "description": "Export hint for add_export" },
                      "onready": { "type": "boolean", "description": "Add @onready for add_variable" },
                      "member_type": { "type": "string", "description": "Member type for delete_member: function, variable, signal, auto (default: auto)" },
                      "new_name": { "type": "string", "description": "New name for rename_member" }
                    },
                    "required": ["op", "name"]
                  }
                },
                "dry_run": { "type": "boolean", "description": "Preview without executing (default: true)" }
              },
              "required": ["script", "ops"]
            }
            """),
        new(
            "system_project_index_build",
            "PROJECT INDEX BUILD: Build an in-memory symbol index over all scripts, scenes, and resources. MUST be called before project_symbol_search or scene_dependency_graph. Index is session-scoped — call again after plugin reload. Returns: script_count, scene_count, resource_count, symbol_count. Optional: include_resources=false to skip .tres/.res files.",
            """
            {
              "type": "object",
              "properties": {
                "include_resources": { "type": "boolean", "description": "Whether to include .tres/.res resources in the index (default: true)" }
              }
            }
            """),
        new(
            "system_project_symbol_search",
            "PROJECT SYMBOL SEARCH: Find scripts, scenes, or classes by name in the project index. REQUIRES project_index_build first. Matches class names, script filenames, scene filenames (exact and partial). Returns: matches[]{symbol, kind, path, class_name, base_type}, exact_match_count, partial_match_count. Requires: symbol (name to search).",
            """
            {
              "type": "object",
              "properties": {
                "symbol": { "type": "string", "description": "Symbol name to search for (class name, script basename, or scene name)" }
              },
              "required": ["symbol"]
            }
            """),
        new(
            "system_scene_dependency_graph",
            "SCENE DEPENDENCY GRAPH: Scene-to-scene dependency map from ExtResource references. REQUIRES project_index_build first. Omit root_scene for full project map; set root_scene (.tscn) to traverse from a specific scene. Optional: max_depth (default 4). Returns: dependencies{scene_path → [dep_paths]}, count.",
            """
            {
              "type": "object",
              "properties": {
                "root_scene": { "type": "string", "description": "Optional root scene path. If omitted, returns the full dependency map." },
                "max_depth": { "type": "integer", "description": "Optional max traversal depth when a root_scene is provided (default: 4)" }
              }
            }
            """)
    ];

    public static IReadOnlyList<object> GetTools()
    {
        return Definitions.Select(BuildTool).ToArray();
    }

    public static bool IsSystemTool(string toolName)
    {
        return Definitions.Any(definition => string.Equals(definition.Name, toolName, StringComparison.OrdinalIgnoreCase));
    }

    private static object BuildTool(SystemToolDefinition definition)
    {
        var schema = JsonNode.Parse(definition.InputSchemaJson) as JsonObject
                     ?? new JsonObject { ["type"] = "object" };
        var properties = schema["properties"] as JsonObject;
        if (properties is null)
        {
            properties = new JsonObject();
            schema["properties"] = properties;
        }

        properties["projectId"] = new JsonObject
        {
            ["type"] = "string",
            ["description"] = "Optional registered project id override for this call."
        };
        properties["projectPath"] = new JsonObject
        {
            ["type"] = "string",
            ["description"] = "Optional Godot project root or project.godot path override for this call."
        };
        properties["autoLaunchEditor"] = new JsonObject
        {
            ["type"] = "boolean",
            ["description"] = "Auto-launch or reuse the editor when no ready editor session is attached (default: true)."
        };
        properties["editorAttachTimeoutMs"] = new JsonObject
        {
            ["type"] = "integer",
            ["description"] = "How long to wait for the editor attach session to become HTTP-ready (default: 45000)."
        };

        var inputSchema = JsonSerializer.Deserialize<object>(schema.ToJsonString(), CentralServerSerialization.JsonOptions)
                          ?? new { type = "object", properties = new { } };

        return new
        {
            name = definition.Name,
            description = definition.Description,
            inputSchema,
        };
    }

    private sealed record SystemToolDefinition(string Name, string Description, string InputSchemaJson);
}
