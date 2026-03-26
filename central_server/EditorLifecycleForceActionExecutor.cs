namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorLifecycleForceActionExecutor
{
    private readonly EditorProcessService _editorProcesses;
    private readonly EditorSessionCoordinator _editorSessionCoordinator;
    private readonly EditorSessionService _editorSessions;
    private readonly EditorLifecycleStatusService _statusService;
    private readonly CentralWorkspaceState _workspaceState;
    private readonly EditorLifecycleActionResultFactory _resultFactory;

    public EditorLifecycleForceActionExecutor(
        EditorProcessService editorProcesses,
        EditorSessionCoordinator editorSessionCoordinator,
        EditorSessionService editorSessions,
        EditorLifecycleStatusService statusService,
        CentralWorkspaceState workspaceState,
        EditorLifecycleActionResultFactory resultFactory)
    {
        _editorProcesses = editorProcesses;
        _editorSessionCoordinator = editorSessionCoordinator;
        _editorSessions = editorSessions;
        _statusService = statusService;
        _workspaceState = workspaceState;
        _resultFactory = resultFactory;
    }

    public async Task<LifecycleActionResult> ExecuteCloseAsync(
        LifecycleActionContext context,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var stopResult = await _editorProcesses.ForceStopTrackedProcessAsync(
            context.Project.ProjectId,
            context.Project.ProjectRoot,
            timeout,
            cancellationToken);
        if (!stopResult.Success)
        {
            return _resultFactory.BuildError(
                context,
                stopResult.ErrorType,
                stopResult.Message,
                process: stopResult.Process,
                forceAttempted: true);
        }

        _editorSessions.InvalidateSession(context.Project.ProjectId, context.Session.SessionId);
        _workspaceState.ClearActiveEditorSession();
        return _resultFactory.BuildSuccess(
            context,
            "Editor closed successfully.",
            _editorSessions.GetStatus(context.Project.ProjectId),
            _editorProcesses.GetStatus(context.Project.ProjectId, context.Project.ProjectRoot),
            context.EditorState,
            forceAttempted: true);
    }

    public async Task<LifecycleActionResult> ExecuteRestartAsync(
        LifecycleActionContext context,
        TimeSpan shutdownTimeout,
        int attachTimeoutMs,
        CancellationToken cancellationToken)
    {
        var stopResult = await _editorProcesses.ForceStopTrackedProcessAsync(
            context.Project.ProjectId,
            context.Project.ProjectRoot,
            shutdownTimeout,
            cancellationToken);
        if (!stopResult.Success)
        {
            return _resultFactory.BuildError(
                context,
                stopResult.ErrorType,
                stopResult.Message,
                process: stopResult.Process,
                forceAttempted: true);
        }

        _editorSessions.InvalidateSession(context.Project.ProjectId, context.Session.SessionId);
        _workspaceState.ClearActiveEditorSession();

        var executableResolution = ResolveRelaunchExecutable(context.Project, context.Process);

        EditorProcessService.EditorLaunchResult launch;
        try
        {
            launch = _editorProcesses.OpenProject(
                context.Project,
                executableResolution.ExecutablePath,
                executableResolution.Source,
                "workspace_restart_editor",
                _editorSessionCoordinator.AttachEndpoint);
        }
        catch (Exception ex)
        {
            return _resultFactory.BuildError(
                context,
                "editor_launch_failed",
                $"Failed to relaunch Godot editor: {ex.Message}",
                session: null,
                process: _editorProcesses.GetStatus(context.Project.ProjectId, context.Project.ProjectRoot),
                forceAttempted: true);
        }

        var restartedSession = await _editorSessions.WaitForReadyHttpSessionAsync(
            context.Project.ProjectId,
            TimeSpan.FromMilliseconds(EditorSessionCoordinator.NormalizeAttachTimeout(attachTimeoutMs)),
            cancellationToken);

        if (!EditorSessionService.IsHttpReady(restartedSession))
        {
            return _resultFactory.BuildError(
                context,
                "editor_restart_attach_timeout",
                $"Timed out waiting for the restarted editor to attach after {attachTimeoutMs} ms.",
                session: restartedSession,
                process: _editorProcesses.GetStatus(context.Project.ProjectId, context.Project.ProjectRoot),
                forceAttempted: true,
                launch: launch);
        }

        var finalProcess = _statusService.GetEffectiveProcessStatus(
            context.Project.ProjectId,
            context.Project.ProjectRoot,
            restartedSession);
        _workspaceState.SetActiveEditorSession(restartedSession.SessionId);
        return _resultFactory.BuildSuccess(
            context,
            "Editor restarted and reattached successfully.",
            restartedSession,
            finalProcess,
            await _statusService.TryGetRemoteStatusAsync(restartedSession, cancellationToken),
            forceAttempted: true,
            launch: launch,
            previousSession: context.Session);
    }

    private GodotInstallationService.GodotExecutableResolution ResolveRelaunchExecutable(
        ProjectRegistryService.RegisteredProject project,
        EditorProcessService.EditorProcessStatus process)
    {
        if (!string.IsNullOrWhiteSpace(process.ExecutablePath))
        {
            return new GodotInstallationService.GodotExecutableResolution
            {
                ExecutablePath = process.ExecutablePath,
                Source = string.IsNullOrWhiteSpace(process.ExecutableSource) ? "editor_residency" : process.ExecutableSource,
            };
        }

        return _editorSessionCoordinator.ResolveExecutable(project, string.Empty);
    }
}
