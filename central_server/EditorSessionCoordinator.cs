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
                _sessionState.ActiveProjectId,
                project: null,
                toolName: toolName,
                requestedExecutablePath: explicitExecutablePath ?? string.Empty);
        }

        var project = projectResolution.Project;
        _sessionState.ActiveProjectId = project.ProjectId;
        var requestedExecutablePath = explicitExecutablePath?.Trim() ?? string.Empty;

        var session = _editorSessions.GetStatus(project.ProjectId);
        if (EditorSessionService.IsHttpReady(session))
        {
            _sessionState.ActiveEditorSessionId = session.SessionId;
            return EnsureEditorSessionResult.FromReady(
                project,
                session,
                null,
                false,
                false,
                attachTimeoutMs ?? DefaultAttachTimeoutMs,
                requestedExecutablePath);
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
                _editorProcesses.GetStatus(project.ProjectId, project.ProjectRoot),
                attachTimeoutMs ?? DefaultAttachTimeoutMs,
                false,
                false,
                toolName,
                requestedExecutablePath: requestedExecutablePath);
        }

        var timeout = NormalizeAttachTimeout(attachTimeoutMs);
        var runningEditor = _editorProcesses.GetStatus(project.ProjectId, project.ProjectRoot);
        if (runningEditor.Running)
        {
            var reusedSession = await _editorSessions.WaitForReadyHttpSessionAsync(project.ProjectId, TimeSpan.FromMilliseconds(timeout), cancellationToken);
            if (EditorSessionService.IsHttpReady(reusedSession))
            {
                _sessionState.ActiveEditorSessionId = reusedSession.SessionId;
                return EnsureEditorSessionResult.FromReady(project, reusedSession, null, false, true, timeout, requestedExecutablePath);
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
                toolName,
                requestedExecutablePath: requestedExecutablePath);
        }

        var externalEditor = _editorProcesses.FindUntrackedEditorStatus(project.ProjectId, project.ProjectRoot);
        if (externalEditor is not null && externalEditor.Running)
        {
            var externalSession = await _editorSessions.WaitForReadyHttpSessionAsync(project.ProjectId, TimeSpan.FromMilliseconds(timeout), cancellationToken);
            if (EditorSessionService.IsHttpReady(externalSession))
            {
                _sessionState.ActiveEditorSessionId = externalSession.SessionId;
                return EnsureEditorSessionResult.FromReady(project, externalSession, null, false, true, timeout, requestedExecutablePath);
            }

            return EnsureEditorSessionResult.FromFailure(
                "editor_already_running_external",
                "A Godot editor for this project is already running outside the current host session. Refusing to launch a duplicate editor instance.",
                _sessionState.ActiveProjectId,
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
                _sessionState.ActiveProjectId,
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
                _sessionState.ActiveProjectId,
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
                _sessionState.ActiveProjectId,
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
                _sessionState.ActiveProjectId,
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
                _editorProcesses.GetStatus(project.ProjectId, project.ProjectRoot),
                timeout,
                true,
                launch.AlreadyRunning,
                toolName,
                requestedExecutablePath: requestedExecutablePath,
                resolvedExecutablePath: executable.ExecutablePath,
                resolvedExecutableSource: executable.Source);
        }

        _sessionState.ActiveEditorSessionId = attachedSession.SessionId;
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

        if (string.IsNullOrWhiteSpace(_sessionState.ActiveProjectId))
        {
            return ProjectResolution.FromFailure("project_not_selected", "No active project is selected for this MCP session.");
        }

        var activeProject = _registry.ResolveProject(_sessionState.ActiveProjectId, null);
        return activeProject is null
            ? ProjectResolution.FromFailure("project_not_registered", "The active project for this MCP session is no longer registered.")
            : ProjectResolution.FromProject(activeProject);
    }

    internal static int NormalizeAttachTimeout(int? attachTimeoutMs)
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
            int attachTimeoutMs = DefaultAttachTimeoutMs,
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
                            attachTimeoutMs = Math.Min(AttachTimeoutMs * 2, MaxAttachTimeoutMs),
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
                            attachTimeoutMs = Math.Min(AttachTimeoutMs * 2, MaxAttachTimeoutMs),
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
                            attachTimeoutMs = Math.Min(AttachTimeoutMs * 2, MaxAttachTimeoutMs),
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
                            attachTimeoutMs = Math.Min(AttachTimeoutMs * 2, MaxAttachTimeoutMs),
                        },
                    },
                },
                _ => null,
            };
        }
    }
}
