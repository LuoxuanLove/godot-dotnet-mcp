using System.Collections.Concurrent;

namespace GodotDotnetMcp.Companion;

public sealed class CompanionBroker
{
    private readonly ConcurrentDictionary<string, ProjectDescriptor> _projects = new(StringComparer.Ordinal);
    private readonly ConcurrentDictionary<string, ProjectSession> _sessions = new(StringComparer.Ordinal);

    public IReadOnlyCollection<ProjectDescriptor> Projects => _projects.Values.ToArray();

    public IReadOnlyCollection<ProjectSessionIdentity> Sessions =>
        _sessions.Values.Select(session => session.Identity).ToArray();

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

        var session = new ProjectSession(project, "session_" + Guid.NewGuid().ToString("N"));
        _sessions[session.Identity.SessionId] = session;
        return session;
    }

    public ProjectSession ResolveSession(ToolRequestScope scope)
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

        return session;
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
