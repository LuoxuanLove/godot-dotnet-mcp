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
            projectId: BuildProjectId(normalizedRoot, normalizedProjectFile),
            projectRoot: normalizedRoot,
            projectFilePath: normalizedProjectFile);
    }

    private static string BuildProjectId(string projectRoot, string? projectFilePath)
    {
        var normalized = Path.TrimEndingDirectorySeparator(Path.GetFullPath(projectRoot));
        var comparisonRoot = normalized;
        if (OperatingSystem.IsWindows())
        {
            comparisonRoot = comparisonRoot.ToUpperInvariant();
        }

        var hashInput = comparisonRoot;
        if (!string.IsNullOrWhiteSpace(projectFilePath))
        {
            var normalizedProjectFile = Path.GetRelativePath(normalized, Path.GetFullPath(projectFilePath))
                .Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);
            if (OperatingSystem.IsWindows())
            {
                normalizedProjectFile = normalizedProjectFile.ToUpperInvariant();
            }

            hashInput += "\n" + normalizedProjectFile;
        }

        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(hashInput));
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
    string? ProjectFilePath,
    CompanionMode Mode,
    string? EditorSessionId,
    DateTimeOffset CreatedAtUtc,
    DateTimeOffset LastUsedAtUtc,
    DateTimeOffset ExpiresAtUtc,
    bool Revoked);

public enum EditorLiveUpgradeEligibilityReason
{
    Eligible,
    SessionStopped,
    SessionExpired,
    BridgeNotOnline,
    ProjectMismatch,
    LiveEditorStateUnavailable,
    IncompatiblePluginVersion,
}

public sealed record EditorLiveUpgradeEligibility(
    bool Eligible,
    EditorLiveUpgradeEligibilityReason Reason,
    ProjectSessionIdentity Session,
    EditorBridgeStatus BridgeStatus,
    string Message);

public sealed class ProjectSession
{
    private readonly object _stateLock = new();
    private readonly Func<DateTimeOffset> _clock;
    private ProjectSessionIdentity _identity;

    internal ProjectSession(
        ProjectDescriptor project,
        string sessionId,
        DateTimeOffset nowUtc,
        TimeSpan leaseDuration,
        Func<DateTimeOffset> clock)
    {
        _clock = clock;
        Project = project;
        _identity = new ProjectSessionIdentity(
            SessionId: sessionId,
            ProjectId: project.ProjectId,
            ProjectRoot: project.ProjectRoot,
            ProjectFilePath: project.ProjectFilePath,
            Mode: CompanionMode.StaticHeadless,
            EditorSessionId: null,
            CreatedAtUtc: nowUtc,
            LastUsedAtUtc: nowUtc,
            ExpiresAtUtc: nowUtc.Add(leaseDuration),
            Revoked: false);
    }

    public ProjectDescriptor Project { get; }

    public ProjectSessionIdentity Identity
    {
        get
        {
            lock (_stateLock)
            {
                return _identity;
            }
        }
    }

    public IReadOnlySet<CompanionCapability> Capabilities =>
        GetCapabilities(_clock());

    public bool HasCapability(CompanionCapability capability)
    {
        return Capabilities.Contains(capability);
    }

    internal bool HasCapability(CompanionCapability capability, DateTimeOffset nowUtc)
    {
        return GetCapabilities(nowUtc).Contains(capability);
    }

    internal SessionCapabilitySnapshot CreateCapabilitySnapshot(DateTimeOffset nowUtc)
    {
        lock (_stateLock)
        {
            var capabilities = IsActiveLocked(nowUtc)
                ? new System.Collections.ObjectModel.ReadOnlyCollection<CompanionCapability>(
                    CompanionCapabilityCatalog.ForMode(_identity.Mode)
                        .OrderBy(capability => capability)
                        .ToArray())
                : Array.AsReadOnly(Array.Empty<CompanionCapability>());
            return new SessionCapabilitySnapshot(_identity, capabilities);
        }
    }

    public bool IsExpired(DateTimeOffset nowUtc)
    {
        lock (_stateLock)
        {
            return IsExpiredLocked(nowUtc);
        }
    }

    public bool IsActive(DateTimeOffset nowUtc)
    {
        lock (_stateLock)
        {
            return IsActiveLocked(nowUtc);
        }
    }

    internal bool TryGetActiveIdentity(DateTimeOffset nowUtc, out ProjectSessionIdentity identity)
    {
        lock (_stateLock)
        {
            identity = _identity;
            return IsActiveLocked(nowUtc);
        }
    }

    internal void Touch(DateTimeOffset nowUtc, TimeSpan leaseDuration)
    {
        lock (_stateLock)
        {
            EnsureActiveLocked(nowUtc);
            _identity = _identity with
            {
                LastUsedAtUtc = nowUtc,
                ExpiresAtUtc = nowUtc.Add(leaseDuration),
            };
        }
    }

    internal void Revoke(DateTimeOffset nowUtc)
    {
        lock (_stateLock)
        {
            if (_identity.Revoked)
            {
                return;
            }

            _identity = _identity with
            {
                LastUsedAtUtc = nowUtc,
                ExpiresAtUtc = nowUtc,
                Revoked = true,
            };
        }
    }

    internal void DowngradeToStaticHeadless(DateTimeOffset nowUtc)
    {
        lock (_stateLock)
        {
            if (!IsActiveLocked(nowUtc))
            {
                return;
            }

            if (_identity.Mode is CompanionMode.StaticHeadless)
            {
                return;
            }

            _identity = _identity with
            {
                Mode = CompanionMode.StaticHeadless,
                EditorSessionId = null,
            };
        }
    }

