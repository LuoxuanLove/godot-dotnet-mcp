namespace GodotDotnetMcp.CentralServer;

internal sealed class ProjectStatusSnapshot
{
    public bool Success { get; set; }

    public string ErrorType { get; set; } = string.Empty;

    public string Message { get; set; } = string.Empty;

    public object? RegistryStatus { get; set; }

    public object? Configuration { get; set; }

    public ProjectRegistryService.RegisteredProject? Project { get; set; }

    public EditorSessionService.EditorSessionStatus? Session { get; set; }

    public EditorProcessService.EditorProcessStatus? Process { get; set; }

    public EditorSessionService.EditorSessionStatus? ActiveEditorSession { get; set; }

    public Dictionary<string, object?>? EditorState { get; set; }

    public Dictionary<string, object?> EditorLifecycle { get; set; } = new(StringComparer.OrdinalIgnoreCase);

    public object ToPayload()
    {
        if (!Success)
        {
            return new
            {
                error = ErrorType,
                message = Message,
                status = RegistryStatus,
                configuration = Configuration,
                project = Project,
                editor = Process,
                editorSession = Session,
                activeEditorSession = ActiveEditorSession,
                activeEditorSessionId = ActiveEditorSession?.SessionId ?? string.Empty,
                editorState = EditorState,
                editorLifecycle = EditorLifecycle,
            };
        }

        return new
        {
            status = RegistryStatus,
            configuration = Configuration,
            project = Project,
            editor = Process,
            editorSession = Session,
            activeEditorSession = ActiveEditorSession,
            activeEditorSessionId = ActiveEditorSession?.SessionId ?? string.Empty,
            editorState = EditorState,
            editorLifecycle = EditorLifecycle,
        };
    }
}

internal sealed class LifecycleActionResult
{
    public bool Success { get; set; }

    public string ErrorType { get; set; } = string.Empty;

    public string Message { get; set; } = string.Empty;

    public string Action { get; set; } = string.Empty;

    public ProjectRegistryService.RegisteredProject? Project { get; set; }

    public EditorSessionService.EditorSessionStatus? Session { get; set; }

    public EditorSessionService.EditorSessionStatus? PreviousSession { get; set; }

    public EditorProcessService.EditorProcessStatus? Process { get; set; }

    public Dictionary<string, object?>? EditorState { get; set; }

    public Dictionary<string, object?> EditorLifecycle { get; set; } = new(StringComparer.OrdinalIgnoreCase);

    public bool SaveRequested { get; set; }

    public bool ForceRequested { get; set; }

    public bool GracefulAttempted { get; set; }

    public bool ForceAttempted { get; set; }

    public EditorProcessService.EditorLaunchResult? Launch { get; set; }

    public object ToPayload()
    {
        return new
        {
            success = Success,
            error = Success ? string.Empty : ErrorType,
            message = Message,
            action = Action,
            project = Project,
            editorSession = Session,
            previousEditorSession = PreviousSession,
            editor = Process,
            editorState = EditorState,
            editorLifecycle = EditorLifecycle,
            saveRequested = SaveRequested,
            forceRequested = ForceRequested,
            gracefulAttempted = GracefulAttempted,
            forceAttempted = ForceAttempted,
            launch = Launch,
            activeProjectId = Project?.ProjectId ?? string.Empty,
            activeEditorSessionId = Session?.SessionId ?? string.Empty,
        };
    }
}

internal sealed class LifecycleActionContext
{
    public string ToolName { get; init; } = string.Empty;

    public string Action { get; init; } = string.Empty;

    public ProjectRegistryService.RegisteredProject Project { get; init; } = null!;

    public EditorSessionService.EditorSessionStatus Session { get; init; } = null!;

    public EditorProcessService.EditorProcessStatus Process { get; init; } = null!;

    public Dictionary<string, object?>? EditorState { get; init; }

    public bool SaveRequested { get; init; }

    public bool ForceRequested { get; init; }
}
