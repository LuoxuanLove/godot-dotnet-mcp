using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class WorkspaceEditorSessionToolHandlerService
{
    private readonly EditorLifecycleCoordinator _editorLifecycleCoordinator;
    private readonly EditorSessionCoordinator _editorSessionCoordinator;
    private readonly CentralHostSessionPayloadFactory _hostSessionPayloadFactory;

    public WorkspaceEditorSessionToolHandlerService(
        EditorLifecycleCoordinator editorLifecycleCoordinator,
        EditorSessionCoordinator editorSessionCoordinator,
        CentralHostSessionPayloadFactory hostSessionPayloadFactory)
    {
        _editorLifecycleCoordinator = editorLifecycleCoordinator;
        _editorSessionCoordinator = editorSessionCoordinator;
        _hostSessionPayloadFactory = hostSessionPayloadFactory;
    }

    public async Task<CentralToolCallResponse> OpenProjectEditorAsync(
        JsonElement arguments,
        CancellationToken cancellationToken)
    {
        var projectId = CentralArgumentReader.GetOptionalString(arguments, "projectId");
        var path = CentralArgumentReader.GetOptionalString(arguments, "path");
        var explicitExecutablePath = CentralArgumentReader.GetOptionalString(arguments, "executablePath") ?? string.Empty;
        var attachTimeoutMs = CentralArgumentReader.GetOptionalPositiveInt(arguments, "attachTimeoutMs");

        var coordination = await _editorSessionCoordinator.EnsureHttpReadySessionAsync(
            "workspace_project_open_editor",
            projectId,
            path,
            autoLaunchEditor: true,
            attachTimeoutMs,
            explicitExecutablePath,
            "workspace_open_editor",
            cancellationToken);

        if (!coordination.Success || coordination.Project is null || coordination.Session is null)
        {
            return CentralToolCallResponse.Error(
                coordination.Message,
                _hostSessionPayloadFactory.BuildFailurePayload(coordination, "workspace_project_open_editor"));
        }

        var centralHostSession = _hostSessionPayloadFactory.Build(
            coordination,
            coordination.Session is null ? string.Empty : $"http://{coordination.Session.ServerHost}:{coordination.Session.ServerPort ?? 0}/mcp",
            "workspace_project_open_editor");
        var editorLifecycle = coordination.Project is null
            ? null
            : _editorLifecycleCoordinator.BuildLifecycleSummary(
                "workspace_project_open_editor",
                coordination.Project,
                coordination.Session,
                _editorLifecycleCoordinator.GetEffectiveProcessStatus(
                    coordination.Project.ProjectId,
                    coordination.Project.ProjectRoot,
                    coordination.Session),
                _hostSessionPayloadFactory.GetResolution(coordination));
        return CentralToolCallResponse.Success(new
        {
            project = coordination.Project,
            editorSession = coordination.Session,
            editorLifecycle,
            centralHostSession,
        });
    }
}
