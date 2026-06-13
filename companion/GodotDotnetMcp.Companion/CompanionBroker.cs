using System.Collections.Concurrent;

namespace GodotDotnetMcp.Companion;

public sealed class CompanionBroker
{
    public static readonly TimeSpan DefaultSessionLeaseDuration = TimeSpan.FromMinutes(30);
    public const int DefaultMaxActiveSessions = 256;
    public const int DefaultMaxActiveSessionsPerProject = 32;

    private readonly ConcurrentDictionary<string, ProjectDescriptor> _projects = new(StringComparer.Ordinal);
    private readonly ConcurrentDictionary<string, ProjectSession> _sessions = new(StringComparer.Ordinal);
    private readonly ConcurrentDictionary<string, EditorBridgeStatus> _editorBridgeStatuses = new(StringComparer.Ordinal);
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

    public IReadOnlyCollection<BrokerProjectSummary> ListProjects()
    {
        var nowUtc = _clock();
        var activeSessionCounts = new Dictionary<string, int>(StringComparer.Ordinal);
        var staticHeadlessSessionCounts = new Dictionary<string, int>(StringComparer.Ordinal);
        var editorLiveSessionCounts = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var session in _sessions.Values)
        {
            if (!session.TryGetActiveIdentity(nowUtc, out var identity))
            {
                continue;
            }

            Increment(activeSessionCounts, identity.ProjectId);
            if (identity.Mode is CompanionMode.EditorLive)
            {
                Increment(editorLiveSessionCounts, identity.ProjectId);
            }
            else
            {
                Increment(staticHeadlessSessionCounts, identity.ProjectId);
            }
        }

