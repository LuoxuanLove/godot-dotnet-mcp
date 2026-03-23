namespace GodotDotnetMcp.CentralServer;

internal sealed class SessionState
{
    public string ActiveProjectId { get; set; } = string.Empty;

    public string ActiveEditorSessionId { get; set; } = string.Empty;
}
