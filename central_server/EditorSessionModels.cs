namespace GodotDotnetMcp.CentralServer;

internal sealed class EnsureEditorSessionResult
{
    public bool Success { get; private set; }

    public string ErrorType { get; private set; } = string.Empty;

    public string Message { get; private set; } = string.Empty;

    public string ActiveProjectId { get; private set; } = string.Empty;

    public ProjectRegistryService.RegisteredProject? Project { get; private set; }

    public EditorSessionService.EditorSessionStatus? Session { get; private set; }

    public EditorProcessService.EditorLaunchResult? Launch { get; private set; }

    public EditorProcessService.EditorProcessStatus? Editor { get; private set; }

    public int AttachTimeoutMs { get; private set; }

    public bool AutoLaunchAttempted { get; private set; }

    public bool ReusedRunningEditor { get; private set; }

    public string ToolName { get; private set; } = string.Empty;

    public string RequestedExecutablePath { get; private set; } = string.Empty;

    public string ResolvedExecutablePath { get; private set; } = string.Empty;

    public string ResolvedExecutableSource { get; private set; } = string.Empty;

    public static EnsureEditorSessionResult FromReady(
        ProjectRegistryService.RegisteredProject project,
        EditorSessionService.EditorSessionStatus session,
        EditorProcessService.EditorLaunchResult? launch,
        bool autoLaunchAttempted,
        bool reusedRunningEditor,
        int attachTimeoutMs,
        string requestedExecutablePath = "",
        string resolvedExecutablePath = "",
        string resolvedExecutableSource = "")
    {
        return new EnsureEditorSessionResult
        {
            Success = true,
            ActiveProjectId = project.ProjectId,
            Project = project,
            Session = session,
            Launch = launch,
            Editor = null,
            AttachTimeoutMs = attachTimeoutMs,
            AutoLaunchAttempted = autoLaunchAttempted,
            ReusedRunningEditor = reusedRunningEditor,
            RequestedExecutablePath = requestedExecutablePath ?? string.Empty,
            ResolvedExecutablePath = resolvedExecutablePath ?? string.Empty,
            ResolvedExecutableSource = resolvedExecutableSource ?? string.Empty,
        };
    }

    public static EnsureEditorSessionResult FromFailure(
        string errorType,
        string message,
        string activeProjectId,
        ProjectRegistryService.RegisteredProject? project = null,
        EditorSessionService.EditorSessionStatus? session = null,
        EditorProcessService.EditorLaunchResult? launch = null,
        EditorProcessService.EditorProcessStatus? editor = null,
        int attachTimeoutMs = EditorSessionCoordinator.DefaultAttachTimeoutMs,
        bool autoLaunchAttempted = false,
        bool reusedRunningEditor = false,
        string toolName = "",
        string requestedExecutablePath = "",
        string resolvedExecutablePath = "",
        string resolvedExecutableSource = "")
    {
        return new EnsureEditorSessionResult
        {
            Success = false,
            ErrorType = errorType,
            Message = message,
            ActiveProjectId = activeProjectId,
            Project = project,
            Session = session,
            Launch = launch,
            Editor = editor,
            AttachTimeoutMs = attachTimeoutMs,
            AutoLaunchAttempted = autoLaunchAttempted,
            ReusedRunningEditor = reusedRunningEditor,
            ToolName = toolName,
            RequestedExecutablePath = requestedExecutablePath ?? string.Empty,
            ResolvedExecutablePath = resolvedExecutablePath ?? string.Empty,
            ResolvedExecutableSource = resolvedExecutableSource ?? string.Empty,
        };
    }

