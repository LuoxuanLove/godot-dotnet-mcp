namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorLifecycleSummaryBuilder
{
    private readonly string _residencyStorePath;

    public EditorLifecycleSummaryBuilder(string residencyStorePath)
    {
        _residencyStorePath = residencyStorePath;
    }

    public Dictionary<string, object?> BuildLifecycleSummary(
        string toolName,
        ProjectRegistryService.RegisteredProject? project,
        EditorSessionService.EditorSessionStatus? session,
        EditorProcessService.EditorProcessStatus? process,
        string resolution,
        Dictionary<string, object?>? editorState = null)
    {
        var processStatus = process ?? EditorProcessService.EditorProcessStatus.Empty(project?.ProjectId ?? string.Empty, _residencyStorePath);
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

    public static string ResolveStatusResolution(
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
}
