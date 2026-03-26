namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorLifecycleActionResultFactory
{
    private readonly EditorLifecycleStatusService _statusService;

    public EditorLifecycleActionResultFactory(EditorLifecycleStatusService statusService)
    {
        _statusService = statusService;
    }

    public LifecycleActionResult BuildSuccess(
        LifecycleActionContext context,
        string message,
        EditorSessionService.EditorSessionStatus? session,
        EditorProcessService.EditorProcessStatus? process,
        Dictionary<string, object?>? editorState,
        bool gracefulAttempted = false,
        bool forceAttempted = false,
        EditorProcessService.EditorLaunchResult? launch = null,
        EditorSessionService.EditorSessionStatus? previousSession = null)
    {
        return new LifecycleActionResult
        {
            Success = true,
            Action = context.Action,
            Message = message,
            Project = context.Project,
            Session = session,
            PreviousSession = previousSession,
            Process = process,
            EditorState = editorState,
            EditorLifecycle = _statusService.BuildLifecycleSummary(
                context.ToolName,
                context.Project,
                session,
                process,
                ResolveStatusResolution(session, process),
                editorState),
            SaveRequested = context.SaveRequested,
            ForceRequested = context.ForceRequested,
            GracefulAttempted = gracefulAttempted,
            ForceAttempted = forceAttempted,
            Launch = launch,
        };
    }

    public LifecycleActionResult BuildError(
        LifecycleActionContext? context,
        string action,
        string errorType,
        string message,
        ProjectRegistryService.RegisteredProject? project,
        EditorSessionService.EditorSessionStatus? session,
        EditorProcessService.EditorProcessStatus? process,
        Dictionary<string, object?>? editorState,
        bool saveRequested,
        bool forceRequested,
        bool gracefulAttempted = false,
        bool forceAttempted = false,
        EditorProcessService.EditorLaunchResult? launch = null,
        string? toolNameOverride = null)
    {
        var toolName = toolNameOverride ?? context?.ToolName ?? string.Empty;
        return new LifecycleActionResult
        {
            Success = false,
            Action = action,
            ErrorType = errorType,
            Message = message,
            Project = project,
            Session = session,
            Process = process,
            EditorState = editorState,
            EditorLifecycle = _statusService.BuildLifecycleSummary(
                toolName,
                project,
                session,
                process,
                ResolveStatusResolution(session, process),
                editorState),
            SaveRequested = saveRequested,
            ForceRequested = forceRequested,
            GracefulAttempted = gracefulAttempted,
            ForceAttempted = forceAttempted,
            Launch = launch,
        };
    }

    public LifecycleActionResult BuildError(
        LifecycleActionContext context,
        string errorType,
        string message,
        EditorSessionService.EditorSessionStatus? session = null,
        EditorProcessService.EditorProcessStatus? process = null,
        Dictionary<string, object?>? editorState = null,
        bool gracefulAttempted = false,
        bool forceAttempted = false,
        EditorProcessService.EditorLaunchResult? launch = null)
    {
        return BuildError(
            context,
            context.Action,
            errorType,
            message,
            context.Project,
            session ?? context.Session,
            process ?? context.Process,
            editorState ?? context.EditorState,
            context.SaveRequested,
            context.ForceRequested,
            gracefulAttempted,
            forceAttempted,
            launch,
            toolNameOverride: context.ToolName);
    }

    public LifecycleActionResult BuildProjectNotFoundError(
        string toolName,
        string action,
        bool saveRequested,
        bool forceRequested)
    {
        return BuildError(
            context: null,
            action,
            "project_not_registered",
            "Registered project not found or no active project is selected.",
            project: null,
            session: null,
            process: null,
            editorState: null,
            saveRequested,
            forceRequested,
            toolNameOverride: toolName);
    }

    private static string ResolveStatusResolution(
        EditorSessionService.EditorSessionStatus? session,
        EditorProcessService.EditorProcessStatus? process)
    {
        var attached = session?.Attached ?? false;
        var httpReady = session is not null && EditorSessionService.IsHttpReady(session);
        var running = process?.Running ?? false;
        if (httpReady && running)
        {
            return "resident_ready_session";
        }

        if (httpReady)
        {
            return "attached_ready_session";
        }

        if (attached)
        {
            return "attached_without_http";
        }

        if (running)
        {
            return "resident_waiting_attach";
        }

        return "editor_unavailable";
    }
}
