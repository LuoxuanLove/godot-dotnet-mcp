using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorLifecycleCoordinator
{
    private const int DefaultShutdownTimeoutMs = 30_000;
    private const int MinShutdownTimeoutMs = 1_000;
    private const int MaxShutdownTimeoutMs = 180_000;

    private readonly CentralConfigurationService _configuration;
    private readonly EditorProcessService _editorProcesses;
    private readonly EditorProxyService _editorProxy;
    private readonly EditorSessionCoordinator _editorSessionCoordinator;
    private readonly EditorSessionService _editorSessions;
    private readonly ProjectRegistryService _registry;
    private readonly SessionState _sessionState;

    public EditorLifecycleCoordinator(
        CentralConfigurationService configuration,
        EditorProcessService editorProcesses,
        EditorProxyService editorProxy,
        EditorSessionCoordinator editorSessionCoordinator,
        EditorSessionService editorSessions,
        ProjectRegistryService registry,
        SessionState sessionState)
    {
        _configuration = configuration;
        _editorProcesses = editorProcesses;
        _editorProxy = editorProxy;
        _editorSessionCoordinator = editorSessionCoordinator;
        _editorSessions = editorSessions;
        _registry = registry;
        _sessionState = sessionState;
    }

    public async Task<ProjectStatusSnapshot> GetProjectStatusAsync(
        string? projectId,
        string? projectPath,
        CancellationToken cancellationToken)
    {
        var registryStatus = _registry.BuildStatus(_sessionState.ActiveProjectId);
        var activeEditorSession = _editorSessions.GetStatusBySessionId(_sessionState.ActiveEditorSessionId);
        var project = ResolveProject(projectId, projectPath);
        if (project is null)
        {
            return new ProjectStatusSnapshot
            {
                Success = false,
                ErrorType = "project_not_registered",
                Message = "Registered project not found or no active project is selected.",
                RegistryStatus = registryStatus,
                Process = EditorProcessService.EditorProcessStatus.Empty(projectId ?? string.Empty, _editorProcesses.StorePath),
                ActiveEditorSession = activeEditorSession,
                EditorLifecycle = BuildLifecycleSummary(
                    "workspace_project_status",
                    project: null,
                    session: null,
                    process: null,
                    resolution: "editor_unavailable",
                    editorState: null),
            };
        }

        var session = _editorSessions.GetStatus(project.ProjectId);
        var process = GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, session);
        var editorState = await TryGetRemoteStatusAsync(session, cancellationToken);
        return new ProjectStatusSnapshot
        {
            Success = true,
            RegistryStatus = registryStatus,
            Configuration = _configuration.BuildStatus(),
            Project = project,
            Session = session,
            Process = process,
            ActiveEditorSession = activeEditorSession,
            EditorState = editorState,
            EditorLifecycle = BuildLifecycleSummary(
                "workspace_project_status",
                project,
                session,
                process,
                ResolveStatusResolution(session, process),
                editorState),
        };
    }

    public EditorProcessService.EditorProcessStatus GetEffectiveProcessStatus(
        string projectId,
        string? projectRoot,
        EditorSessionService.EditorSessionStatus? session)
    {
        if (session?.ProcessId is > 0)
        {
            _editorProcesses.SyncTrackedProcess(
                projectId,
                projectRoot ?? session.ProjectRoot,
                session.ProcessId.Value,
                session.ServerHost,
                session.ServerPort,
                session.AttachedAtUtc);
        }

        return _editorProcesses.GetStatus(projectId, projectRoot ?? session?.ProjectRoot);
    }

    public Dictionary<string, object?> BuildLifecycleSummary(
        string toolName,
        ProjectRegistryService.RegisteredProject? project,
        EditorSessionService.EditorSessionStatus? session,
        EditorProcessService.EditorProcessStatus? process,
        string resolution,
        Dictionary<string, object?>? editorState = null)
    {
        var processStatus = process ?? EditorProcessService.EditorProcessStatus.Empty(project?.ProjectId ?? string.Empty, _editorProcesses.StorePath);
        var attached = session?.Attached ?? false;
        var httpReady = session is not null && EditorSessionService.IsHttpReady(session);
        var supportsEditorLifecycle = session is not null && EditorSessionService.SupportsEditorLifecycle(session);
        var resident = processStatus.Running || attached;
        var ownership = processStatus.Running
            ? processStatus.Ownership
            : attached
                ? "external_attached"
                : "none";
        var processId = processStatus.ProcessId ?? session?.ProcessId ?? 0;
        var startedAtUtc = processStatus.StartedAtUtc ?? session?.AttachedAtUtc;

        var summary = new Dictionary<string, object?>
        {
            ["policy"] = "persistent_background_editor",
            ["toolName"] = toolName,
            ["resolution"] = resolution,
            ["resident"] = resident,
            ["ownership"] = ownership,
            ["attached"] = attached,
            ["httpReady"] = httpReady,
            ["supportsEditorLifecycle"] = supportsEditorLifecycle,
            ["sessionId"] = session?.SessionId ?? string.Empty,
            ["processId"] = processId,
            ["startedAtUtc"] = startedAtUtc?.ToString("O") ?? string.Empty,
            ["launchReason"] = processStatus.LaunchReason,
            ["canGracefulClose"] = httpReady && supportsEditorLifecycle,
            ["canForceClose"] = processStatus.Running
                && string.Equals(processStatus.Ownership, "host_managed", StringComparison.OrdinalIgnoreCase),
            ["storePath"] = processStatus.StorePath,
        };

        if (project is not null)
        {
            summary["projectId"] = project.ProjectId;
            summary["projectPath"] = project.ProjectRoot;
        }

        if (editorState is not null && editorState.Count > 0)
        {
            summary["editorState"] = editorState;
        }

        return summary;
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
        var project = ResolveProject(projectId, projectPath);
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

        _sessionState.ActiveProjectId = project.ProjectId;

        var session = _editorSessions.GetStatus(project.ProjectId);
        var process = GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, session);
        var editorState = await TryGetRemoteStatusAsync(session, cancellationToken);
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
                        editorState ?? BuildUnsupportedEditorLifecycleState(session),
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
                GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, finalSession),
                editorState,
                save,
                force,
                gracefulAttempted: true);
        }

        var finalProcess = process.Running
            ? await _editorProcesses.WaitForExitAsync(project.ProjectId, project.ProjectRoot, timeout, cancellationToken)
            : GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, finalSession);

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

        _sessionState.ActiveEditorSessionId = string.Empty;
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
                : GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, restartedSession);
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

        var finalProcessStatus = GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, restartedSession);
        _sessionState.ActiveEditorSessionId = restartedSession.SessionId;
        return BuildActionSuccess(
            toolName,
            "restart",
            "Editor restarted and reattached successfully.",
            project,
            restartedSession,
            finalProcessStatus,
            await TryGetRemoteStatusAsync(restartedSession, cancellationToken),
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
        _sessionState.ActiveEditorSessionId = string.Empty;
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
        _sessionState.ActiveEditorSessionId = string.Empty;

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

        var finalProcess = GetEffectiveProcessStatus(project.ProjectId, project.ProjectRoot, restartedSession);
        _sessionState.ActiveEditorSessionId = restartedSession.SessionId;
        return BuildActionSuccess(
            toolName,
            "restart",
            "Editor restarted and reattached successfully.",
            project,
            restartedSession,
            finalProcess,
            await TryGetRemoteStatusAsync(restartedSession, cancellationToken),
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
            EditorLifecycle = BuildLifecycleSummary(
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
            EditorLifecycle = BuildLifecycleSummary(
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

    private async Task<Dictionary<string, object?>?> TryGetRemoteStatusAsync(
        EditorSessionService.EditorSessionStatus? session,
        CancellationToken cancellationToken)
    {
        if (session is null || !EditorSessionService.IsHttpReady(session))
        {
            return null;
        }

        if (!EditorSessionService.SupportsEditorLifecycle(session))
        {
            return BuildUnsupportedEditorLifecycleState(session);
        }

        try
        {
            var response = await _editorProxy.GetEditorLifecycleStatusAsync(session, cancellationToken);
            if (!response.Success)
            {
                return new Dictionary<string, object?>
                {
                    ["available"] = false,
                    ["error"] = response.ErrorType,
                    ["message"] = response.Message,
                    ["endpoint"] = response.Endpoint,
                };
            }

            return ExtractDataDictionary(response.Payload)
                ?? new Dictionary<string, object?>
                {
                    ["available"] = true,
                    ["endpoint"] = response.Endpoint,
                };
        }
        catch (Exception ex)
        {
            return new Dictionary<string, object?>
            {
                ["available"] = false,
                ["error"] = "editor_status_unavailable",
                ["message"] = ex.Message,
            };
        }
    }

    private static Dictionary<string, object?> BuildUnsupportedEditorLifecycleState(EditorSessionService.EditorSessionStatus session)
    {
        return new Dictionary<string, object?>
        {
            ["available"] = false,
            ["error"] = "editor_lifecycle_unsupported",
            ["message"] = "Attached editor session does not advertise internal editor lifecycle support.",
            ["endpoint"] = string.IsNullOrWhiteSpace(session.ServerHost) || session.ServerPort is null or <= 0
                ? string.Empty
                : $"http://{session.ServerHost}:{session.ServerPort}/api/editor/lifecycle",
            ["capabilities"] = session.Capabilities,
        };
    }

    private ProjectRegistryService.RegisteredProject? ResolveProject(string? explicitProjectId, string? explicitProjectPath)
    {
        if (!string.IsNullOrWhiteSpace(explicitProjectId))
        {
            return _registry.ResolveProject(explicitProjectId, null);
        }

        if (!string.IsNullOrWhiteSpace(explicitProjectPath))
        {
            try
            {
                return _registry.ResolveProject(null, explicitProjectPath)
                       ?? _registry.RegisterProject(explicitProjectPath, "workspace_lifecycle");
            }
            catch (CentralToolException)
            {
                return null;
            }
        }

        return string.IsNullOrWhiteSpace(_sessionState.ActiveProjectId)
            ? null
            : _registry.ResolveProject(_sessionState.ActiveProjectId, null);
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

    private static Dictionary<string, object?>? ExtractDataDictionary(JsonElement payload)
    {
        if (payload.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        if (payload.TryGetProperty("data", out var dataElement) && dataElement.ValueKind == JsonValueKind.Object)
        {
            return JsonSerializer.Deserialize<Dictionary<string, object?>>(dataElement.GetRawText(), CentralServerSerialization.JsonOptions);
        }

        return JsonSerializer.Deserialize<Dictionary<string, object?>>(payload.GetRawText(), CentralServerSerialization.JsonOptions);
    }

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
}
