using GodotDotnetMcp.HostShared;

namespace GodotDotnetMcp.CentralServer;

internal static class CentralToolCatalog
{
    public static IReadOnlyList<object> GetTools()
    {
        return
        [
            CreateProjectListTool(),
            CreateProjectRegisterTool(),
            CreateProjectRemoveTool(),
            CreateProjectSelectTool(),
            CreateProjectStatusTool(),
            CreateProjectRescanTool(),
            CreateEditorSessionListTool(),
            CreateProjectSetGodotPathTool(),
            CreateProjectOpenEditorTool(),
            CreateProjectCloseEditorTool(),
            CreateProjectRestartEditorTool(),
            CreateGodotInstallationListTool(),
            CreateGodotInstallationSetDefaultTool(),
            CreateGodotManagerListProjectsTool(),
            CreateGodotManagerGetStatusTool(),
            CreateGodotManagerImportProjectsTool(),
            ..SystemToolCatalog.GetTools(),
            ..BridgeToolCatalog.GetTools(),
        ];
    }

    private static object CreateProjectListTool()
    {
        return new
        {
            name = "workspace_project_list",
            description = "List registered Godot projects and show the current active project for this session.",
            inputSchema = new
            {
                type = "object",
                properties = new { },
                additionalProperties = false,
            },
        };
    }

