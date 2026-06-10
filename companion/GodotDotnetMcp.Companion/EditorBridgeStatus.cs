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
    string? PluginVersion,
    bool SupportsLiveEditorState)
{
    public static EditorBridgeStatus Disabled(string projectId)
    {
        return new EditorBridgeStatus(EditorBridgeState.Disabled, projectId, null, null, false);
    }

    public bool ProvidesLiveEditorState =>
        State is EditorBridgeState.Online &&
        SupportsLiveEditorState &&
        !string.IsNullOrWhiteSpace(EditorSessionId);
}