        return _projects.Values
            .OrderBy(project => project.ProjectId, StringComparer.Ordinal)
            .Select(project =>
            {
                activeSessionCounts.TryGetValue(project.ProjectId, out var activeSessionCount);
                staticHeadlessSessionCounts.TryGetValue(project.ProjectId, out var staticHeadlessSessionCount);
                editorLiveSessionCounts.TryGetValue(project.ProjectId, out var editorLiveSessionCount);
                return new BrokerProjectSummary(
                    project.ProjectId,
                    project.ProjectRoot,
                    project.ProjectFilePath,
                    ProjectFileScoped: project.ProjectFilePath is not null,
                    activeSessionCount,
                    staticHeadlessSessionCount,
                    editorLiveSessionCount);
            })
            .ToArray();
    }

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

    public IReadOnlyCollection<ProjectSessionIdentity> ListProjectSessions(string projectId)
    {
        if (string.IsNullOrWhiteSpace(projectId))
        {
            throw new ArgumentException("project_id is required.", nameof(projectId));
        }

        if (!_projects.ContainsKey(projectId))
        {
            throw new KeyNotFoundException($"Unknown project_id: {projectId}");
        }

        RemoveInactiveSessions();
        var nowUtc = _clock();
        var identities = new List<ProjectSessionIdentity>();
        foreach (var session in _sessions.Values)
        {
            if (!session.TryGetActiveIdentity(nowUtc, out var identity))
            {
                continue;
            }

            if (string.Equals(identity.ProjectId, projectId, StringComparison.Ordinal))
            {
                identities.Add(identity);
            }
        }

        return identities
            .OrderBy(identity => identity.SessionId, StringComparer.Ordinal)
            .ToArray();
    }

    public EditorBridgeStatus GetEditorBridgeStatus(string projectId)
    {
        if (string.IsNullOrWhiteSpace(projectId))
        {
            throw new ArgumentException("project_id is required.", nameof(projectId));
        }

        if (!_projects.ContainsKey(projectId))
        {
            throw new KeyNotFoundException($"Unknown project_id: {projectId}");
        }

        return _editorBridgeStatuses.TryGetValue(projectId, out var status)
            ? status
            : EditorBridgeStatus.Disabled(projectId);
    }

    public EditorBridgeStatus UpdateEditorBridgeStatus(EditorBridgeStatus bridgeStatus)
    {
        ArgumentNullException.ThrowIfNull(bridgeStatus);
        if (string.IsNullOrWhiteSpace(bridgeStatus.ProjectId))
        {
            throw new ArgumentException("Editor bridge status must include project_id.", nameof(bridgeStatus));
        }

        if (!_projects.ContainsKey(bridgeStatus.ProjectId))
        {
            throw new KeyNotFoundException($"Unknown project_id: {bridgeStatus.ProjectId}");
        }

        _editorBridgeStatuses[bridgeStatus.ProjectId] = bridgeStatus;
        return bridgeStatus;
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

    public bool RemoveProject(string projectId)
    {
        if (string.IsNullOrWhiteSpace(projectId))
        {
            throw new ArgumentException("project_id is required.", nameof(projectId));
        }

        lock (_sessionLock)
        {
            if (!_projects.TryRemove(projectId, out _))
            {
                return false;
            }

            _editorBridgeStatuses.TryRemove(projectId, out _);
            var nowUtc = _clock();
            foreach (var (sessionId, session) in _sessions)
            {
                if (string.Equals(session.Identity.ProjectId, projectId, StringComparison.Ordinal))
                {
                    session.Revoke(nowUtc);
                    _sessions.TryRemove(sessionId, out _);
                }
            }

            return true;
        }
    }

    public ProjectSession StartSession(string projectId)
    {
        if (string.IsNullOrWhiteSpace(projectId))
        {
            throw new ArgumentException("project_id is required.", nameof(projectId));
        }

        lock (_sessionLock)
        {
            RemoveInactiveSessions();
            if (!_projects.TryGetValue(projectId, out var project))
            {
                throw new KeyNotFoundException($"Unknown project_id: {projectId}");
            }

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

    public ToolScopeValidationResult ValidateToolScope(
        ToolRequestScope scope,
        CompanionCapability? requiredCapability = null)
    {
        if (string.IsNullOrWhiteSpace(scope.ProjectId))
        {
            return ToolScopeValidationResult.CreateRejected(
                ToolScopeValidationReason.MissingProjectId,
                "Tool calls must include project_id.");
        }

        if (string.IsNullOrWhiteSpace(scope.SessionId))
        {
            return ToolScopeValidationResult.CreateRejected(
                ToolScopeValidationReason.MissingSessionId,
                "Tool calls must include session_id.");
        }

        if (!_sessions.TryGetValue(scope.SessionId, out var session))
        {
            return ToolScopeValidationResult.CreateRejected(
                ToolScopeValidationReason.UnknownSessionId,
                $"Unknown session_id: {scope.SessionId}");
        }

        if (!string.Equals(session.Identity.ProjectId, scope.ProjectId, StringComparison.Ordinal))
        {
            return ToolScopeValidationResult.CreateRejected(
                ToolScopeValidationReason.ProjectSessionMismatch,
                "Tool call project_id does not match the resolved session.",
                session.Identity);
        }

        var nowUtc = _clock();
        if (session.IsExpired(nowUtc))
        {
            return ToolScopeValidationResult.CreateRejected(
                ToolScopeValidationReason.ExpiredSession,
                "Project session lease has expired.",
                session.Identity);
        }

        if (!session.IsActive(nowUtc))
        {
            return ToolScopeValidationResult.CreateRejected(
                ToolScopeValidationReason.InactiveSession,
                "Project session is not active.",
                session.Identity);
        }

        if (requiredCapability is not null && !session.HasCapability(requiredCapability.Value, nowUtc))
        {
            return ToolScopeValidationResult.CreateRejected(
                ToolScopeValidationReason.CapabilityUnavailable,
                $"Capability '{requiredCapability}' is unavailable in {session.Identity.Mode} mode.",
                session.Identity);
        }

        return ToolScopeValidationResult.CreateAccepted(session.Identity);
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

    private static void Increment(Dictionary<string, int> counts, string projectId)
    {
        counts.TryGetValue(projectId, out var currentCount);
        counts[projectId] = currentCount + 1;
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

public sealed record BrokerProjectSummary(
    string ProjectId,
    string ProjectRoot,
    string? ProjectFilePath,
    bool ProjectFileScoped,
    int ActiveSessionCount,
    int StaticHeadlessSessionCount,
    int EditorLiveSessionCount);

public sealed record BrokerLifecycleOptions(
    bool EnabledByDefault = false,
    bool StartsBackgroundProcess = false,
    bool OpensListeningPort = false,
    bool LaunchesGodotEditor = false,
    bool RequiresExplicitStart = true,
    bool RequiresExplicitEditorLaunch = true)
{
    public static BrokerLifecycleOptions Default { get; } = new();

    public void Validate()
    {
        if (EnabledByDefault)
        {
            throw new InvalidOperationException("Broker lifecycle must be disabled by default.");
        }

        if (StartsBackgroundProcess)
        {
            throw new InvalidOperationException("Broker lifecycle must not start a background process by default.");
        }

        if (OpensListeningPort)
        {
            throw new InvalidOperationException("Broker lifecycle must not open a listening port by default.");
        }

        if (LaunchesGodotEditor)
        {
            throw new InvalidOperationException("Broker lifecycle must not launch Godot by default.");
        }

        if (!RequiresExplicitStart)
        {
            throw new InvalidOperationException("Broker lifecycle must require explicit start.");
        }

        if (!RequiresExplicitEditorLaunch)
        {
            throw new InvalidOperationException("Broker lifecycle must require explicit editor launch.");
        }
    }
}

public enum BrokerTransportMode
{
    Stdio,
    HttpLoopback,
}

public sealed record BrokerTransportOptions(
    BrokerTransportMode Mode = BrokerTransportMode.Stdio,
    bool HttpLoopbackEnabled = false,
    string HttpLoopbackHost = "127.0.0.1",
    int? HttpLoopbackPort = null)
{
    public static BrokerTransportOptions Default { get; } = new();

    public static BrokerTransportOptions CreateStdio()
    {
        return Default;
    }

    public static BrokerTransportOptions CreateHttpLoopback(int port, string host = "127.0.0.1")
    {
        return new BrokerTransportOptions(
            BrokerTransportMode.HttpLoopback,
            HttpLoopbackEnabled: true,
            HttpLoopbackHost: host,
            HttpLoopbackPort: port);
    }

    public void Validate()
    {
        if (!Enum.IsDefined(Mode))
        {
            throw new ArgumentOutOfRangeException(nameof(Mode), "Broker transport mode is not supported.");
        }

        if (string.IsNullOrWhiteSpace(HttpLoopbackHost))
        {
            throw new ArgumentException("HTTP loopback host is required.", nameof(HttpLoopbackHost));
        }

        if (Mode is BrokerTransportMode.Stdio)
        {
            if (HttpLoopbackEnabled)
            {
                throw new InvalidOperationException("HTTP loopback transport must be disabled for stdio mode.");
            }

            if (HttpLoopbackPort is not null)
            {
                throw new InvalidOperationException("HTTP loopback port must not be set for stdio mode.");
            }

            return;
        }

        if (!HttpLoopbackEnabled)
        {
            throw new InvalidOperationException("HTTP loopback transport requires explicit enablement.");
        }

        if (!string.Equals(HttpLoopbackHost, "127.0.0.1", StringComparison.Ordinal))
        {
            throw new InvalidOperationException("HTTP loopback transport must bind to 127.0.0.1.");
        }

        if (HttpLoopbackPort is null or < 1 or > 65535)
        {
            throw new InvalidOperationException("HTTP loopback transport requires an explicit TCP port from 1 through 65535.");
        }
    }
}

public sealed record ToolRequestScope(string ProjectId, string SessionId);

public enum ToolScopeValidationReason
{
    Accepted,
    MissingProjectId,
    MissingSessionId,
    UnknownSessionId,
    ProjectSessionMismatch,
    ExpiredSession,
    InactiveSession,
    CapabilityUnavailable,
}

public sealed record ToolScopeValidationResult(
    bool Accepted,
    ToolScopeValidationReason Reason,
    string Message,
    ProjectSessionIdentity? Session)
{
    public static ToolScopeValidationResult CreateAccepted(ProjectSessionIdentity session)
    {
        return new ToolScopeValidationResult(true, ToolScopeValidationReason.Accepted, "Tool scope is valid.", session);
    }

    public static ToolScopeValidationResult CreateRejected(
        ToolScopeValidationReason reason,
        string message,
        ProjectSessionIdentity? session = null)
    {
        if (reason is ToolScopeValidationReason.Accepted)
        {
            throw new ArgumentException("Accepted validation results must use the CreateAccepted factory.", nameof(reason));
        }

        return new ToolScopeValidationResult(false, reason, message, session);
    }
}
