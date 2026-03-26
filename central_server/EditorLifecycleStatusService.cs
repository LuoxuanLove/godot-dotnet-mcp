namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorLifecycleStatusService
{
    private readonly CentralConfigurationService _configuration;
    private readonly EditorProcessService _editorProcesses;
    private readonly EditorSessionService _editorSessions;
    private readonly ProjectRegistryService _registry;
    private readonly CentralWorkspaceState _workspaceState;
    private readonly EditorLifecycleRemoteStateService _remoteStateService;
    private readonly EditorLifecycleSummaryBuilder _summaryBuilder;

    public EditorLifecycleStatusService(
        CentralConfigurationService configuration,
        EditorProcessService editorProcesses,
        EditorProxyService editorProxy,
        EditorSessionService editorSessions,
        ProjectRegistryService registry,
        CentralWorkspaceState workspaceState)
    {
        _configuration = configuration;
        _editorProcesses = editorProcesses;
        _editorSessions = editorSessions;
        _registry = registry;
        _workspaceState = workspaceState;
        _remoteStateService = new EditorLifecycleRemoteStateService(editorProxy);
        _summaryBuilder = new EditorLifecycleSummaryBuilder(editorProcesses.StorePath);
    }

    public async Task<ProjectStatusSnapshot> GetProjectStatusAsync(
        string? projectId,
        string? projectPath,
        CancellationToken cancellationToken)
    {
        var registryStatus = _registry.BuildStatus(_workspaceState.ActiveProjectId);
        var activeEditorSession = _editorSessions.GetStatusBySessionId(_workspaceState.ActiveEditorSessionId);
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
                EditorLifecycleSummaryBuilder.ResolveStatusResolution(session, process),
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
        return _summaryBuilder.BuildLifecycleSummary(toolName, project, session, process, resolution, editorState);
    }

    public Task<Dictionary<string, object?>?> TryGetRemoteStatusAsync(
        EditorSessionService.EditorSessionStatus? session,
        CancellationToken cancellationToken)
    {
        return _remoteStateService.TryGetRemoteStatusAsync(session, cancellationToken);
    }

    public ProjectRegistryService.RegisteredProject? ResolveProject(string? explicitProjectId, string? explicitProjectPath)
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

        return string.IsNullOrWhiteSpace(_workspaceState.ActiveProjectId)
            ? null
            : _registry.ResolveProject(_workspaceState.ActiveProjectId, null);
    }

    internal static Dictionary<string, object?> BuildUnsupportedEditorLifecycleState(EditorSessionService.EditorSessionStatus session)
    {
        return EditorLifecycleRemoteStateService.BuildUnsupportedEditorLifecycleState(session);
    }
}
