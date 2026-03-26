using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorLifecycleStatusService
{
    private readonly CentralConfigurationService _configuration;
    private readonly EditorProcessService _editorProcesses;
    private readonly EditorProxyService _editorProxy;
    private readonly EditorSessionService _editorSessions;
    private readonly ProjectRegistryService _registry;
    private readonly CentralWorkspaceState _workspaceState;

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
        _editorProxy = editorProxy;
        _editorSessions = editorSessions;
        _registry = registry;
        _workspaceState = workspaceState;
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

    public async Task<Dictionary<string, object?>?> TryGetRemoteStatusAsync(
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
}