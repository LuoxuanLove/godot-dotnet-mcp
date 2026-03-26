using System.Text.Json;
using System.Text.Json.Nodes;

namespace GodotDotnetMcp.CentralServer;

internal sealed class CentralHostSessionPayloadFactory
{
    private readonly EditorLifecycleCoordinator _editorLifecycleCoordinator;
    private readonly EditorSessionCoordinator _editorSessionCoordinator;
    private readonly CentralWorkspaceState _workspaceState;

    public CentralHostSessionPayloadFactory(
        EditorLifecycleCoordinator editorLifecycleCoordinator,
        EditorSessionCoordinator editorSessionCoordinator,
        CentralWorkspaceState workspaceState)
    {
        _editorLifecycleCoordinator = editorLifecycleCoordinator;
        _editorSessionCoordinator = editorSessionCoordinator;
        _workspaceState = workspaceState;
    }

    public object Build(
        EnsureEditorSessionResult coordination,
        string endpoint,
        string toolName)
    {
        var resolution = GetResolution(coordination);
        var workspaceState = _workspaceState.Snapshot();
        var process = coordination.Project is null
            ? coordination.Editor
            : coordination.Editor
              ?? _editorLifecycleCoordinator.GetEffectiveProcessStatus(
                  coordination.Project.ProjectId,
                  coordination.Project.ProjectRoot,
                  coordination.Session);

        return new
        {
            toolName,
            activeProjectId = workspaceState.ActiveProjectId,
            activeEditorSessionId = workspaceState.ActiveEditorSessionId,
            endpoint,
            attachHost = _editorSessionCoordinator.AttachEndpoint.Host,
            attachPort = _editorSessionCoordinator.AttachEndpoint.Port,
            attachTimeoutMs = coordination.AttachTimeoutMs,
            autoLaunchAttempted = coordination.AutoLaunchAttempted,
            editorLifecycle = _editorLifecycleCoordinator.BuildLifecycleSummary(
                toolName,
                coordination.Project,
                coordination.Session,
                process,
                resolution),
        };
    }

    public string GetResolution(EnsureEditorSessionResult coordination)
    {
        return ResolveCoordinationResolution(coordination);
    }

    public object BuildFailurePayload(
        EnsureEditorSessionResult coordination,
        string toolName)
    {
        return AttachToResult(
            coordination.ToErrorPayload(),
            Build(coordination, string.Empty, toolName));
    }

    public object AttachToResult(object toolResult, object centralHostSession)
    {
        var centralHostSessionNode = JsonSerializer.SerializeToNode(centralHostSession, CentralServerSerialization.JsonOptions);
        var resultNode = JsonSerializer.SerializeToNode(toolResult, CentralServerSerialization.JsonOptions);
        if (resultNode is JsonObject resultObject)
        {
            resultObject["centralHostSession"] = centralHostSessionNode;
            return resultObject;
        }

        return new JsonObject
        {
            ["result"] = resultNode,
            ["centralHostSession"] = centralHostSessionNode,
        };
    }

    private static string ResolveCoordinationResolution(EnsureEditorSessionResult coordination)
    {
        if (!coordination.Success)
        {
            return string.IsNullOrWhiteSpace(coordination.ErrorType)
                ? "editor_unavailable"
                : coordination.ErrorType;
        }

        return coordination.ReusedRunningEditor
               || coordination.Launch?.AlreadyRunning == true
            ? "reused_running_editor"
            : coordination.AutoLaunchAttempted
                ? "launched_editor"
                : "reused_ready_session";
    }
}