    public object ToErrorPayload()
    {
        var guidance = BuildErrorGuidance();
        return new
        {
            error = ErrorType,
            message = Message,
            toolName = ToolName,
            activeProjectId = ActiveProjectId,
            attachTimeoutMs = AttachTimeoutMs,
            autoLaunchAttempted = AutoLaunchAttempted,
            reusedRunningEditor = ReusedRunningEditor,
            project = Project,
            editorSession = Session,
            editor = Editor,
            launch = Launch,
            requestedExecutablePath = RequestedExecutablePath,
            resolvedExecutablePath = ResolvedExecutablePath,
            resolvedExecutableSource = ResolvedExecutableSource,
            guidance,
        };
    }

    private object? BuildErrorGuidance()
    {
        return ErrorType switch
        {
            "godot_executable_not_found" => GodotInstallationService.BuildMissingExecutableGuidance(Project?.ProjectId),
            "project_not_selected" => new
            {
                configureWith = new[]
                {
                    "workspace_project_register",
                    "workspace_project_select",
                },
                suggestedUserPrompt = "Please tell me which Godot project you want to work with so I can register or select it first.",
            },
            "editor_transport_unavailable" => new
            {
                requiredTransport = "http",
                suggestedUserPrompt = "Please restart the editor with the current plugin version so it exposes the HTTP MCP endpoint, then I can retry the tool.",
                retryWith = new object[]
                {
                    new
                    {
                        tool = "workspace_project_status",
                        useWhen = "Inspect the current attach and transport status before retrying.",
                    },
                    new
                    {
                        tool = ToolName,
                        useWhen = "Retry the same request after the editor session exposes an HTTP endpoint.",
                        attachTimeoutMs = Math.Min(AttachTimeoutMs * 2, EditorSessionCoordinator.MaxAttachTimeoutMs),
                    },
                },
            },
            "editor_attach_timeout" => new
            {
                requiredTransport = "http",
                suggestedUserPrompt = "Please confirm the Godot editor finished opening and the plugin is enabled, then I can retry attaching.",
                retryWith = new object[]
                {
                    new
                    {
                        tool = "workspace_project_status",
                        useWhen = "Inspect whether the editor attached but is still not HTTP-ready.",
                    },
                    new
                    {
                        tool = ToolName,
                        useWhen = "Retry the same request with a longer attach timeout.",
                        attachTimeoutMs = Math.Min(AttachTimeoutMs * 2, EditorSessionCoordinator.MaxAttachTimeoutMs),
                    },
                },
            },
            "editor_already_running_external" => new
            {
                duplicateEditorPrevented = true,
                suggestedUserPrompt = "A Godot editor for this project is already open outside the current host session. Please close that editor or reconnect it to the current host before retrying.",
                retryWith = new object[]
                {
                    new
                    {
                        tool = "workspace_project_status",
                        useWhen = "Inspect whether the already-open editor has attached to the current host.",
                    },
                    new
                    {
                        tool = ToolName,
                        useWhen = "Retry after the existing editor is closed or successfully attached to the current host.",
                        attachTimeoutMs = Math.Min(AttachTimeoutMs * 2, EditorSessionCoordinator.MaxAttachTimeoutMs),
                    },
                },
            },
            "editor_launch_failed" => new
            {
                suggestedUserPrompt = "Please verify the Godot executable path and editor startup prerequisites, then I can retry opening the project.",
                configureWith = new object[]
                {
                    new
                    {
                        tool = "workspace_project_set_godot_path",
                        useWhen = "Replace the current project-specific executable path.",
                        projectId = Project?.ProjectId ?? string.Empty,
                    },
                    new
                    {
                        tool = "workspace_godot_set_default_executable",
                        useWhen = "Replace the current user default executable path.",
                        projectId = string.Empty,
                    },
                },
                retryWith = new object[]
                {
                    new
                    {
                        tool = ToolName,
                        useWhen = "Retry the same request after fixing the executable path or startup prerequisites.",
                        attachTimeoutMs = Math.Min(AttachTimeoutMs * 2, EditorSessionCoordinator.MaxAttachTimeoutMs),
                    },
                },
            },
            _ => null,
        };
    }
}
