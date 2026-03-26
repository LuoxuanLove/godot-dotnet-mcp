namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorLifecycleActionService
{
    private const int DefaultShutdownTimeoutMs = 30_000;
    private const int MinShutdownTimeoutMs = 1_000;
    private const int MaxShutdownTimeoutMs = 180_000;

    private readonly EditorSessionService _editorSessions;
    private readonly EditorLifecycleStatusService _statusService;
    private readonly CentralWorkspaceState _workspaceState;
    private readonly EditorLifecycleActionResultFactory _resultFactory;
    private readonly EditorLifecycleGracefulActionExecutor _gracefulExecutor;
    private readonly EditorLifecycleForceActionExecutor _forceExecutor;

    public EditorLifecycleActionService(
        EditorProcessService editorProcesses,
        EditorProxyService editorProxy,
        EditorSessionCoordinator editorSessionCoordinator,
        EditorSessionService editorSessions,
        EditorLifecycleStatusService statusService,
        CentralWorkspaceState workspaceState)
    {
        _editorSessions = editorSessions;
        _statusService = statusService;
        _workspaceState = workspaceState;
        _resultFactory = new EditorLifecycleActionResultFactory(statusService);
        _gracefulExecutor = new EditorLifecycleGracefulActionExecutor(
            editorProcesses,
            editorProxy,
            editorSessions,
            statusService,
            workspaceState,
            _resultFactory);
        _forceExecutor = new EditorLifecycleForceActionExecutor(
            editorProcesses,
            editorSessionCoordinator,
            editorSessions,
            statusService,
            workspaceState,
            _resultFactory);
    }

    public Task<LifecycleActionResult> CloseEditorAsync(
        string? projectId,
        string? projectPath,
        bool save,
        bool force,
        int? shutdownTimeoutMs,
        CancellationToken cancellationToken)
    {
        return ExecuteLifecycleActionAsync(
            "workspace_project_close_editor",
            "close",
            projectId,
            projectPath,
            save,
            force,
            shutdownTimeoutMs,
            attachTimeoutMs: null,
            cancellationToken);
    }

    public Task<LifecycleActionResult> RestartEditorAsync(
        string? projectId,
        string? projectPath,
        bool save,
        bool force,
        int? shutdownTimeoutMs,
        int? attachTimeoutMs,
        CancellationToken cancellationToken)
    {
        return ExecuteLifecycleActionAsync(
            "workspace_project_restart_editor",
            "restart",
            projectId,
            projectPath,
            save,
            force,
            shutdownTimeoutMs,
            attachTimeoutMs,
            cancellationToken);
    }

    private async Task<LifecycleActionResult> ExecuteLifecycleActionAsync(
        string toolName,
        string action,
        string? projectId,
        string? projectPath,
        bool save,
        bool force,
        int? shutdownTimeoutMs,
        int? attachTimeoutMs,
        CancellationToken cancellationToken)
    {
        var project = _statusService.ResolveProject(projectId, projectPath);
        if (project is null)
        {
            return _resultFactory.BuildProjectNotFoundError(toolName, action, save, force);
        }

        _workspaceState.SetActiveProject(project.ProjectId);

        var session = _editorSessions.GetStatus(project.ProjectId);
        var process = _statusService.GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, session);
        var editorState = await _statusService.TryGetRemoteStatusAsync(session, cancellationToken);
        var timeout = TimeSpan.FromMilliseconds(NormalizeShutdownTimeout(shutdownTimeoutMs));
        var effectiveAttachTimeoutMs = attachTimeoutMs ?? EditorSessionCoordinator.DefaultAttachTimeoutMs;
        var context = new LifecycleActionContext
        {
            ToolName = toolName,
            Action = action,
            Project = project,
            Session = session,
            Process = process,
            EditorState = editorState,
            SaveRequested = save,
            ForceRequested = force,
        };

        var validationError = ValidateRequest(context);
        if (validationError is not null)
        {
            return validationError;
        }

        if (save)
        {
            var gracefulResult = action == "restart"
                ? await _gracefulExecutor.ExecuteRestartAsync(
                    context,
                    timeout,
                    effectiveAttachTimeoutMs,
                    cancellationToken)
                : await _gracefulExecutor.ExecuteCloseAsync(
                    context,
                    timeout,
                    cancellationToken);

            if (gracefulResult.Success || !force)
            {
                return gracefulResult;
            }
        }

        if (!CanForceLifecycle(process))
        {
            return _resultFactory.BuildError(
                context,
                "editor_force_unavailable",
                "Force lifecycle actions are only available for host-managed resident editors.");
        }

        return action == "restart"
            ? await _forceExecutor.ExecuteRestartAsync(
                context,
                timeout,
                effectiveAttachTimeoutMs,
                cancellationToken)
            : await _forceExecutor.ExecuteCloseAsync(
                context,
                timeout,
                cancellationToken);
    }

    private LifecycleActionResult? ValidateRequest(LifecycleActionContext context)
    {
        if (!context.SaveRequested && !context.ForceRequested)
        {
            return _resultFactory.BuildError(
                context,
                "editor_confirmation_required",
                "Explicit confirmation is required. Pass save=true for graceful lifecycle actions or force=true for host-managed fallback.");
        }

        if (!context.Session.Attached && !context.Process.Running)
        {
            return _resultFactory.BuildError(
                context,
                "editor_process_not_found",
                "No resident editor is available for this project.");
        }

        if (!context.SaveRequested)
        {
            return null;
        }

        if (!EditorSessionService.IsHttpReady(context.Session))
        {
            return context.ForceRequested
                ? null
                : _resultFactory.BuildError(
                    context,
                    "editor_session_required_for_graceful_lifecycle",
                    "Graceful editor lifecycle actions require an attached HTTP-ready editor session.");
        }

        if (EditorSessionService.SupportsEditorLifecycle(context.Session))
        {
            return null;
        }

        return context.ForceRequested
            ? null
            : _resultFactory.BuildError(
                context,
                "editor_lifecycle_unsupported",
                "Attached editor session does not advertise internal editor lifecycle support.",
                editorState: context.EditorState ?? EditorLifecycleStatusService.BuildUnsupportedEditorLifecycleState(context.Session));
    }

    private static bool CanForceLifecycle(EditorProcessService.EditorProcessStatus process)
    {
        return process.Running
               && string.Equals(process.Ownership, "host_managed", StringComparison.OrdinalIgnoreCase);
    }

    private static int NormalizeShutdownTimeout(int? shutdownTimeoutMs)
    {
        if (!shutdownTimeoutMs.HasValue || shutdownTimeoutMs.Value <= 0)
        {
            return DefaultShutdownTimeoutMs;
        }

        return Math.Clamp(shutdownTimeoutMs.Value, MinShutdownTimeoutMs, MaxShutdownTimeoutMs);
    }
}