    internal void RefreshEditorSession(EditorBridgeStatus bridgeStatus, DateTimeOffset nowUtc)
    {
        lock (_stateLock)
        {
            if (!IsActiveLocked(nowUtc))
            {
                return;
            }

            if (_identity.Mode is not CompanionMode.EditorLive)
            {
                return;
            }

            if (!string.Equals(_identity.ProjectId, bridgeStatus.ProjectId, StringComparison.Ordinal))
            {
                return;
            }

            if (!bridgeStatus.ProvidesLiveEditorState)
            {
                _identity = _identity with
                {
                    Mode = CompanionMode.StaticHeadless,
                    EditorSessionId = null,
                };
                return;
            }

            _identity = _identity with
            {
                EditorSessionId = bridgeStatus.EditorSessionId,
            };
        }
    }

    internal void EnsureActive(DateTimeOffset nowUtc)
    {
        lock (_stateLock)
        {
            EnsureActiveLocked(nowUtc);
        }
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
            throw new InvalidOperationException("Editor bridge must provide an editor_session_id and supports_live_editor_state before live capabilities are available.");
        }

        if (!EditorBridgeCompatibility.IsPluginVersionCompatible(bridgeStatus.PluginVersion))
        {
            throw new InvalidOperationException($"Editor bridge plugin_version is not compatible. {EditorBridgeCompatibility.CompatibilityRequirement}");
        }

        lock (_stateLock)
        {
            EnsureActiveLocked(_clock());
            _identity = _identity with
            {
                Mode = CompanionMode.EditorLive,
                EditorSessionId = bridgeStatus.EditorSessionId,
            };
        }
    }

    public EditorLiveUpgradeEligibility EvaluateEditorLiveUpgrade(EditorBridgeStatus bridgeStatus)
    {
        lock (_stateLock)
        {
            var nowUtc = _clock();
            if (_identity.Revoked)
            {
                return CreateEditorLiveUpgradeEligibility(
                    false,
                    EditorLiveUpgradeEligibilityReason.SessionStopped,
                    bridgeStatus,
                    "Project session has been stopped.");
            }

            if (IsExpiredLocked(nowUtc))
            {
                return CreateEditorLiveUpgradeEligibility(
                    false,
                    EditorLiveUpgradeEligibilityReason.SessionExpired,
                    bridgeStatus,
                    "Project session lease has expired.");
            }

            if (bridgeStatus.State is not EditorBridgeState.Online)
            {
                return CreateEditorLiveUpgradeEligibility(
                    false,
                    EditorLiveUpgradeEligibilityReason.BridgeNotOnline,
                    bridgeStatus,
                    "Project sessions can upgrade to editor-live mode only when the editor bridge is online.");
            }

            if (!string.Equals(Project.ProjectId, bridgeStatus.ProjectId, StringComparison.Ordinal))
            {
                return CreateEditorLiveUpgradeEligibility(
                    false,
                    EditorLiveUpgradeEligibilityReason.ProjectMismatch,
                    bridgeStatus,
                    "Editor bridge project_id must match the project session before live capabilities are available.");
            }

            if (!bridgeStatus.ProvidesLiveEditorState)
            {
                return CreateEditorLiveUpgradeEligibility(
                    false,
                    EditorLiveUpgradeEligibilityReason.LiveEditorStateUnavailable,
                    bridgeStatus,
                    "Editor bridge must provide an editor_session_id and supports_live_editor_state before live capabilities are available.");
            }

            if (!EditorBridgeCompatibility.IsPluginVersionCompatible(bridgeStatus.PluginVersion))
            {
                return CreateEditorLiveUpgradeEligibility(
                    false,
                    EditorLiveUpgradeEligibilityReason.IncompatiblePluginVersion,
                    bridgeStatus,
                    $"Editor bridge plugin_version is not compatible. {EditorBridgeCompatibility.CompatibilityRequirement}");
            }

            return CreateEditorLiveUpgradeEligibility(
                true,
                EditorLiveUpgradeEligibilityReason.Eligible,
                bridgeStatus,
                "Editor bridge can be explicitly upgraded to editor-live mode.");
        }
    }

    private IReadOnlySet<CompanionCapability> GetCapabilities(DateTimeOffset nowUtc)
    {
        lock (_stateLock)
        {
            return IsActiveLocked(nowUtc)
                ? CompanionCapabilityCatalog.ForMode(_identity.Mode)
                : CompanionCapabilityCatalog.ForInactiveSession();
        }
    }

    private void EnsureActiveLocked(DateTimeOffset nowUtc)
    {
        if (_identity.Revoked)
        {
            throw new InvalidOperationException("Project session has been stopped.");
        }

        if (IsExpiredLocked(nowUtc))
        {
            throw new InvalidOperationException("Project session lease has expired.");
        }
    }

    private bool IsActiveLocked(DateTimeOffset nowUtc)
    {
        return !_identity.Revoked && !IsExpiredLocked(nowUtc);
    }

    private bool IsExpiredLocked(DateTimeOffset nowUtc)
    {
        return nowUtc >= _identity.ExpiresAtUtc;
    }

    private EditorLiveUpgradeEligibility CreateEditorLiveUpgradeEligibility(
        bool eligible,
        EditorLiveUpgradeEligibilityReason reason,
        EditorBridgeStatus bridgeStatus,
        string message)
    {
        return new EditorLiveUpgradeEligibility(
            eligible,
            reason,
            _identity,
            bridgeStatus,
            message);
    }
}
