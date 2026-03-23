namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorSessionCoordinator
{
    public const int DefaultAttachTimeoutMs = 45_000;
    private const int MinAttachTimeoutMs = 1_000;
    private const int MaxAttachTimeoutMs = 180_000;

    private readonly CentralConfigurationService _configuration;
    private readonly EditorProcessService _editorProcesses;
    private readonly EditorSessionService _editorSessions;
    private readonly GodotInstallationService _godotInstallations;
    private readonly ProjectRegistryService _registry;
    private readonly SessionState _sessionState;
    private readonly EditorAttachEndpoint _attachEndpoint;

    public EditorSessionCoordinator(
        CentralConfigurationService configuration,
        EditorProcessService editorProcesses,
        EditorSessionService editorSessions,
        GodotInstallationService godotInstallations,
        ProjectRegistryService registry,
        SessionState sessionState,
        EditorAttachEndpoint attachEndpoint)
    {
        _configuration = configuration;
        _editorProcesses = editorProcesses;
        _editorSessions = editorSessions;
        _godotInstallations = godotInstallations;
        _registry = registry;
        _sessionState = sessionState;
        _attachEndpoint = attachEndpoint;
    }

    public EditorAttachEndpoint AttachEndpoint => _attachEndpoint;

    public async Task<EnsureEditorSessionResult> EnsureHttpReadySessionAsync(
        string toolName,
        string? projectId,
        string? projectPath,
        bool autoLaunchEditor,
        int? attachTimeoutMs,
        CancellationToken cancellationToken)
    {
        var projectResolution = ResolveProject(projectId, projectPath);
        if (!projectResolution.Success || projectResolution.Project is null)
        {
            return EnsureEditorSessionResult.FromFailure(
                projectResolution.ErrorType,
                projectResolution.Message,
                _sessionState.ActiveProjectId,
                project: null,
                toolName: toolName);
        }

        var project = projectResolution.Project;
        _sessionState.ActiveProjectId = project.ProjectId;

        var session = _editorSessions.GetStatus(project.ProjectId);
        if (EditorSessionService.IsHttpReady(session))
        {
            _sessionState.ActiveEditorSessionId = session.SessionId;
            return EnsureEditorSessionResult.FromReady(project, session, null, false, false, attachTimeoutMs ?? DefaultAttachTimeoutMs);
        }

        if (session.Attached && !EditorSessionService.IsHttpTransportSupported(session))
        {
            return EnsureEditorSessionResult.FromFailure(
                "editor_transport_unavailable",
                "Attached editor session does not expose an HTTP MCP endpoint.",
                _sessionState.ActiveProjectId,
                project,
                session,
                null,
                _editorProcesses.GetStatus(project.ProjectId),
                attachTimeoutMs ?? DefaultAttachTimeoutMs,
                false,
                false,
                toolName);
        }

        var timeout = NormalizeAttachTimeout(attachTimeoutMs);
        var runningEditor = _editorProcesses.GetStatus(project.ProjectId);
        if (runningEditor.Running)
        {
            var reusedSession = await _editorSessions.WaitForReadyHttpSessionAsync(project.ProjectId, TimeSpan.FromMilliseconds(timeout), cancellationToken);
            if (EditorSessionService.IsHttpReady(reusedSession))
            {
                _sessionState.ActiveEditorSessionId = reusedSession.SessionId;
                return EnsureEditorSessionResult.FromReady(project, reusedSession, null, false, true, timeout);
            }

            return EnsureEditorSessionResult.FromFailure(
                "editor_attach_timeout",
                "Timed out waiting for the running Godot editor to attach.",
                _sessionState.ActiveProjectId,
                project,
                reusedSession,
                null,
                runningEditor,
                timeout,
                false,
                true,
                toolName);
        }

        if (!autoLaunchEditor)
        {
            return EnsureEditorSessionResult.FromFailure(
                "editor_required",
                "Editor-attached tool requires an active editor session.",
                _sessionState.ActiveProjectId,
                project,
                session,
                null,
                runningEditor,
                timeout,
                false,
                false,
                toolName);
        }

        GodotInstallationService.GodotExecutableResolution executable;
        try
        {
            executable = _godotInstallations.ResolveExecutable(project, string.Empty, _configuration);
        }
        catch (CentralToolException ex)
        {
            return EnsureEditorSessionResult.FromFailure(
                "godot_executable_not_found",
                ex.Message,
                _sessionState.ActiveProjectId,
                project,
                session,
                null,
                runningEditor,
                timeout,
                true,
                false,
                toolName);
        }

        EditorProcessService.EditorLaunchResult launch;
        try
        {
            launch = _editorProcesses.OpenProject(project, executable.ExecutablePath, executable.Source, _attachEndpoint);
        }
        catch (CentralToolException ex)
        {
            return EnsureEditorSessionResult.FromFailure(
                "editor_launch_failed",
                ex.Message,
                _sessionState.ActiveProjectId,
                project,
                session,
                null,
                runningEditor,
                timeout,
                true,
                false,
                toolName);
        }
        catch (Exception ex)
        {
            return EnsureEditorSessionResult.FromFailure(
                "editor_launch_failed",
                $"Failed to launch Godot editor: {ex.Message}",
                _sessionState.ActiveProjectId,
                project,
                session,
                null,
                runningEditor,
                timeout,
                true,
                false,
                toolName);
        }

        var attachedSession = await _editorSessions.WaitForReadyHttpSessionAsync(project.ProjectId, TimeSpan.FromMilliseconds(timeout), cancellationToken);
        if (!EditorSessionService.IsHttpReady(attachedSession))
        {
            return EnsureEditorSessionResult.FromFailure(
                "editor_attach_timeout",
                "Timed out waiting for Godot editor to attach and expose an HTTP MCP endpoint.",
                _sessionState.ActiveProjectId,
                project,
                attachedSession,
                launch,
                _editorProcesses.GetStatus(project.ProjectId),
                timeout,
                true,
                launch.AlreadyRunning,
                toolName);
        }

        _sessionState.ActiveEditorSessionId = attachedSession.SessionId;
        return EnsureEditorSessionResult.FromReady(project, attachedSession, launch, true, launch.AlreadyRunning, timeout);
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

        if (string.IsNullOrWhiteSpace(_sessionState.ActiveProjectId))
        {
            return ProjectResolution.FromFailure("project_not_selected", "No active project is selected for this MCP session.");
        }

        var activeProject = _registry.ResolveProject(_sessionState.ActiveProjectId, null);
        return activeProject is null
            ? ProjectResolution.FromFailure("project_not_registered", "The active project for this MCP session is no longer registered.")
            : ProjectResolution.FromProject(activeProject);
    }

    private static int NormalizeAttachTimeout(int? attachTimeoutMs)
    {
        if (!attachTimeoutMs.HasValue || attachTimeoutMs.Value <= 0)
        {
            return DefaultAttachTimeoutMs;
        }

        return Math.Clamp(attachTimeoutMs.Value, MinAttachTimeoutMs, MaxAttachTimeoutMs);
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

        public static EnsureEditorSessionResult FromReady(
            ProjectRegistryService.RegisteredProject project,
            EditorSessionService.EditorSessionStatus session,
            EditorProcessService.EditorLaunchResult? launch,
            bool autoLaunchAttempted,
            bool reusedRunningEditor,
            int attachTimeoutMs)
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
            int attachTimeoutMs = DefaultAttachTimeoutMs,
            bool autoLaunchAttempted = false,
            bool reusedRunningEditor = false,
            string toolName = "")
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
                _ => null,
            };
        }
    }
}
