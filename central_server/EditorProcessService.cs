using System.Diagnostics;
using System.Globalization;
using System.Net;
using System.Net.Sockets;
using System.Management;
using System.Text.RegularExpressions;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorProcessService
{
    private const string RuntimeServerHostEnvName = "GODOT_DOTNET_MCP_SERVER_HOST";
    private const string RuntimeServerPortEnvName = "GODOT_DOTNET_MCP_SERVER_PORT";

    private readonly EditorResidencyStore _residencyStore;

    public EditorProcessService()
        : this(new EditorResidencyStore())
    {
    }

    internal EditorProcessService(EditorResidencyStore residencyStore)
    {
        _residencyStore = residencyStore;
        _residencyStore.Prune(IsProcessRunning);
    }

    public string StorePath => _residencyStore.StorePath;

    public EditorLaunchResult OpenProject(
        ProjectRegistryService.RegisteredProject project,
        string executablePath,
        string executableSource,
        string launchReason,
        EditorAttachEndpoint? attachEndpoint = null)
    {
        _residencyStore.Prune(IsProcessRunning);
        var existingEntry = ResolveTrackedEntry(project.ProjectId, project.ProjectRoot, adoptProjectIdentity: true);
        if (existingEntry is not null && TryGetLiveProcess(existingEntry.ProcessId, out _))
        {
            return BuildLaunchResult(project, existingEntry, alreadyRunning: true);
        }

        var runtimeServerHost = "127.0.0.1";
        var runtimeServerPort = GetFreeTcpPort();
        var startInfo = new ProcessStartInfo
        {
            FileName = executablePath,
            Arguments = $"--editor --path \"{project.ProjectRoot}\"",
            WorkingDirectory = project.ProjectRoot,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };

        if (attachEndpoint is not null)
        {
            startInfo.Environment["GODOT_DOTNET_MCP_CENTRAL_SERVER_HOST"] = attachEndpoint.Host;
            startInfo.Environment["GODOT_DOTNET_MCP_CENTRAL_SERVER_PORT"] = attachEndpoint.Port.ToString(CultureInfo.InvariantCulture);
        }

        startInfo.Environment[RuntimeServerHostEnvName] = runtimeServerHost;
        startInfo.Environment[RuntimeServerPortEnvName] = runtimeServerPort.ToString(CultureInfo.InvariantCulture);

        var process = Process.Start(startInfo);
        if (process is null)
        {
            throw new CentralToolException("Failed to start Godot editor process.");
        }

        process.OutputDataReceived += static (_, _) => { };
        process.ErrorDataReceived += static (_, _) => { };
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        var entry = new EditorResidencyStore.ResidencyEntry
        {
            ProjectId = project.ProjectId,
            ProjectRoot = NormalizeProjectRoot(project.ProjectRoot),
            ProcessId = process.Id,
            StartedAtUtc = DateTimeOffset.UtcNow,
            ExecutablePath = executablePath,
            ExecutableSource = executableSource,
            ServerHost = runtimeServerHost,
            ServerPort = runtimeServerPort,
            LaunchReason = launchReason,
        };
        _residencyStore.Upsert(entry);

        return BuildLaunchResult(project, entry, alreadyRunning: false);
    }

    public EditorProcessStatus GetStatus(string projectId, string? projectRoot = null)
    {
        _residencyStore.Prune(IsProcessRunning);
        var entry = ResolveTrackedEntry(projectId, projectRoot, adoptProjectIdentity: true);
        if (entry is null)
        {
            return EditorProcessStatus.Empty(projectId, _residencyStore.StorePath);
        }

        if (!TryGetLiveProcess(entry.ProcessId, out _))
        {
            _residencyStore.Remove(projectId);
            return EditorProcessStatus.Empty(projectId, _residencyStore.StorePath);
        }

        return BuildProcessStatus(entry);
    }

    public EditorResidencyStore.ResidencyEntry? GetResidency(string projectId, string? projectRoot = null)
    {
        _residencyStore.Prune(IsProcessRunning);
        return ResolveTrackedEntry(projectId, projectRoot, adoptProjectIdentity: true);
    }

    public EditorProcessStatus? FindUntrackedEditorStatus(string projectId, string? projectRoot)
    {
        _residencyStore.Prune(IsProcessRunning);
        if (!OperatingSystem.IsWindows() || string.IsNullOrWhiteSpace(projectRoot))
        {
            return null;
        }

        var normalizedProjectRoot = NormalizeProjectRoot(projectRoot);
        var trackedEntry = ResolveTrackedEntry(projectId, normalizedProjectRoot, adoptProjectIdentity: false);
        var trackedProcessId = trackedEntry?.ProcessId ?? 0;

        try
        {
            foreach (var candidate in EnumerateWindowsEditorProcesses())
            {
                if (candidate.ProcessId <= 0
                    || candidate.ProcessId == trackedProcessId
                    || !string.Equals(candidate.ProjectRoot, normalizedProjectRoot, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                return BuildUntrackedProcessStatus(projectId, normalizedProjectRoot, candidate);
            }
        }
        catch
        {
            // WMI probing is best-effort only; degraded environments should not block host orchestration.
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

        if (!TryGetLiveProcess(processId, out _))
        {
            return;
        }

        var updatedEntry = existingEntry with
        {
            ProcessId = processId,
            ProjectRoot = ResolveProjectRoot(projectRoot, existingEntry.ProjectRoot),
            ServerHost = string.IsNullOrWhiteSpace(serverHost) ? existingEntry.ServerHost : serverHost.Trim(),
            ServerPort = serverPort is > 0 ? serverPort.Value : existingEntry.ServerPort,
            StartedAtUtc = startedAtUtc ?? existingEntry.StartedAtUtc,
        };
        _residencyStore.Upsert(updatedEntry);
    }

    public async Task<EditorProcessStatus> WaitForExitAsync(string projectId, string? projectRoot, TimeSpan timeout, CancellationToken cancellationToken)
    {
        var startedAt = DateTimeOffset.UtcNow;
        while (DateTimeOffset.UtcNow - startedAt < timeout)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var status = GetStatus(projectId, projectRoot);
            if (!status.Running)
            {
                return status;
            }

            await Task.Delay(500, cancellationToken);
        }

        return GetStatus(projectId, projectRoot);
    }

    public async Task<EditorForceStopResult> ForceStopTrackedProcessAsync(string projectId, string? projectRoot, TimeSpan timeout, CancellationToken cancellationToken)
    {
        _residencyStore.Prune(IsProcessRunning);
        var entry = ResolveTrackedEntry(projectId, projectRoot, adoptProjectIdentity: true);
        if (entry is null)
        {
            return new EditorForceStopResult
            {
                Success = false,
                ErrorType = "editor_process_not_found",
                Message = "No host-managed editor process is tracked for this project.",
                Process = EditorProcessStatus.Empty(projectId, _residencyStore.StorePath),
            };
        }

        if (!TryGetLiveProcess(entry.ProcessId, out var process))
        {
            _residencyStore.Remove(entry.ProjectId);
            return new EditorForceStopResult
            {
                Success = true,
                Process = EditorProcessStatus.Empty(projectId, _residencyStore.StorePath),
            };
        }

        using (process!)
        {
            process!.Kill(entireProcessTree: true);
        }

        var finalStatus = await WaitForExitAsync(projectId, projectRoot, timeout, cancellationToken);
        if (finalStatus.Running)
        {
            return new EditorForceStopResult
            {
                Success = false,
                ErrorType = "editor_close_timeout",
                Message = $"Timed out waiting for the tracked editor process to exit after {timeout.TotalMilliseconds:F0} ms.",
                Process = finalStatus,
            };
        }

        _residencyStore.Remove(entry.ProjectId);
        return new EditorForceStopResult
        {
            Success = true,
            Process = finalStatus,
        };
    }

    private static EditorLaunchResult BuildLaunchResult(
        ProjectRegistryService.RegisteredProject project,
        EditorResidencyStore.ResidencyEntry entry,
        bool alreadyRunning)
    {
        return new EditorLaunchResult
        {
            ProjectId = project.ProjectId,
            ProjectRoot = project.ProjectRoot,
            AlreadyRunning = alreadyRunning,
            ProcessId = entry.ProcessId,
            ExecutablePath = entry.ExecutablePath,
            ExecutableSource = entry.ExecutableSource,
            StartedAtUtc = entry.StartedAtUtc,
            ServerHost = entry.ServerHost,
            ServerPort = entry.ServerPort,
            LaunchReason = entry.LaunchReason,
        };
    }

    private EditorProcessStatus BuildProcessStatus(EditorResidencyStore.ResidencyEntry entry)
    {
        return new EditorProcessStatus
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

    private static bool IsProcessRunning(int processId)
    {
        return TryGetLiveProcess(processId, out _);
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
            ProjectRoot = ResolveProjectRoot(projectRoot, rootEntry.ProjectRoot),
        };
        _residencyStore.Upsert(migratedEntry);
        return migratedEntry;
    }

    private static bool TryGetLiveProcess(int processId, out Process? process)
    {
        process = null;
        try
        {
            process = Process.GetProcessById(processId);
            return !process.HasExited;
        }
        catch
        {
            return false;
        }
    }

    private static int GetFreeTcpPort()
    {
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        try
        {
            return ((IPEndPoint)listener.LocalEndpoint).Port;
        }
        finally
        {
            listener.Stop();
        }
    }

    private static string ResolveProjectRoot(string? projectRoot, string fallbackProjectRoot)
    {
        if (!string.IsNullOrWhiteSpace(projectRoot))
        {
            return NormalizeProjectRoot(projectRoot);
        }

        return NormalizeProjectRoot(fallbackProjectRoot);
    }

    private static string NormalizeProjectRoot(string projectRoot)
    {
        return Path.GetFullPath(Environment.ExpandEnvironmentVariables(projectRoot))
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
    }

    private EditorProcessStatus BuildUntrackedProcessStatus(string projectId, string projectRoot, ExternalEditorProcessInfo candidate)
    {
        return new EditorProcessStatus
        {
            ProjectId = projectId,
            ProjectRoot = projectRoot,
            Resident = true,
            Running = true,
            Ownership = "external_untracked",
            ProcessId = candidate.ProcessId,
            StartedAtUtc = TryGetProcessStartTime(candidate.ProcessId),
            ExecutablePath = candidate.ExecutablePath,
            ExecutableSource = "external",
            LaunchReason = "external_existing_editor",
            StorePath = _residencyStore.StorePath,
        };
    }

    private static DateTimeOffset? TryGetProcessStartTime(int processId)
    {
        try
        {
            using var process = Process.GetProcessById(processId);
            return process.HasExited
                ? null
                : process.StartTime;
        }
        catch
        {
            return null;
        }
    }

    private static IEnumerable<ExternalEditorProcessInfo> EnumerateWindowsEditorProcesses()
    {
        if (!OperatingSystem.IsWindows())
        {
            yield break;
        }

        ManagementObjectCollection? results = null;
        try
        {
            using var searcher = new ManagementObjectSearcher(
                "SELECT ProcessId, Name, CommandLine, ExecutablePath FROM Win32_Process WHERE Name LIKE 'Godot%.exe'");
            results = searcher.Get();
        }
        catch
        {
            yield break;
        }

        using (results)
        {
            foreach (var process in results.OfType<ManagementObject>())
            {
                using (process)
                {
                    var processId = Convert.ToInt32(process["ProcessId"] ?? 0, CultureInfo.InvariantCulture);
                    var commandLine = Convert.ToString(process["CommandLine"], CultureInfo.InvariantCulture) ?? string.Empty;
                    if (processId <= 0
                        || !TryExtractEditorProjectRoot(commandLine, out var projectRoot))
                    {
                        continue;
                    }

                    yield return new ExternalEditorProcessInfo(
                        processId,
                        projectRoot,
                        Convert.ToString(process["ExecutablePath"], CultureInfo.InvariantCulture) ?? string.Empty,
                        commandLine);
                }
            }
        }
    }

    private static bool TryExtractEditorProjectRoot(string commandLine, out string projectRoot)
    {
        projectRoot = string.Empty;
        if (string.IsNullOrWhiteSpace(commandLine)
            || !Regex.IsMatch(commandLine, @"(^|\s)--editor(\s|$)", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant))
        {
            return false;
        }

        var match = Regex.Match(
            commandLine,
            @"(?:^|\s)--path\s+(?:""(?<path>[^""]+)""|(?<path>\S+))",
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
        if (!match.Success)
        {
            return false;
        }

        var value = match.Groups["path"].Value;
        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        try
        {
            projectRoot = NormalizeProjectRoot(value);
            return !string.IsNullOrWhiteSpace(projectRoot);
        }
        catch
        {
            projectRoot = string.Empty;
            return false;
        }
    }

    private sealed record ExternalEditorProcessInfo(
        int ProcessId,
        string ProjectRoot,
        string ExecutablePath,
        string CommandLine);

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
