namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorProcessService
{
    private readonly EditorProcessResidencyService _residencyService;
    private readonly EditorProcessLaunchService _launchService;
    private readonly EditorProcessTerminationService _terminationService;

    public EditorProcessService()
        : this(new EditorResidencyStore(), CreateDefaultExternalEditorProcessProbe())
    {
    }

    internal EditorProcessService(EditorResidencyStore residencyStore)
        : this(residencyStore, CreateDefaultExternalEditorProcessProbe())
    {
    }

    internal EditorProcessService(EditorResidencyStore residencyStore, IExternalEditorProcessProbe externalEditorProcessProbe)
    {
        _residencyService = new EditorProcessResidencyService(residencyStore, externalEditorProcessProbe);
        _launchService = new EditorProcessLaunchService(_residencyService);
        _terminationService = new EditorProcessTerminationService(_residencyService);
    }

    public string StorePath => _residencyService.StorePath;

    public EditorLaunchResult OpenProject(
        ProjectRegistryService.RegisteredProject project,
        string executablePath,
        string executableSource,
        string launchReason,
        EditorAttachEndpoint? attachEndpoint = null)
    {
        return _launchService.OpenProject(project, executablePath, executableSource, launchReason, attachEndpoint);
    }

    public EditorProcessStatus GetStatus(string projectId, string? projectRoot = null)
    {
        return _residencyService.GetStatus(projectId, projectRoot);
    }

    public EditorResidencyStore.ResidencyEntry? GetResidency(string projectId, string? projectRoot = null)
    {
        return _residencyService.GetResidency(projectId, projectRoot);
    }

    public EditorProcessStatus? FindUntrackedEditorStatus(string projectId, string? projectRoot)
    {
        return _residencyService.FindUntrackedEditorStatus(projectId, projectRoot);
    }

    public void SyncTrackedProcess(
        string projectId,
        string? projectRoot,
        int processId,
        string? serverHost = null,
        int? serverPort = null,
        DateTimeOffset? startedAtUtc = null)
    {
        _residencyService.SyncTrackedProcess(projectId, projectRoot, processId, serverHost, serverPort, startedAtUtc);
    }

    public Task<EditorProcessStatus> WaitForExitAsync(
        string projectId,
        string? projectRoot,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        return _terminationService.WaitForExitAsync(projectId, projectRoot, timeout, cancellationToken);
    }

    public Task<EditorForceStopResult> ForceStopTrackedProcessAsync(
        string projectId,
        string? projectRoot,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        return _terminationService.ForceStopTrackedProcessAsync(projectId, projectRoot, timeout, cancellationToken);
    }

    private static IExternalEditorProcessProbe CreateDefaultExternalEditorProcessProbe()
    {
        return OperatingSystem.IsWindows()
            ? new WindowsWmiExternalEditorProcessProbe()
            : new NullExternalEditorProcessProbe();
    }

    internal sealed class EditorLaunchResult
    {
        public string ProjectId { get; set; } = string.Empty;

        public string ProjectRoot { get; set; } = string.Empty;

        public bool AlreadyRunning { get; set; }

        public int ProcessId { get; set; }

        public string ExecutablePath { get; set; } = string.Empty;

        public string ExecutableSource { get; set; } = string.Empty;

        public DateTimeOffset StartedAtUtc { get; set; }

        public string ServerHost { get; set; } = string.Empty;

        public int ServerPort { get; set; }

        public string LaunchReason { get; set; } = string.Empty;
    }

    internal sealed class EditorProcessStatus
    {
        public string ProjectId { get; set; } = string.Empty;

        public string ProjectRoot { get; set; } = string.Empty;

        public bool Resident { get; set; }

        public bool Running { get; set; }

        public string Ownership { get; set; } = "none";

        public int? ProcessId { get; set; }

        public DateTimeOffset? StartedAtUtc { get; set; }

        public string ExecutablePath { get; set; } = string.Empty;

        public string ExecutableSource { get; set; } = string.Empty;

        public string ServerHost { get; set; } = string.Empty;

        public int ServerPort { get; set; }

        public string LaunchReason { get; set; } = string.Empty;

        public string StorePath { get; set; } = string.Empty;

        public static EditorProcessStatus Empty(string projectId, string storePath)
        {
            return new EditorProcessStatus
            {
                ProjectId = projectId,
                ProjectRoot = string.Empty,
                Resident = false,
                Running = false,
                Ownership = "none",
                StorePath = storePath,
            };
        }
    }

    internal sealed class EditorForceStopResult
    {
        public bool Success { get; set; }

        public string ErrorType { get; set; } = string.Empty;

        public string Message { get; set; } = string.Empty;

        public EditorProcessStatus Process { get; set; } = EditorProcessStatus.Empty(string.Empty, string.Empty);
    }
}
