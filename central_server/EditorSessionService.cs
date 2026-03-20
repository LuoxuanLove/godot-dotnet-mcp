namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorSessionService
{
    private readonly ProjectRegistryService _registry;
    private readonly Dictionary<string, EditorSessionEntry> _sessions = new(StringComparer.OrdinalIgnoreCase);
    private readonly TimeSpan _staleTimeout = TimeSpan.FromSeconds(30);

    public EditorSessionService(ProjectRegistryService registry)
    {
        _registry = registry;
    }

    public EditorSessionAttachResult Attach(EditorSessionAttachRequest request)
    {
        var project = ResolveOrRegisterProject(request);
        var now = DateTimeOffset.UtcNow;
        var sessionId = string.IsNullOrWhiteSpace(request.SessionId)
            ? Guid.NewGuid().ToString("N")
            : request.SessionId.Trim();

        var entry = new EditorSessionEntry
        {
            ProjectId = project.ProjectId,
            ProjectName = project.ProjectName,
            ProjectRoot = project.ProjectRoot,
            SessionId = sessionId,
            PluginVersion = request.PluginVersion ?? string.Empty,
            GodotVersion = request.GodotVersion ?? string.Empty,
            Capabilities = request.Capabilities ?? [],
            AttachedAtUtc = now,
            LastHeartbeatAtUtc = now,
            Status = "attached",
            LastError = string.Empty,
            TransportMode = request.TransportMode ?? string.Empty,
            ServerHost = request.ServerHost ?? string.Empty,
            ServerPort = request.ServerPort,
            ServerRunning = request.ServerRunning ?? false,
        };

        _sessions[project.ProjectId] = entry;

        return new EditorSessionAttachResult
        {
            Success = true,
            ProjectId = project.ProjectId,
            ProjectName = project.ProjectName,
            ProjectRoot = project.ProjectRoot,
            SessionId = sessionId,
            AttachedAtUtc = now,
            Status = entry.Status,
        };
    }

    public EditorSessionHeartbeatResult Heartbeat(EditorSessionHeartbeatRequest request)
    {
        var entry = ResolveSession(request.ProjectId, request.ProjectRoot, request.SessionId);
        entry.LastHeartbeatAtUtc = DateTimeOffset.UtcNow;
        entry.Status = "attached";
        entry.LastError = string.Empty;
        entry.TransportMode = request.TransportMode ?? entry.TransportMode;
        entry.ServerHost = request.ServerHost ?? entry.ServerHost;
        entry.ServerPort = request.ServerPort ?? entry.ServerPort;
        entry.ServerRunning = request.ServerRunning ?? entry.ServerRunning;

        return new EditorSessionHeartbeatResult
        {
            Success = true,
            ProjectId = entry.ProjectId,
            SessionId = entry.SessionId,
            LastHeartbeatAtUtc = entry.LastHeartbeatAtUtc,
            Status = entry.Status,
        };
    }

    public EditorSessionDetachResult Detach(EditorSessionDetachRequest request)
    {
        var entry = ResolveSession(request.ProjectId, request.ProjectRoot, request.SessionId);
        _sessions.Remove(entry.ProjectId);

        return new EditorSessionDetachResult
        {
            Success = true,
            ProjectId = entry.ProjectId,
            SessionId = entry.SessionId,
            DetachedAtUtc = DateTimeOffset.UtcNow,
            Status = "detached",
        };
    }

    public EditorSessionStatus GetStatus(string projectId)
    {
        PruneStaleSessions();
        if (!_sessions.TryGetValue(projectId, out var entry))
        {
            return new EditorSessionStatus
            {
                ProjectId = projectId,
                Attached = false,
                Status = "detached",
            };
        }

        return BuildStatus(entry, attached: true);
    }

    public IReadOnlyList<EditorSessionStatus> ListSessions()
    {
        PruneStaleSessions();
        return _sessions.Values
            .OrderBy(entry => entry.ProjectName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(entry => entry.ProjectRoot, StringComparer.OrdinalIgnoreCase)
            .Select(entry => BuildStatus(entry, attached: true))
            .ToArray();
    }

    private void PruneStaleSessions()
    {
        var cutoff = DateTimeOffset.UtcNow - _staleTimeout;
        var staleProjectIds = _sessions.Values
            .Where(entry => entry.LastHeartbeatAtUtc < cutoff)
            .Select(entry => entry.ProjectId)
            .ToArray();

        foreach (var projectId in staleProjectIds)
        {
            _sessions.Remove(projectId);
        }
    }

    private ProjectRegistryService.RegisteredProject ResolveOrRegisterProject(EditorSessionAttachRequest request)
    {
        var project = _registry.ResolveProject(request.ProjectId, request.ProjectRoot);
        if (project is not null)
        {
            return project;
        }

        if (string.IsNullOrWhiteSpace(request.ProjectRoot))
        {
            throw new CentralToolException("Editor attach requires projectId or projectRoot.");
        }

        return _registry.RegisterProject(request.ProjectRoot, "editor_attach");
    }

    private EditorSessionEntry ResolveSession(string? projectId, string? projectRoot, string? sessionId)
    {
        PruneStaleSessions();

        var project = _registry.ResolveProject(projectId, projectRoot);
        if (project is null)
        {
            throw new CentralToolException("Registered project not found for editor session.");
        }

        if (!_sessions.TryGetValue(project.ProjectId, out var entry))
        {
            throw new CentralToolException("Active editor session not found.");
        }

        if (!string.IsNullOrWhiteSpace(sessionId)
            && !string.Equals(entry.SessionId, sessionId.Trim(), StringComparison.OrdinalIgnoreCase))
        {
            throw new CentralToolException("Editor session id does not match the active session.");
        }

        return entry;
    }

    private static EditorSessionStatus BuildStatus(EditorSessionEntry entry, bool attached)
    {
        return new EditorSessionStatus
        {
            ProjectId = entry.ProjectId,
            ProjectName = entry.ProjectName,
            ProjectRoot = entry.ProjectRoot,
            SessionId = entry.SessionId,
            PluginVersion = entry.PluginVersion,
            GodotVersion = entry.GodotVersion,
            Capabilities = entry.Capabilities,
            Attached = attached,
            Status = attached ? entry.Status : "detached",
            AttachedAtUtc = entry.AttachedAtUtc,
            LastHeartbeatAtUtc = entry.LastHeartbeatAtUtc,
            LastError = entry.LastError,
            TransportMode = entry.TransportMode,
            ServerHost = entry.ServerHost,
            ServerPort = entry.ServerPort,
            ServerRunning = entry.ServerRunning,
        };
    }

    internal sealed class EditorSessionAttachRequest
    {
        public string? ProjectId { get; set; }

        public string? ProjectRoot { get; set; }

        public string? SessionId { get; set; }

        public string? PluginVersion { get; set; }

        public string? GodotVersion { get; set; }

        public string[]? Capabilities { get; set; }

        public string? TransportMode { get; set; }

        public string? ServerHost { get; set; }

        public int? ServerPort { get; set; }

        public bool? ServerRunning { get; set; }
    }

    internal sealed class EditorSessionHeartbeatRequest
    {
        public string? ProjectId { get; set; }

        public string? ProjectRoot { get; set; }

        public string? SessionId { get; set; }

        public string? TransportMode { get; set; }

        public string? ServerHost { get; set; }

        public int? ServerPort { get; set; }

        public bool? ServerRunning { get; set; }
    }

    internal sealed class EditorSessionDetachRequest
    {
        public string? ProjectId { get; set; }

        public string? ProjectRoot { get; set; }

        public string? SessionId { get; set; }
    }

    internal sealed class EditorSessionAttachResult
    {
        public bool Success { get; set; }

        public string ProjectId { get; set; } = string.Empty;

        public string ProjectName { get; set; } = string.Empty;

        public string ProjectRoot { get; set; } = string.Empty;

        public string SessionId { get; set; } = string.Empty;

        public DateTimeOffset AttachedAtUtc { get; set; }

        public string Status { get; set; } = string.Empty;
    }

    internal sealed class EditorSessionHeartbeatResult
    {
        public bool Success { get; set; }

        public string ProjectId { get; set; } = string.Empty;

        public string SessionId { get; set; } = string.Empty;

        public DateTimeOffset LastHeartbeatAtUtc { get; set; }

        public string Status { get; set; } = string.Empty;
    }

    internal sealed class EditorSessionDetachResult
    {
        public bool Success { get; set; }

        public string ProjectId { get; set; } = string.Empty;

        public string SessionId { get; set; } = string.Empty;

        public DateTimeOffset DetachedAtUtc { get; set; }

        public string Status { get; set; } = string.Empty;
    }

    internal sealed class EditorSessionStatus
    {
        public string ProjectId { get; set; } = string.Empty;

        public string ProjectName { get; set; } = string.Empty;

        public string ProjectRoot { get; set; } = string.Empty;

        public string SessionId { get; set; } = string.Empty;

        public string PluginVersion { get; set; } = string.Empty;

        public string GodotVersion { get; set; } = string.Empty;

        public string[] Capabilities { get; set; } = [];

        public bool Attached { get; set; }

        public string Status { get; set; } = string.Empty;

        public DateTimeOffset? AttachedAtUtc { get; set; }

        public DateTimeOffset? LastHeartbeatAtUtc { get; set; }

        public string LastError { get; set; } = string.Empty;

        public string TransportMode { get; set; } = string.Empty;

        public string ServerHost { get; set; } = string.Empty;

        public int? ServerPort { get; set; }

        public bool ServerRunning { get; set; }
    }

    private sealed class EditorSessionEntry
    {
        public string ProjectId { get; set; } = string.Empty;

        public string ProjectName { get; set; } = string.Empty;

        public string ProjectRoot { get; set; } = string.Empty;

        public string SessionId { get; set; } = string.Empty;

        public string PluginVersion { get; set; } = string.Empty;

        public string GodotVersion { get; set; } = string.Empty;

        public string[] Capabilities { get; set; } = [];

        public string Status { get; set; } = string.Empty;

        public string LastError { get; set; } = string.Empty;

        public string TransportMode { get; set; } = string.Empty;

        public string ServerHost { get; set; } = string.Empty;

        public int? ServerPort { get; set; }

        public bool ServerRunning { get; set; }

        public DateTimeOffset AttachedAtUtc { get; set; }

        public DateTimeOffset LastHeartbeatAtUtc { get; set; }
    }
}
