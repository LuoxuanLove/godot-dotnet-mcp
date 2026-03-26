namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorSessionAcquisitionService
{
    private readonly CentralConfigurationService _configuration;
    private readonly EditorProcessService _editorProcesses;
    private readonly EditorSessionService _editorSessions;
    private readonly GodotInstallationService _godotInstallations;
    private readonly ProjectRegistryService _registry;
    private readonly CentralWorkspaceState _workspaceState;
    private readonly EditorAttachEndpoint _attachEndpoint;

    public EditorSessionAcquisitionService(
        CentralConfigurationService configuration,
        EditorProcessService editorProcesses,
        EditorSessionService editorSessions,
        GodotInstallationService godotInstallations,
        ProjectRegistryService registry,
        CentralWorkspaceState workspaceState,
        EditorAttachEndpoint attachEndpoint)
    {
        _configuration = configuration;
        _editorProcesses = editorProcesses;
        _editorSessions = editorSessions;
        _godotInstallations = godotInstallations;
        _registry = registry;
        _workspaceState = workspaceState;
        _attachEndpoint = attachEndpoint;
    }

    public GodotInstallationService.GodotExecutableResolution ResolveExecutable(
        ProjectRegistryService.RegisteredProject project,
        string explicitExecutablePath)
    {
        return _godotInstallations.ResolveExecutable(project, explicitExecutablePath, _configuration);
    }

    public async Task<EnsureEditorSessionResult> EnsureHttpReadySessionAsync(
        string toolName,
        string? projectId,
        string? projectPath,
        bool autoLaunchEditor,
        int? attachTimeoutMs,
        string? explicitExecutablePath,
        string launchReason,
        CancellationToken cancellationToken)
    {
        var projectResolution = ResolveProject(projectId, projectPath);
        if (!projectResolution.Success || projectResolution.Project is null)
        {
            return EnsureEditorSessionResult.FromFailure(
                projectResolution.ErrorType,
                projectResolution.Message,
                _workspaceState.ActiveProjectId,
                project: null,
                toolName: toolName,
                requestedExecutablePath: explicitExecutablePath ?? string.Empty);
        }

        var project = projectResolution.Project;
        _workspaceState.SetActiveProject(project.ProjectId);
        var requestedExecutablePath = explicitExecutablePath?.Trim() ?? string.Empty;

        var session = _editorSessions.GetStatus(project.ProjectId);
        if (EditorSessionService.IsHttpReady(session))
        {
            _workspaceState.SetActiveEditorSession(session.SessionId);
            return EnsureEditorSessionResult.FromReady(
                project,
                session,
                null,
                false,
                false,
                attachTimeoutMs ?? EditorSessionCoordinator.DefaultAttachTimeoutMs,
                requestedExecutablePath);
        }

        if (session.Attached && !EditorSessionService.IsHttpTransportSupported(session))
        {
            return EnsureEditorSessionResult.FromFailure(
                "editor_transport_unavailable",
                "Attached editor session does not expose an HTTP MCP endpoint.",
                _workspaceState.ActiveProjectId,
                project,
                session,
                null,
                _editorProcesses.GetStatus(project.ProjectId, project.ProjectRoot),
                attachTimeoutMs ?? EditorSessionCoordinator.DefaultAttachTimeoutMs,
                false,
                false,
                toolName,
                requestedExecutablePath: requestedExecutablePath);
        }

        var timeout = EditorSessionCoordinator.NormalizeAttachTimeout(attachTimeoutMs);
        var runningEditor = _editorProcesses.GetStatus(project.ProjectId, project.ProjectRoot);
        if (runningEditor.Running)
        {
            var reusedSession = await _editorSessions.WaitForReadyHttpSessionAsync(
                project.ProjectId,
                TimeSpan.FromMilliseconds(timeout),
                cancellationToken);
            if (EditorSessionService.IsHttpReady(reusedSession))
            {
                _workspaceState.SetActiveEditorSession(reusedSession.SessionId);
                return EnsureEditorSessionResult.FromReady(project, reusedSession, null, false, true, timeout, requestedExecutablePath);
            }

            return EnsureEditorSessionResult.FromFailure(
                "editor_attach_timeout",
                "Timed out waiting for the running Godot editor to attach.",
                _workspaceState.ActiveProjectId,
                project,
                reusedSession,
                null,
                runningEditor,
                timeout,
                false,
                true,
                toolName,
                requestedExecutablePath: requestedExecutablePath);
        }

        var externalEditor = _editorProcesses.FindUntrackedEditorStatus(project.ProjectId, project.ProjectRoot);
        if (externalEditor is not null && externalEditor.Running)
        {
            var externalSession = await _editorSessions.WaitForReadyHttpSessionAsync(
                project.ProjectId,
                TimeSpan.FromMilliseconds(timeout),
                cancellationToken);
            if (EditorSessionService.IsHttpReady(externalSession))
            {
                _workspaceState.SetActiveEditorSession(externalSession.SessionId);
                return EnsureEditorSessionResult.FromReady(project, externalSession, null, false, true, timeout, requestedExecutablePath);
            }

            return EnsureEditorSessionResult.FromFailure(
                "editor_already_running_external",
                "A Godot editor for this project is already running outside the current host session. Refusing to launch a duplicate editor instance.",
                _workspaceState.ActiveProjectId,
                project,
                externalSession,
                null,
                externalEditor,
                timeout,
                false,
                true,
                toolName,
                requestedExecutablePath: requestedExecutablePath);
        }

        if (!autoLaunchEditor)
        {
            return EnsureEditorSessionResult.FromFailure(
                "editor_required",
                "Editor-attached tool requires an active editor session.",
                _workspaceState.ActiveProjectId,
                project,
                session,
                null,
                runningEditor,
                timeout,
                false,
                false,
                toolName,
                requestedExecutablePath: requestedExecutablePath);
        }

        GodotInstallationService.GodotExecutableResolution executable;
        try
        {
            executable = ResolveExecutable(project, requestedExecutablePath);
        }
        catch (CentralToolException ex)
        {
            return EnsureEditorSessionResult.FromFailure(
                "godot_executable_not_found",
                ex.Message,
                _workspaceState.ActiveProjectId,
                project,
                session,
                null,
                runningEditor,
                timeout,
                true,
                false,
                toolName,
                requestedExecutablePath: requestedExecutablePath);
        }

        EditorProcessService.EditorLaunchResult launch;
        try
        {
            launch = _editorProcesses.OpenProject(project, executable.ExecutablePath, executable.Source, launchReason, _attachEndpoint);
        }
        catch (CentralToolException ex)
        {
            return EnsureEditorSessionResult.FromFailure(
                "editor_launch_failed",
                ex.Message,
                _workspaceState.ActiveProjectId,
                project,
                session,
                null,
                runningEditor,
                timeout,
                true,
                false,
                toolName,
                requestedExecutablePath: requestedExecutablePath,
                resolvedExecutablePath: executable.ExecutablePath,
                resolvedExecutableSource: executable.Source);
        }
        catch (Exception ex)
        {
            return EnsureEditorSessionResult.FromFailure(
                "editor_launch_failed",
                $"Failed to launch Godot editor: {ex.Message}",
                _workspaceState.ActiveProjectId,
                project,
                session,
                null,
                runningEditor,
                timeout,
                true,
                false,
                toolName,
                requestedExecutablePath: requestedExecutablePath,
                resolvedExecutablePath: executable.ExecutablePath,
                resolvedExecutableSource: executable.Source);
        }

        var attachedSession = await _editorSessions.WaitForReadyHttpSessionAsync(
            project.ProjectId,
            TimeSpan.FromMilliseconds(timeout),
            cancellationToken);
        if (!EditorSessionService.IsHttpReady(attachedSession))
        {
            return EnsureEditorSessionResult.FromFailure(
                "editor_attach_timeout",
                "Timed out waiting for Godot editor to attach and expose an HTTP MCP endpoint.",
                _workspaceState.ActiveProjectId,
                project,
                attachedSession,
                launch,
                _editorProcesses.GetStatus(project.ProjectId, project.ProjectRoot),
                timeout,
                true,
                launch.AlreadyRunning,
                toolName,
                requestedExecutablePath: requestedExecutablePath,
                resolvedExecutablePath: executable.ExecutablePath,
                resolvedExecutableSource: executable.Source);
        }

        _workspaceState.SetActiveEditorSession(attachedSession.SessionId);
        return EnsureEditorSessionResult.FromReady(
            project,
            attachedSession,
            launch,
            true,
            launch.AlreadyRunning,
            timeout,
            requestedExecutablePath,
            executable.ExecutablePath,
            executable.Source);
    }

    private ProjectResolution ResolveProject(string? explicitProjectId, string? explicitProjectPath)
    {
        if (!string.IsNullOrWhiteSpace(explicitProjectId))
        {
            var project = _registry.ResolveProject(explicitProjectId, null);
            return project is null
                ? ProjectResolution.FromFailure("project_not_registered", "Registered project not found.")
                : ProjectResolution.FromProject(project);
        }

        if (!string.IsNullOrWhiteSpace(explicitProjectPath))
        {
            try
            {
                var existing = _registry.ResolveProject(null, explicitProjectPath);
                return ProjectResolution.FromProject(existing ?? _registry.RegisterProject(explicitProjectPath, "system_tool_call"));
            }
            catch (CentralToolException ex)
            {
                return ProjectResolution.FromFailure("project_not_registered", ex.Message);
            }
        }

        if (string.IsNullOrWhiteSpace(_workspaceState.ActiveProjectId))
        {
            return ProjectResolution.FromFailure("project_not_selected", "No active project is selected for this MCP session.");
        }

        var activeProject = _registry.ResolveProject(_workspaceState.ActiveProjectId, null);
        return activeProject is null
            ? ProjectResolution.FromFailure("project_not_registered", "The active project for this MCP session is no longer registered.")
            : ProjectResolution.FromProject(activeProject);
    }

    private sealed record ProjectResolution(
        bool Success,
        ProjectRegistryService.RegisteredProject? Project,
        string ErrorType,
        string Message)
    {
        public static ProjectResolution FromProject(ProjectRegistryService.RegisteredProject project)
            => new(true, project, string.Empty, string.Empty);

        public static ProjectResolution FromFailure(string errorType, string message)
            => new(false, null, errorType, message);
    }
}
