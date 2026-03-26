namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorLifecycleCoordinator
{
    private readonly EditorLifecycleStatusService _statusService;
    private readonly EditorLifecycleActionService _actionService;

    public EditorLifecycleCoordinator(
        CentralConfigurationService configuration,
        EditorProcessService editorProcesses,
        EditorProxyService editorProxy,
        EditorSessionCoordinator editorSessionCoordinator,
        EditorSessionService editorSessions,
        ProjectRegistryService registry,
        CentralWorkspaceState workspaceState)
    {
        _statusService = new EditorLifecycleStatusService(
            configuration,
            editorProcesses,
            editorProxy,
            editorSessions,
            registry,
            workspaceState);
        _actionService = new EditorLifecycleActionService(
            editorProcesses,
            editorProxy,
            editorSessionCoordinator,
            editorSessions,
            _statusService,
            workspaceState);
    }

    public Task<ProjectStatusSnapshot> GetProjectStatusAsync(
        string? projectId,
        string? projectPath,
        CancellationToken cancellationToken)
    {
        return _statusService.GetProjectStatusAsync(projectId, projectPath, cancellationToken);
    }

    public EditorProcessService.EditorProcessStatus GetEffectiveProcessStatus(
        string projectId,
        string? projectRoot,
        EditorSessionService.EditorSessionStatus? session)
    {
        return _statusService.GetEffectiveProcessStatus(projectId, projectRoot, session);
    }

    public Dictionary<string, object?> BuildLifecycleSummary(
        string toolName,
        ProjectRegistryService.RegisteredProject? project,
        EditorSessionService.EditorSessionStatus? session,
        EditorProcessService.EditorProcessStatus? process,
        string resolution,
        Dictionary<string, object?>? editorState = null)
    {
        return _statusService.BuildLifecycleSummary(toolName, project, session, process, resolution, editorState);
    }

    public Task<LifecycleActionResult> CloseEditorAsync(
        string? projectId,
        string? projectPath,
        bool save,
        bool force,
        int? shutdownTimeoutMs,
        CancellationToken cancellationToken)
    {
        return _actionService.CloseEditorAsync(projectId, projectPath, save, force, shutdownTimeoutMs, cancellationToken);
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
        return _actionService.RestartEditorAsync(
            projectId,
            projectPath,
            save,
            force,
            shutdownTimeoutMs,
            attachTimeoutMs,
            cancellationToken);
    }
}