    private static object CreateProjectRegisterTool()
    {
        return new
        {
            name = "workspace_project_register",
            description = "Register a Godot project root in the central server registry.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    path = new { type = "string", description = "Path to a Godot project root or project.godot file." },
                    source = new { type = "string", description = "Optional source label such as manual or workspace_scan." },
                },
                required = new[] { "path" },
                additionalProperties = false,
            },
        };
    }

    private static object CreateProjectRemoveTool()
    {
        return new
        {
            name = "workspace_project_remove",
            description = "Remove a registered project by projectId or path.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    projectId = new { type = "string", description = "Registered project id." },
                    path = new { type = "string", description = "Path to a registered Godot project root or project.godot file." },
                },
                additionalProperties = false,
            },
        };
    }

    private static object CreateProjectSelectTool()
    {
        return new
        {
            name = "workspace_project_select",
            description = "Select the active project for the current MCP session by projectId or path.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    projectId = new { type = "string", description = "Registered project id." },
                    path = new { type = "string", description = "Path to a registered Godot project root or project.godot file." },
                },
                additionalProperties = false,
            },
        };
    }

    private static object CreateProjectStatusTool()
    {
        return new
        {
            name = "workspace_project_status",
            description = "Show central server registry status and the active project for the current session.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    projectId = new { type = "string", description = "Optional registered project id to inspect." },
                    path = new { type = "string", description = "Optional project path to inspect." },
                },
                additionalProperties = false,
            },
        };
    }

    private static object CreateProjectRescanTool()
    {
        return new
        {
            name = "workspace_project_rescan",
            description = "Scan one or more workspace roots for Godot projects and optionally import discovered projects.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    roots = new
                    {
                        type = "array",
                        items = new { type = "string" },
                        description = "Workspace roots to scan recursively for project.godot files.",
                    },
                    importDiscovered = new { type = "boolean", description = "Import newly discovered projects into the registry. Defaults to false." },
                },
                required = new[] { "roots" },
                additionalProperties = false,
            },
        };
    }

    private static object CreateEditorSessionListTool()
    {
        return new
        {
            name = "workspace_editor_session_list",
            description = "List active editor-attached sessions currently connected to the central server.",
            inputSchema = new
            {
                type = "object",
                properties = new { },
                additionalProperties = false,
            },
        };
    }

    private static object CreateProjectSetGodotPathTool()
    {
        return new
        {
            name = "workspace_project_set_godot_path",
            description = "Assign a project-specific Godot executable path for a registered project.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    projectId = new { type = "string", description = "Registered project id." },
                    executablePath = new { type = "string", description = "Absolute path to the Godot executable." },
                },
                required = new[] { "projectId", "executablePath" },
                additionalProperties = false,
            },
        };
    }

    private static object CreateProjectOpenEditorTool()
    {
        return new
        {
            name = "workspace_project_open_editor",
            description = "Open the Godot editor for a registered project using an explicit, project-specific, default, or discovered executable.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    projectId = new { type = "string", description = "Registered project id." },
                    path = new { type = "string", description = "Alternative registered project path." },
                    executablePath = new { type = "string", description = "Optional explicit Godot executable path override." },
                    attachTimeoutMs = new { type = "integer", description = "Optional attach timeout in milliseconds while waiting for the editor to become ready." },
                },
                additionalProperties = false,
            },
        };
    }

    private static object CreateProjectCloseEditorTool()
    {
        return new
        {
            name = "workspace_project_close_editor",
            description = "Close a resident Godot editor for a registered project. Requires save=true for graceful close or force=true for host-managed fallback.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    projectId = new { type = "string", description = "Registered project id." },
                    path = new { type = "string", description = "Alternative registered project path." },
                    save = new { type = "boolean", description = "Gracefully save open scenes and close the editor." },
                    force = new { type = "boolean", description = "Force close only when the editor process is host-managed." },
                    shutdownTimeoutMs = new { type = "integer", description = "Optional shutdown timeout in milliseconds." },
                },
                additionalProperties = false,
            },
        };
    }

    private static object CreateProjectRestartEditorTool()
    {
        return new
        {
            name = "workspace_project_restart_editor",
            description = "Restart a resident Godot editor for a registered project. Requires save=true for graceful restart or force=true for host-managed fallback.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    projectId = new { type = "string", description = "Registered project id." },
                    path = new { type = "string", description = "Alternative registered project path." },
                    save = new { type = "boolean", description = "Gracefully save open scenes and restart the editor." },
                    force = new { type = "boolean", description = "Force restart only when the editor process is host-managed." },
                    shutdownTimeoutMs = new { type = "integer", description = "Optional shutdown timeout in milliseconds." },
                    attachTimeoutMs = new { type = "integer", description = "Optional attach timeout in milliseconds while waiting for the restarted editor." },
                },
                additionalProperties = false,
            },
        };
    }

    private static object CreateGodotInstallationListTool()
    {
        return new
        {
            name = "workspace_godot_installation_list",
            description = "List discoverable Godot executable candidates on this machine.",
            inputSchema = new
            {
                type = "object",
                properties = new { },
                additionalProperties = false,
            },
        };
    }

    private static object CreateGodotInstallationSetDefaultTool()
    {
        return new
        {
            name = "workspace_godot_set_default_executable",
            description = "Set the default Godot executable path used when a project-specific path is not configured.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    executablePath = new { type = "string", description = "Absolute path to the Godot executable." },
                },
                required = new[] { "executablePath" },
                additionalProperties = false,
            },
        };
    }

    private static object CreateGodotManagerListProjectsTool()
    {
        return new
        {
            name = "workspace_godot_manager_list_projects",
            description = "List Godot Project Manager projects as candidates without importing them into the central registry.",
            inputSchema = new
            {
                type = "object",
                properties = new { },
                additionalProperties = false,
            },
        };
    }

    private static object CreateGodotManagerGetStatusTool()
    {
        return new
        {
            name = "workspace_godot_manager_get_status",
            description = "Show Godot Project Manager config paths, scan status, and candidate count.",
            inputSchema = new
            {
                type = "object",
                properties = new { },
                additionalProperties = false,
            },
        };
    }

    private static object CreateGodotManagerImportProjectsTool()
    {
        return new
        {
            name = "workspace_godot_manager_import_projects",
            description = "Import selected Godot Project Manager candidates into the central registry.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    paths = new
                    {
                        type = "array",
                        items = new { type = "string" },
                        description = "Candidate project roots from workspace_godot_manager_list_projects.",
                    },
                },
                required = new[] { "paths" },
                additionalProperties = false,
            },
        };
    }
}
