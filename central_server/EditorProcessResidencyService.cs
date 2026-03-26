namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorProcessResidencyService
{
    private readonly EditorResidencyStore _residencyStore;
    private readonly IExternalEditorProcessProbe _externalEditorProcessProbe;

    public EditorProcessResidencyService(
        EditorResidencyStore residencyStore,
        IExternalEditorProcessProbe externalEditorProcessProbe)
    {
        _residencyStore = residencyStore;
        _externalEditorProcessProbe = externalEditorProcessProbe;
        Prune();
    }

    public string StorePath => _residencyStore.StorePath;

    public void Prune()
    {
        _residencyStore.Prune(EditorProcessSupport.IsProcessRunning);
    }

    public EditorProcessService.EditorProcessStatus GetStatus(string projectId, string? projectRoot = null)
    {
        Prune();
        var entry = ResolveTrackedEntry(projectId, projectRoot, adoptProjectIdentity: true);
        if (entry is null)
        {
            return EditorProcessService.EditorProcessStatus.Empty(projectId, _residencyStore.StorePath);
        }

        if (!EditorProcessSupport.TryGetLiveProcess(entry.ProcessId, out _))
        {
            _residencyStore.Remove(entry.ProjectId);
            return EditorProcessService.EditorProcessStatus.Empty(projectId, _residencyStore.StorePath);
        }

        return BuildProcessStatus(entry);
    }

    public EditorResidencyStore.ResidencyEntry? GetResidency(string projectId, string? projectRoot = null)
    {
        Prune();
        return ResolveTrackedEntry(projectId, projectRoot, adoptProjectIdentity: true);
    }

    public EditorProcessService.EditorProcessStatus? FindUntrackedEditorStatus(string projectId, string? projectRoot)
    {
        Prune();
        if (string.IsNullOrWhiteSpace(projectRoot))
        {
            return null;
        }

        var normalizedProjectRoot = EditorProcessSupport.NormalizeProjectRoot(projectRoot);
        var trackedEntry = ResolveTrackedEntry(projectId, normalizedProjectRoot, adoptProjectIdentity: false);
        var trackedProcessId = trackedEntry?.ProcessId ?? 0;

        foreach (var candidate in _externalEditorProcessProbe.EnumerateEditorProcesses())
        {
            if (candidate.ProcessId <= 0
                || candidate.ProcessId == trackedProcessId
                || !string.Equals(candidate.ProjectRoot, normalizedProjectRoot, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            return BuildUntrackedProcessStatus(projectId, normalizedProjectRoot, candidate);
        }

        return null;
    }

    public void SyncTrackedProcess(
        string projectId,
        string? projectRoot,
        int processId,
        string? serverHost = null,
        int? serverPort = null,
        DateTimeOffset? startedAtUtc = null)
    {
        if (processId <= 0)
        {
            return;
        }

        var existingEntry = ResolveTrackedEntry(projectId, projectRoot, adoptProjectIdentity: true);
        if (existingEntry is null)
        {
            return;
        }

        if (!EditorProcessSupport.TryGetLiveProcess(processId, out _))
        {
            return;
        }

        var updatedEntry = existingEntry with
        {
            ProcessId = processId,
            ProjectRoot = EditorProcessSupport.ResolveProjectRoot(projectRoot, existingEntry.ProjectRoot),
            ServerHost = string.IsNullOrWhiteSpace(serverHost) ? existingEntry.ServerHost : serverHost.Trim(),
            ServerPort = serverPort is > 0 ? serverPort.Value : existingEntry.ServerPort,
            StartedAtUtc = startedAtUtc ?? existingEntry.StartedAtUtc,
        };
        _residencyStore.Upsert(updatedEntry);
    }

    public EditorResidencyStore.ResidencyEntry UpsertLaunchResidency(
        ProjectRegistryService.RegisteredProject project,
        int processId,
        string executablePath,
        string executableSource,
        string launchReason,
        string runtimeServerHost,
        int runtimeServerPort)
    {
        var entry = new EditorResidencyStore.ResidencyEntry
        {
            ProjectId = project.ProjectId,
            ProjectRoot = EditorProcessSupport.NormalizeProjectRoot(project.ProjectRoot),
            ProcessId = processId,
            StartedAtUtc = DateTimeOffset.UtcNow,
            ExecutablePath = executablePath,
            ExecutableSource = executableSource,
            ServerHost = runtimeServerHost,
            ServerPort = runtimeServerPort,
            LaunchReason = launchReason,
        };
        _residencyStore.Upsert(entry);
        return entry;
    }

    public bool RemoveResidency(string projectId)
    {
        return _residencyStore.Remove(projectId);
    }

    private EditorResidencyStore.ResidencyEntry? ResolveTrackedEntry(string projectId, string? projectRoot, bool adoptProjectIdentity)
    {
        if (!string.IsNullOrWhiteSpace(projectId))
        {
            var exactEntry = _residencyStore.Get(projectId);
            if (exactEntry is not null)
            {
                return exactEntry;
            }
        }

        var rootEntry = _residencyStore.FindByProjectRoot(projectRoot);
        if (rootEntry is null)
        {
            return null;
        }

        if (!adoptProjectIdentity || string.IsNullOrWhiteSpace(projectId) || string.Equals(rootEntry.ProjectId, projectId, StringComparison.OrdinalIgnoreCase))
        {
            return rootEntry;
        }

        _residencyStore.Remove(rootEntry.ProjectId);
        var migratedEntry = rootEntry with
        {
            ProjectId = projectId,
            ProjectRoot = EditorProcessSupport.ResolveProjectRoot(projectRoot, rootEntry.ProjectRoot),
        };
        _residencyStore.Upsert(migratedEntry);
        return migratedEntry;
    }

    private EditorProcessService.EditorProcessStatus BuildProcessStatus(EditorResidencyStore.ResidencyEntry entry)
    {
        return new EditorProcessService.EditorProcessStatus
        {
            ProjectId = entry.ProjectId,
            ProjectRoot = entry.ProjectRoot,
            Resident = true,
            Running = true,
            Ownership = "host_managed",
            ProcessId = entry.ProcessId,
            StartedAtUtc = entry.StartedAtUtc,
            ExecutablePath = entry.ExecutablePath,
            ExecutableSource = entry.ExecutableSource,
            ServerHost = entry.ServerHost,
            ServerPort = entry.ServerPort,
            LaunchReason = entry.LaunchReason,
            StorePath = _residencyStore.StorePath,
        };
    }

    private EditorProcessService.EditorProcessStatus BuildUntrackedProcessStatus(
        string projectId,
        string projectRoot,
        ExternalEditorProcessInfo candidate)
    {
        return new EditorProcessService.EditorProcessStatus
        {
            ProjectId = projectId,
            ProjectRoot = projectRoot,
            Resident = true,
            Running = true,
            Ownership = "external_untracked",
            ProcessId = candidate.ProcessId,
            StartedAtUtc = EditorProcessSupport.TryGetProcessStartTime(candidate.ProcessId),
            ExecutablePath = candidate.ExecutablePath,
            ExecutableSource = "external",
            LaunchReason = "external_existing_editor",
            StorePath = _residencyStore.StorePath,
        };
    }
}
