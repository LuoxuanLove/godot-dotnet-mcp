using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorAttachedToolForwardingService
{
    private readonly EditorProxyService _editorProxy;
    private readonly EditorSessionCoordinator _editorSessionCoordinator;
    private readonly CentralHostSessionPayloadFactory _hostSessionPayloadFactory;

    public EditorAttachedToolForwardingService(
        EditorProxyService editorProxy,
        EditorSessionCoordinator editorSessionCoordinator,
        CentralHostSessionPayloadFactory hostSessionPayloadFactory)
    {
        _editorProxy = editorProxy;
        _editorSessionCoordinator = editorSessionCoordinator;
        _hostSessionPayloadFactory = hostSessionPayloadFactory;
    }

    public async Task<CentralToolCallResponse> ExecuteSystemToolAsync(
        string toolName,
        JsonElement arguments,
        CancellationToken cancellationToken)
    {
        var projectId = CentralArgumentReader.GetOptionalString(arguments, "projectId");
        var projectPath = CentralArgumentReader.GetOptionalString(arguments, "projectPath");
        var autoLaunchEditor = CentralArgumentReader.GetBooleanOrDefault(arguments, "autoLaunchEditor", true);
        var attachTimeoutMs = CentralArgumentReader.GetOptionalPositiveInt(arguments, "editorAttachTimeoutMs");

        var coordination = await _editorSessionCoordinator.EnsureHttpReadySessionAsync(
            toolName,
            projectId,
            projectPath,
            autoLaunchEditor,
            attachTimeoutMs,
            explicitExecutablePath: null,
            launchReason: "system_auto_launch",
            cancellationToken: cancellationToken);

        if (!coordination.Success || coordination.Project is null || coordination.Session is null)
        {
            return CentralToolCallResponse.Error(
                coordination.Message,
                _hostSessionPayloadFactory.BuildFailurePayload(coordination, toolName));
        }

        var forwarded = await _editorProxy.ForwardToolCallAsync(coordination.Session, toolName, arguments, cancellationToken);
        var centralHostSession = _hostSessionPayloadFactory.Build(coordination, forwarded.Endpoint, toolName);
        if (forwarded.Success)
        {
            return CentralToolCallResponse.Success(
                _hostSessionPayloadFactory.AttachToResult(forwarded.ToolResult ?? new { success = true }, centralHostSession));
        }

        return CentralToolCallResponse.Error(
            "Forwarded editor tool failed.",
            _hostSessionPayloadFactory.AttachToResult(
                forwarded.ToolResult ?? new
                {
                    error = "editor_tool_failed",
                    toolName,
                    project = coordination.Project,
                    editorSession = coordination.Session,
                    launch = coordination.Launch,
                },
                centralHostSession));
    }
}
