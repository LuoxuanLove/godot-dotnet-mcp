using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorToolHandlerService
{
    private readonly EditorLifecycleCoordinator _editorLifecycleCoordinator;
    private readonly WorkspaceEditorSessionToolHandlerService _sessionTools;

    public EditorToolHandlerService(
        EditorLifecycleCoordinator editorLifecycleCoordinator,
        WorkspaceEditorSessionToolHandlerService sessionTools)
    {
        _editorLifecycleCoordinator = editorLifecycleCoordinator;
        _sessionTools = sessionTools;
    }

    public void RegisterHandlers(CentralToolHandlerRegistry handlers)
    {
        handlers
            .Register("workspace_project_status", GetStatusAsync)
            .Register("workspace_project_open_editor", _sessionTools.OpenProjectEditorAsync)
            .Register("workspace_project_close_editor", CloseProjectEditorAsync)
            .Register("workspace_project_restart_editor", RestartProjectEditorAsync);
    }

    private async Task<CentralToolCallResponse> GetStatusAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        var projectId = CentralArgumentReader.GetOptionalString(arguments, "projectId");
        var path = CentralArgumentReader.GetOptionalString(arguments, "path");
        var snapshot = await _editorLifecycleCoordinator.GetProjectStatusAsync(projectId, path, cancellationToken);
        return snapshot.Success
            ? CentralToolCallResponse.Success(snapshot.ToPayload())
            : CentralToolCallResponse.Error(snapshot.Message, snapshot.ToPayload());
    }

    private async Task<CentralToolCallResponse> CloseProjectEditorAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        var result = await _editorLifecycleCoordinator.CloseEditorAsync(
            CentralArgumentReader.GetOptionalString(arguments, "projectId"),
            CentralArgumentReader.GetOptionalString(arguments, "path"),
            CentralArgumentReader.GetBooleanOrDefault(arguments, "save", false),
            CentralArgumentReader.GetBooleanOrDefault(arguments, "force", false),
            CentralArgumentReader.GetOptionalPositiveInt(arguments, "shutdownTimeoutMs"),
            cancellationToken);

        return result.Success
            ? CentralToolCallResponse.Success(result.ToPayload())
            : CentralToolCallResponse.Error(result.Message, result.ToPayload());
    }

    private async Task<CentralToolCallResponse> RestartProjectEditorAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        var result = await _editorLifecycleCoordinator.RestartEditorAsync(
            CentralArgumentReader.GetOptionalString(arguments, "projectId"),
            CentralArgumentReader.GetOptionalString(arguments, "path"),
            CentralArgumentReader.GetBooleanOrDefault(arguments, "save", false),
            CentralArgumentReader.GetBooleanOrDefault(arguments, "force", false),
            CentralArgumentReader.GetOptionalPositiveInt(arguments, "shutdownTimeoutMs"),
            CentralArgumentReader.GetOptionalPositiveInt(arguments, "attachTimeoutMs"),
            cancellationToken);

        return result.Success
            ? CentralToolCallResponse.Success(result.ToPayload())
            : CentralToolCallResponse.Error(result.Message, result.ToPayload());
    }
}
