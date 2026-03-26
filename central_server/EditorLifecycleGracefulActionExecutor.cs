namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorLifecycleGracefulActionExecutor
{
    private readonly EditorProcessService _editorProcesses;
    private readonly EditorProxyService _editorProxy;
    private readonly EditorSessionService _editorSessions;
    private readonly EditorLifecycleStatusService _statusService;
    private readonly CentralWorkspaceState _workspaceState;
    private readonly EditorLifecycleActionResultFactory _resultFactory;

    public EditorLifecycleGracefulActionExecutor(
        EditorProcessService editorProcesses,
        EditorProxyService editorProxy,
        EditorSessionService editorSessions,
        EditorLifecycleStatusService statusService,
        CentralWorkspaceState workspaceState,
        EditorLifecycleActionResultFactory resultFactory)
    {
        _editorProcesses = editorProcesses;
        _editorProxy = editorProxy;
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
        var actionResponse = await _editorProxy.ExecuteEditorLifecycleActionAsync(
            context.Session,
            "close",
            new Dictionary<string, object?>
            {
                ["save"] = true,
                ["force"] = false,
            },
            cancellationToken);

        if (!actionResponse.Success)
        {
            return _resultFactory.BuildError(
                context,
                actionResponse.ErrorType,
                actionResponse.Message,
                gracefulAttempted: true);
        }

        var finalSession = await _editorSessions.WaitForSessionLossAsync(
            context.Project.ProjectId,
            context.Session.SessionId,
            timeout,
            cancellationToken);
        if (finalSession.Attached)
        {
            return _resultFactory.BuildError(
                context,
                "editor_close_timeout",
                $"Timed out waiting for the editor session to close after {timeout.TotalMilliseconds:F0} ms.",
                session: finalSession,
                process: _statusService.GetEffectiveProcessStatus(context.Project.ProjectId, context.Project.ProjectRoot, finalSession),
                gracefulAttempted: true);
        }

        var finalProcess = context.Process.Running
            ? await _editorProcesses.WaitForExitAsync(context.Project.ProjectId, context.Project.ProjectRoot, timeout, cancellationToken)
            : _statusService.GetEffectiveProcessStatus(context.Project.ProjectId, context.Project.ProjectRoot, finalSession);

        if (finalProcess.Running)
        {
            return _resultFactory.BuildError(
                context,
                "editor_close_timeout",
                $"Timed out waiting for the resident editor process to exit after {timeout.TotalMilliseconds:F0} ms.",
                session: finalSession,
                process: finalProcess,
                gracefulAttempted: true);
        }

        _workspaceState.ClearActiveEditorSession();
        return _resultFactory.BuildSuccess(
            context,
            "Editor closed successfully.",
            finalSession,
            finalProcess,
            context.EditorState,
            gracefulAttempted: true);
    }

    public async Task<LifecycleActionResult> ExecuteRestartAsync(
        LifecycleActionContext context,
        TimeSpan shutdownTimeout,
        int attachTimeoutMs,
        CancellationToken cancellationToken)
    {
        var actionResponse = await _editorProxy.ExecuteEditorLifecycleActionAsync(
            context.Session,
            "restart",
            new Dictionary<string, object?>
            {
                ["save"] = true,
                ["force"] = false,
            },
            cancellationToken);

        if (!actionResponse.Success)
        {
            return _resultFactory.BuildError(
                context,
                actionResponse.ErrorType,
                actionResponse.Message,
                gracefulAttempted: true);
        }

        var attachTimeout = TimeSpan.FromMilliseconds(EditorSessionCoordinator.NormalizeAttachTimeout(attachTimeoutMs));
        var restartedSession = await _editorSessions.WaitForDifferentReadyHttpSessionAsync(
            context.Project.ProjectId,
            context.Session.SessionId,
            attachTimeout,
            cancellationToken);

        if (!EditorSessionService.IsHttpReady(restartedSession)
            || string.Equals(restartedSession.SessionId, context.Session.SessionId, StringComparison.OrdinalIgnoreCase))
        {
            var finalProcess = context.Process.Running
                ? await _editorProcesses.WaitForExitAsync(context.Project.ProjectId, context.Project.ProjectRoot, shutdownTimeout, cancellationToken)
                : _statusService.GetEffectiveProcessStatus(context.Project.ProjectId, context.Project.ProjectRoot, restartedSession);
            return _resultFactory.BuildError(
                context,
                "editor_restart_attach_timeout",
                $"Timed out waiting for the restarted editor to reattach after {attachTimeout.TotalMilliseconds:F0} ms.",
                session: restartedSession,
                process: finalProcess,
                gracefulAttempted: true);
        }

        var finalProcessStatus = _statusService.GetEffectiveProcessStatus(
            context.Project.ProjectId,
            context.Project.ProjectRoot,
            restartedSession);
        _workspaceState.SetActiveEditorSession(restartedSession.SessionId);
        return _resultFactory.BuildSuccess(
            context,
            "Editor restarted and reattached successfully.",
            restartedSession,
            finalProcessStatus,
            await _statusService.TryGetRemoteStatusAsync(restartedSession, cancellationToken),
            gracefulAttempted: true,
            previousSession: context.Session);
    }
}
