namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorSessionCoordinator
{
    public const int DefaultAttachTimeoutMs = 45_000;
    private const int MinAttachTimeoutMs = 1_000;
    internal const int MaxAttachTimeoutMs = 180_000;

    private readonly EditorSessionAcquisitionService _acquisitionService;
    private readonly EditorAttachEndpoint _attachEndpoint;

    public EditorSessionCoordinator(
        CentralConfigurationService configuration,
        EditorProcessService editorProcesses,
        EditorSessionService editorSessions,
        GodotInstallationService godotInstallations,
        ProjectRegistryService registry,
        CentralWorkspaceState workspaceState,
        EditorAttachEndpoint attachEndpoint)
    {
        _attachEndpoint = attachEndpoint;
        _acquisitionService = new EditorSessionAcquisitionService(
            configuration,
            editorProcesses,
            editorSessions,
            godotInstallations,
            registry,
            workspaceState,
            attachEndpoint);
    }

    public EditorAttachEndpoint AttachEndpoint => _attachEndpoint;

    public GodotInstallationService.GodotExecutableResolution ResolveExecutable(
        ProjectRegistryService.RegisteredProject project,
        string explicitExecutablePath)
    {
        return _acquisitionService.ResolveExecutable(project, explicitExecutablePath);
    }

    public Task<EnsureEditorSessionResult> EnsureHttpReadySessionAsync(
        string toolName,
        string? projectId,
        string? projectPath,
        bool autoLaunchEditor,
        int? attachTimeoutMs,
        string? explicitExecutablePath,
        string launchReason,
        CancellationToken cancellationToken)
    {
        return _acquisitionService.EnsureHttpReadySessionAsync(
            toolName,
            projectId,
            projectPath,
            autoLaunchEditor,
            attachTimeoutMs,
            explicitExecutablePath,
            launchReason,
            cancellationToken);
    }

    internal static int NormalizeAttachTimeout(int? attachTimeoutMs)
    {
        if (!attachTimeoutMs.HasValue || attachTimeoutMs.Value <= 0)
        {
            return DefaultAttachTimeoutMs;
        }

        return Math.Clamp(attachTimeoutMs.Value, MinAttachTimeoutMs, MaxAttachTimeoutMs);
    }
}
