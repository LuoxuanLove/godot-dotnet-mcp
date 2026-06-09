namespace GodotDotnetMcp.Companion;

public enum EditorBridgeState
{
    Disabled,
    Offline,
    Online,
    VersionMismatch,
}

public sealed record EditorBridgeStatus(
    EditorBridgeState State,
    string ProjectId,
    string? EditorSessionId,
    string? PluginVersion)
{
    public static EditorBridgeStatus Disabled(string projectId)
    {
        return new EditorBridgeStatus(EditorBridgeState.Disabled, projectId, null, null);
    }

    public bool ProvidesLiveEditorState =>
        State is EditorBridgeState.Online &&
        !string.IsNullOrWhiteSpace(EditorSessionId);
}
