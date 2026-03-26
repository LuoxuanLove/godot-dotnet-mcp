namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorLifecycleActionService
{
    private const int DefaultShutdownTimeoutMs = 30_000;
    private const int MinShutdownTimeoutMs = 1_000;
    private const int MaxShutdownTimeoutMs = 180_000;

    private readonly EditorProcessService _editorProcesses;
    private readonly EditorProxyService _editorProxy;
    private readonly EditorSessionCoordinator _editorSessionCoordinator;
    private readonly EditorSessionService _editorSessions;
    private readonly EditorLifecycleStatusService _statusService;
    private readonly CentralWorkspaceState _workspaceState;

    public EditorLifecycleActionService(
        EditorProcessService editorProcesses,
        EditorProxyService editorProxy,
        EditorSessionCoordinator editorSessionCoordinator,
        EditorSessionService editorSessions,
        EditorLifecycleStatusService statusService,
        CentralWorkspaceState workspaceState)
    {
        _editorProcesses = editorProcesses;
        _editorProxy = editorProxy;
        _editorSessionCoordinator = editorSessionCoordinator;
        _editorSessions = editorSessions;
        _statusService = statusService;
        _workspaceState = workspaceState;
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
            return BuildActionError(
                toolName,
                action,
                "project_not_registered",
                "Registered project not found or no active project is selected.",
                null,
                null,
                null,
                null,
                save,
                force);
        }

        _workspaceState.SetActiveProject(project.ProjectId);

        var session = _editorSessions.GetStatus(project.ProjectId);
        var process = _statusService.GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, session);
        var editorState = await _statusService.TryGetRemoteStatusAsync(session, cancellationToken);
        var timeout = TimeSpan.FromMilliseconds(NormalizeShutdownTimeout(shutdownTimeoutMs));
        var effectiveAttachTimeoutMs = attachTimeoutMs ?? EditorSessionCoordinator.DefaultAttachTimeoutMs;

        if (!save && !force)
        {
            return BuildActionError(
                toolName,
                action,
                "editor_confirmation_required",
                "Explicit confirmation is required. Pass save=true for graceful lifecycle actions or force=true for host-managed fallback.",
                project,
                session,
                process,
                editorState,
                save,
                force);
        }

        if (!session.Attached && !process.Running)
        {
            return BuildActionError(
                toolName,
                action,
                "editor_process_not_found",
                "No resident editor is available for this project.",
                project,
                session,
                process,
                editorState,
                save,
                force);
        }

        if (save)
        {
            if (!EditorSessionService.IsHttpReady(session))
            {
                if (!force)
                {
                    return BuildActionError(
                        toolName,
                        action,
                        "editor_session_required_for_graceful_lifecycle",
                        "Graceful editor lifecycle actions require an attached HTTP-ready editor session.",
                        project,
                        session,
                        process,
                        editorState,
                        save,
                        force);
                }
            }
            else if (!EditorSessionService.SupportsEditorLifecycle(session))
            {
                if (!force)
                {
                    return BuildActionError(
                        toolName,
                        action,
                        "editor_lifecycle_unsupported",
                        "Attached editor session does not advertise internal editor lifecycle support.",
                        project,
                        session,
                        process,
                        editorState ?? EditorLifecycleStatusService.BuildUnsupportedEditorLifecycleState(session),
                        save,
                        force);
                }
            }
            else
            {
                var gracefulResult = action == "restart"
                    ? await ExecuteGracefulRestartAsync(
                        toolName,
                        project,
                        session,
                        process,
                        editorState,
                        save,
                        force,
                        timeout,
                        effectiveAttachTimeoutMs,
                        cancellationToken)
                    : await ExecuteGracefulCloseAsync(
                        toolName,
                        project,
                        session,
                        process,
                        editorState,
                        save,
                        force,
                        timeout,
                        cancellationToken);

                if (gracefulResult.Success || !force)
                {
                    return gracefulResult;
                }
            }
        }

        if (!CanForceLifecycle(process))
        {
            return BuildActionError(
                toolName,
                action,
                "editor_force_unavailable",
                "Force lifecycle actions are only available for host-managed resident editors.",
                project,
                session,
                process,
                editorState,
                save,
                force);
        }

        return action == "restart"
            ? await ExecuteForceRestartAsync(
                toolName,
                project,
                session,
                process,
                editorState,
                save,
                force,
                timeout,
                effectiveAttachTimeoutMs,
                cancellationToken)
            : await ExecuteForceCloseAsync(
                toolName,
                project,
                session,
                process,
                editorState,
                save,
                force,
                timeout,
                cancellationToken);
    }

    private async Task<LifecycleActionResult> ExecuteGracefulCloseAsync(
        string toolName,
        ProjectRegistryService.RegisteredProject project,
        EditorSessionService.EditorSessionStatus session,
        EditorProcessService.EditorProcessStatus process,
        Dictionary<string, object?>? editorState,
        bool save,
        bool force,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var actionResponse = await _editorProxy.ExecuteEditorLifecycleActionAsync(
            session,
            "close",
            new Dictionary<string, object?>
            {
                ["save"] = true,
                ["force"] = false,
            },
            cancellationToken);

        if (!actionResponse.Success)
        {
            return BuildActionError(
                toolName,
                "close",
                actionResponse.ErrorType,
                actionResponse.Message,
                project,
                session,
                process,
                editorState,
                save,
                force,
                gracefulAttempted: true);
        }

        var finalSession = await _editorSessions.WaitForSessionLossAsync(project.ProjectId, session.SessionId, timeout, cancellationToken);
        if (finalSession.Attached)
        {
            return BuildActionError(
                toolName,
                "close",
                "editor_close_timeout",
                $"Timed out waiting for the editor session to close after {timeout.TotalMilliseconds:F0} ms.",
                project,
                finalSession,
                _statusService.GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, finalSession),
                editorState,
                save,
                force,
                gracefulAttempted: true);
        }

        var finalProcess = process.Running
            ? await _editorProcesses.WaitForExitAsync(project.ProjectId, project.ProjectRoot, timeout, cancellationToken)
            : _statusService.GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, finalSession);

        if (finalProcess.Running)
        {
            return BuildActionError(
                toolName,
                "close",
                "editor_close_timeout",
                $"Timed out waiting for the resident editor process to exit after {timeout.TotalMilliseconds:F0} ms.",
                project,
                finalSession,
                finalProcess,
                editorState,
                save,
                force,
                gracefulAttempted: true);
        }

        _workspaceState.ClearActiveEditorSession();
        return BuildActionSuccess(
            toolName,
            "close",
            "Editor closed successfully.",
            project,
            finalSession,
            finalProcess,
            editorState,
            save,
            force,
            gracefulAttempted: true);
    }

    private async Task<LifecycleActionResult> ExecuteGracefulRestartAsync(
        string toolName,
        ProjectRegistryService.RegisteredProject project,
        EditorSessionService.EditorSessionStatus session,
        EditorProcessService.EditorProcessStatus process,
        Dictionary<string, object?>? editorState,
        bool save,
        bool force,
        TimeSpan shutdownTimeout,
        int attachTimeoutMs,
        CancellationToken cancellationToken)
    {
        var actionResponse = await _editorProxy.ExecuteEditorLifecycleActionAsync(
            session,
            "restart",
            new Dictionary<string, object?>
            {
                ["save"] = true,
                ["force"] = false,
            },
            cancellationToken);

        if (!actionResponse.Success)
        {
            return BuildActionError(
                toolName,
                "restart",
                actionResponse.ErrorType,
                actionResponse.Message,
                project,
                session,
                process,
                editorState,
                save,
                force,
                gracefulAttempted: true);
        }

        var attachTimeout = TimeSpan.FromMilliseconds(EditorSessionCoordinator.NormalizeAttachTimeout(attachTimeoutMs));
        var restartedSession = await _editorSessions.WaitForDifferentReadyHttpSessionAsync(
            project.ProjectId,
            session.SessionId,
            attachTimeout,
            cancellationToken);

        if (!EditorSessionService.IsHttpReady(restartedSession)
            || string.Equals(restartedSession.SessionId, session.SessionId, StringComparison.OrdinalIgnoreCase))
        {
            var finalProcess = process.Running
                ? await _editorProcesses.WaitForExitAsync(project.ProjectId, project.ProjectRoot, shutdownTimeout, cancellationToken)
                : _statusService.GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, restartedSession);
            return BuildActionError(
                toolName,
                "restart",
                "editor_restart_attach_timeout",
                $"Timed out waiting for the restarted editor to reattach after {attachTimeout.TotalMilliseconds:F0} ms.",
                project,
                restartedSession,
                finalProcess,
                editorState,
                save,
                force,
                gracefulAttempted: true);
        }

        var finalProcessStatus = _statusService.GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, restartedSession);
        _workspaceState.SetActiveEditorSession(restartedSession.SessionId);
        return BuildActionSuccess(
            toolName,
            "restart",
            "Editor restarted and reattached successfully.",
            project,
            restartedSession,
            finalProcessStatus,
            await _statusService.TryGetRemoteStatusAsync(restartedSession, cancellationToken),
            save,
            force,
            gracefulAttempted: true,
            previousSession: session);
    }

    private async Task<LifecycleActionResult> ExecuteForceCloseAsync(
        string toolName,
        ProjectRegistryService.RegisteredProject project,
        EditorSessionService.EditorSessionStatus session,
        EditorProcessService.EditorProcessStatus process,
        Dictionary<string, object?>? editorState,
        bool save,
        bool force,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var stopResult = await _editorProcesses.ForceStopTrackedProcessAsync(project.ProjectId, project.ProjectRoot, timeout, cancellationToken);
        if (!stopResult.Success)
        {
            return BuildActionError(
                toolName,
                "close",
                stopResult.ErrorType,
                stopResult.Message,
                project,
                session,
                stopResult.Process,
                editorState,
                save,
                force,
                forceAttempted: true);
        }

        _editorSessions.InvalidateSession(project.ProjectId, session.SessionId);
        _workspaceState.ClearActiveEditorSession();
        return BuildActionSuccess(
            toolName,
            "close",
            "Editor closed successfully.",
            project,
            _editorSessions.GetStatus(project.ProjectId),
            _editorProcesses.GetStatus(project.ProjectId, project.ProjectRoot),
            editorState,
            save,
            force,
            forceAttempted: true);
    }

    private async Task<LifecycleActionResult> ExecuteForceRestartAsync(
        string toolName,
        ProjectRegistryService.RegisteredProject project,
        EditorSessionService.EditorSessionStatus session,
        EditorProcessService.EditorProcessStatus process,
        Dictionary<string, object?>? editorState,
        bool save,
        bool force,
        TimeSpan shutdownTimeout,
        int attachTimeoutMs,
        CancellationToken cancellationToken)
    {
        var stopResult = await _editorProcesses.ForceStopTrackedProcessAsync(project.ProjectId, project.ProjectRoot, shutdownTimeout, cancellationToken);
        if (!stopResult.Success)
        {
            return BuildActionError(
                toolName,
                "restart",
                stopResult.ErrorType,
                stopResult.Message,
                project,
                session,
                stopResult.Process,
                editorState,
                save,
                force,
                forceAttempted: true);
        }

        _editorSessions.InvalidateSession(project.ProjectId, session.SessionId);
        _workspaceState.ClearActiveEditorSession();

        var executableResolution = ResolveRelaunchExecutable(project, process);

        EditorProcessService.EditorLaunchResult launch;
        try
        {
            launch = _editorProcesses.OpenProject(
                project,
                executableResolution.ExecutablePath,
                executableResolution.Source,
                "workspace_restart_editor",
                _editorSessionCoordinator.AttachEndpoint);
        }
        catch (Exception ex)
        {
            return BuildActionError(
                toolName,
                "restart",
                "editor_launch_failed",
                $"Failed to relaunch Godot editor: {ex.Message}",
                project,
                null,
                _editorProcesses.GetStatus(project.ProjectId, project.ProjectRoot),
                editorState,
                save,
                force,
                forceAttempted: true);
        }

        var restartedSession = await _editorSessions.WaitForReadyHttpSessionAsync(
            project.ProjectId,
            TimeSpan.FromMilliseconds(EditorSessionCoordinator.NormalizeAttachTimeout(attachTimeoutMs)),
            cancellationToken);

        if (!EditorSessionService.IsHttpReady(restartedSession))
        {
            return BuildActionError(
                toolName,
                "restart",
                "editor_restart_attach_timeout",
                $"Timed out waiting for the restarted editor to attach after {attachTimeoutMs} ms.",
                project,
                restartedSession,
                _editorProcesses.GetStatus(project.ProjectId, project.ProjectRoot),
                editorState,
                save,
                force,
                forceAttempted: true,
                launch: launch);
        }

        var finalProcess = _statusService.GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, restartedSession);
        _workspaceState.SetActiveEditorSession(restartedSession.SessionId);
        return BuildActionSuccess(
            toolName,
            "restart",
            "Editor restarted and reattached successfully.",
            project,
            restartedSession,
            finalProcess,
            await _statusService.TryGetRemoteStatusAsync(restartedSession, cancellationToken),
            save,
            force,
            forceAttempted: true,
            launch: launch,
            previousSession: session);
    }

    private LifecycleActionResult BuildActionSuccess(
        string toolName,
        string action,
        string message,
        ProjectRegistryService.RegisteredProject project,
        EditorSessionService.EditorSessionStatus? session,
        EditorProcessService.EditorProcessStatus? process,
        Dictionary<string, object?>? editorState,
        bool save,
        bool force,
        bool gracefulAttempted = false,
        bool forceAttempted = false,
        EditorProcessService.EditorLaunchResult? launch = null,
        EditorSessionService.EditorSessionStatus? previousSession = null)
    {
        return new LifecycleActionResult
        {
            Success = true,
            Action = action,
            Message = message,
            Project = project,
            Session = session,
            PreviousSession = previousSession,
            Process = process,
            EditorState = editorState,
            EditorLifecycle = _statusService.BuildLifecycleSummary(
                toolName,
                project,
                session,
                process,
                ResolveStatusResolution(session, process),
                editorState),
            SaveRequested = save,
            ForceRequested = force,
            GracefulAttempted = gracefulAttempted,
            ForceAttempted = forceAttempted,
            Launch = launch,
        };
    }

    private LifecycleActionResult BuildActionError(
        string toolName,
        string action,
        string errorType,
        string message,
        ProjectRegistryService.RegisteredProject? project,
        EditorSessionService.EditorSessionStatus? session,
        EditorProcessService.EditorProcessStatus? process,
        Dictionary<string, object?>? editorState,
        bool save,
        bool force,
        bool gracefulAttempted = false,
        bool forceAttempted = false,
        EditorProcessService.EditorLaunchResult? launch = null)
    {
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
            SaveRequested = save,
            ForceRequested = force,
            GracefulAttempted = gracefulAttempted,
            ForceAttempted = forceAttempted,
            Launch = launch,
        };
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

    private static bool CanForceLifecycle(EditorProcessService.EditorProcessStatus process)
    {
        return process.Running
               && string.Equals(process.Ownership, "host_managed", StringComparison.OrdinalIgnoreCase);
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

    private static int NormalizeShutdownTimeout(int? shutdownTimeoutMs)
    {
        if (!shutdownTimeoutMs.HasValue || shutdownTimeoutMs.Value <= 0)
        {
            return DefaultShutdownTimeoutMs;
        }

        return Math.Clamp(shutdownTimeoutMs.Value, MinShutdownTimeoutMs, MaxShutdownTimeoutMs);
    }
}