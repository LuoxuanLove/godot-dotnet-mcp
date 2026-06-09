using System.Security.Cryptography;
using System.Text;

namespace GodotDotnetMcp.Companion;

public sealed record ProjectDescriptor
{
    private ProjectDescriptor(
        string projectId,
        string projectRoot,
        string? projectFilePath)
    {
        ProjectId = projectId;
        ProjectRoot = projectRoot;
        ProjectFilePath = projectFilePath;
    }

    public string ProjectId { get; }
    public string ProjectRoot { get; }
    public string? ProjectFilePath { get; }

    public static ProjectDescriptor FromRoot(string projectRoot, string? projectFilePath = null)
    {
        if (string.IsNullOrWhiteSpace(projectRoot))
        {
            throw new ArgumentException("Project root is required.", nameof(projectRoot));
        }

        var normalizedRoot = Path.GetFullPath(projectRoot);
        if (!File.Exists(Path.Combine(normalizedRoot, "project.godot")))
        {
            throw new ArgumentException("Project root must contain project.godot.", nameof(projectRoot));
        }

        var normalizedProjectFile = string.IsNullOrWhiteSpace(projectFilePath)
            ? null
            : Path.GetFullPath(projectFilePath, normalizedRoot);

        if (normalizedProjectFile is not null && !IsInside(normalizedRoot, normalizedProjectFile))
        {
            throw new ArgumentException("Project file path must stay inside the project root.", nameof(projectFilePath));
        }

        if (normalizedProjectFile is not null && !normalizedProjectFile.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException("Project file path must point to a .csproj file.", nameof(projectFilePath));
        }

        return new ProjectDescriptor(
            projectId: BuildProjectId(normalizedRoot),
            projectRoot: normalizedRoot,
            projectFilePath: normalizedProjectFile);
    }

    private static string BuildProjectId(string projectRoot)
    {
        var normalized = Path.TrimEndingDirectorySeparator(Path.GetFullPath(projectRoot));
        if (OperatingSystem.IsWindows())
        {
            normalized = normalized.ToUpperInvariant();
        }

        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(normalized));
        return "project_" + Convert.ToHexString(hash[..8]).ToLowerInvariant();
    }

    private static bool IsInside(string root, string path)
    {
        var normalizedRoot = Path.TrimEndingDirectorySeparator(Path.GetFullPath(root)) + Path.DirectorySeparatorChar;
        var normalizedPath = Path.GetFullPath(path);
        var comparison = OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;
        return normalizedPath.StartsWith(normalizedRoot, comparison);
    }
}

public sealed record ProjectSessionIdentity(
    string SessionId,
    string ProjectId,
    string ProjectRoot,
    CompanionMode Mode,
    string? EditorSessionId);

public sealed class ProjectSession
{
    internal ProjectSession(ProjectDescriptor project, string sessionId)
    {
        Project = project;
        Identity = new ProjectSessionIdentity(
            SessionId: sessionId,
            ProjectId: project.ProjectId,
            ProjectRoot: project.ProjectRoot,
            Mode: CompanionMode.StaticHeadless,
            EditorSessionId: null);
    }

    public ProjectDescriptor Project { get; }

    public ProjectSessionIdentity Identity { get; private set; }

    public IReadOnlySet<CompanionCapability> Capabilities =>
        CompanionCapabilityCatalog.ForMode(Identity.Mode);

    public bool HasCapability(CompanionCapability capability)
    {
        return Capabilities.Contains(capability);
    }

    public void UpgradeToEditorLive(EditorBridgeStatus bridgeStatus)
    {
        if (bridgeStatus.State is not EditorBridgeState.Online)
        {
            throw new InvalidOperationException("Project sessions can upgrade to editor-live mode only when the editor bridge is online.");
        }

        if (!string.Equals(Project.ProjectId, bridgeStatus.ProjectId, StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Editor bridge project_id must match the project session before live capabilities are available.");
        }

        if (!bridgeStatus.ProvidesLiveEditorState)
        {
            throw new InvalidOperationException("Editor bridge must provide an editor_session_id before live capabilities are available.");
        }

        if (!EditorBridgeCompatibility.IsPluginVersionCompatible(bridgeStatus.PluginVersion))
        {
            throw new InvalidOperationException($"Editor bridge plugin_version is not compatible. {EditorBridgeCompatibility.CompatibilityRequirement}");
        }

        Identity = Identity with
        {
            Mode = CompanionMode.EditorLive,
            EditorSessionId = bridgeStatus.EditorSessionId,
        };
    }
}
