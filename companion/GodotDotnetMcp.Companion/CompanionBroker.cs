using System.Collections.Concurrent;

namespace GodotDotnetMcp.Companion;

public sealed class CompanionBroker
{
    public static readonly TimeSpan DefaultSessionLeaseDuration = TimeSpan.FromMinutes(30);
    public const int DefaultMaxActiveSessions = 256;
    public const int DefaultMaxActiveSessionsPerProject = 32;

    private readonly ConcurrentDictionary<string, ProjectDescriptor> _projects = new(StringComparer.Ordinal);
    private readonly ConcurrentDictionary<string, ProjectSession> _sessions = new(StringComparer.Ordinal);
    private readonly object _sessionLock = new();
    private readonly Func<DateTimeOffset> _clock;
    private readonly TimeSpan _sessionLeaseDuration;
    private readonly int _maxActiveSessions;
    private readonly int _maxActiveSessionsPerProject;

    public CompanionBroker()
        : this(DefaultSessionLeaseDuration)
    {
    }

    public CompanionBroker(
        TimeSpan sessionLeaseDuration,
        Func<DateTimeOffset>? clock = null,
        int maxActiveSessions = DefaultMaxActiveSessions,
        int maxActiveSessionsPerProject = DefaultMaxActiveSessionsPerProject)
    {
        if (sessionLeaseDuration <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(sessionLeaseDuration), "Session lease duration must be positive.");
        }

        if (maxActiveSessions <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maxActiveSessions), "Maximum active session count must be positive.");
        }

        if (maxActiveSessionsPerProject <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maxActiveSessionsPerProject), "Maximum active session count per project must be positive.");
        }

        if (maxActiveSessionsPerProject > maxActiveSessions)
        {
            throw new ArgumentOutOfRangeException(nameof(maxActiveSessionsPerProject), "Per-project session limit cannot exceed the global session limit.");
        }

        _sessionLeaseDuration = sessionLeaseDuration;
        _clock = clock ?? (() => DateTimeOffset.UtcNow);
        _maxActiveSessions = maxActiveSessions;
        _maxActiveSessionsPerProject = maxActiveSessionsPerProject;
    }

    public IReadOnlyCollection<ProjectDescriptor> Projects => _projects.Values.ToArray();

    public IReadOnlyCollection<ProjectSessionIdentity> Sessions
    {
        get
        {
            RemoveInactiveSessions();
            var nowUtc = _clock();
            var identities = new List<ProjectSessionIdentity>();
            foreach (var session in _sessions.Values)
            {
                if (session.TryGetActiveIdentity(nowUtc, out var identity))
                {
                    identities.Add(identity);
                }
            }

            return identities.ToArray();
        }
    }

    public ProjectDescriptor RegisterProject(ProjectDescriptor project)
    {
        ArgumentNullException.ThrowIfNull(project);
        var verifiedProject = ProjectDescriptor.FromRoot(project.ProjectRoot, project.ProjectFilePath);
        return _projects.GetOrAdd(verifiedProject.ProjectId, verifiedProject);
    }

    public ProjectDescriptor RegisterProject(string projectRoot, string? projectFilePath = null)
    {
        var project = ProjectDescriptor.FromRoot(projectRoot, projectFilePath);
        return _projects.GetOrAdd(project.ProjectId, project);
    }

    public ProjectSession StartSession(string projectId)
    {
        if (string.IsNullOrWhiteSpace(projectId))
        {
            throw new ArgumentException("project_id is required.", nameof(projectId));
        }

        if (!_projects.TryGetValue(projectId, out var project))
        {
            throw new KeyNotFoundException($"Unknown project_id: {projectId}");
        }

        lock (_sessionLock)
        {
            RemoveInactiveSessions();
            var nowUtc = _clock();
            var activeSessionCount = 0;
            var activeProjectSessionCount = 0;
            foreach (var currentSession in _sessions.Values)
            {
                if (!currentSession.TryGetActiveIdentity(nowUtc, out var identity))
                {
                    continue;
                }

                activeSessionCount++;
                if (string.Equals(identity.ProjectId, project.ProjectId, StringComparison.Ordinal))
                {
                    activeProjectSessionCount++;
                }
            }

            if (activeSessionCount >= _maxActiveSessions)
            {
                throw new InvalidOperationException("Global active project session limit has been reached.");
            }

            if (activeProjectSessionCount >= _maxActiveSessionsPerProject)
            {
                throw new InvalidOperationException("Project active session limit has been reached.");
            }

            var session = new ProjectSession(project, "session_" + Guid.NewGuid().ToString("N"), nowUtc, _sessionLeaseDuration, _clock);
            _sessions[session.Identity.SessionId] = session;
            return session;
        }
    }

    public bool StopSession(ToolRequestScope scope)
    {
        var session = ResolveSession(scope, renewLease: false);
        session.Revoke(_clock());
        return _sessions.TryRemove(scope.SessionId, out _);
    }

    public ProjectSession RenewSession(ToolRequestScope scope)
    {
        return ResolveSession(scope);
    }

    public ProjectSession ResolveSession(ToolRequestScope scope)
    {
        return ResolveSession(scope, renewLease: true);
    }

    private ProjectSession ResolveSession(ToolRequestScope scope, bool renewLease)
    {
        if (string.IsNullOrWhiteSpace(scope.ProjectId))
        {
            throw new ArgumentException("Tool calls must include project_id.", nameof(scope));
        }

        if (string.IsNullOrWhiteSpace(scope.SessionId))
        {
            throw new ArgumentException("Tool calls must include session_id.", nameof(scope));
        }

        if (!_sessions.TryGetValue(scope.SessionId, out var session))
        {
            throw new KeyNotFoundException($"Unknown session_id: {scope.SessionId}");
        }

        if (!string.Equals(session.Identity.ProjectId, scope.ProjectId, StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Tool call project_id does not match the resolved session.");
        }

        var nowUtc = _clock();
        if (session.IsExpired(nowUtc))
        {
            _sessions.TryRemove(scope.SessionId, out _);
            throw new InvalidOperationException("Project session lease has expired.");
        }

        session.EnsureActive(nowUtc);
        if (renewLease)
        {
            session.Touch(nowUtc, _sessionLeaseDuration);
        }

        return session;
    }

    private void RemoveInactiveSessions()
    {
        var nowUtc = _clock();
        foreach (var (sessionId, session) in _sessions)
        {
            if (!session.IsActive(nowUtc))
            {
                _sessions.TryRemove(sessionId, out _);
            }
        }
    }

    public void RequireCapability(ToolRequestScope scope, CompanionCapability capability)
    {
        var session = ResolveSession(scope);
        if (!session.HasCapability(capability))
        {
            throw new InvalidOperationException($"Capability '{capability}' is unavailable in {session.Identity.Mode} mode.");
        }
    }
}

public sealed record ToolRequestScope(string ProjectId, string SessionId);
