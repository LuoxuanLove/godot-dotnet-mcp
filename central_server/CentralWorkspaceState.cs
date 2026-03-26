namespace GodotDotnetMcp.CentralServer;

internal readonly record struct WorkspaceStateSnapshot(
    string ActiveProjectId,
    string ActiveEditorSessionId);

internal sealed class CentralWorkspaceState
{
    private readonly object _gate = new();
    private string _activeProjectId = string.Empty;
    private string _activeEditorSessionId = string.Empty;

    public string ActiveProjectId
    {
        get
        {
            lock (_gate)
            {
                return _activeProjectId;
            }
        }
    }

    public string ActiveEditorSessionId
    {
        get
        {
            lock (_gate)
            {
                return _activeEditorSessionId;
            }
        }
    }

    public WorkspaceStateSnapshot Snapshot()
    {
        lock (_gate)
        {
            return new WorkspaceStateSnapshot(_activeProjectId, _activeEditorSessionId);
        }
    }

    public void SetActiveProject(string projectId)
    {
        lock (_gate)
        {
            _activeProjectId = Normalize(projectId);
        }
    }

    public void ClearActiveProject()
    {
        lock (_gate)
        {
            _activeProjectId = string.Empty;
        }
    }

    public void SetActiveEditorSession(string sessionId)
    {
        lock (_gate)
        {
            _activeEditorSessionId = Normalize(sessionId);
        }
    }

    public void ClearActiveEditorSession()
    {
        lock (_gate)
        {
            _activeEditorSessionId = string.Empty;
        }
    }

    private static string Normalize(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? string.Empty : value.Trim();
    }
}
