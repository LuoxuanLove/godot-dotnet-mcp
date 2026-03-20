using System.Diagnostics;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorProcessService
{
    private readonly Dictionary<string, EditorProcessEntry> _entries = new(StringComparer.OrdinalIgnoreCase);

    public EditorLaunchResult OpenProject(
        ProjectRegistryService.RegisteredProject project,
        string executablePath,
        string executableSource)
    {
        if (_entries.TryGetValue(project.ProjectId, out var existingEntry))
        {
            if (TryGetLiveProcess(existingEntry.ProcessId, out var existingProcess))
            {
                return new EditorLaunchResult
                {
                    ProjectId = project.ProjectId,
                    ProjectRoot = project.ProjectRoot,
                    AlreadyRunning = true,
                    ProcessId = existingEntry.ProcessId,
                    ExecutablePath = executablePath,
                    ExecutableSource = executableSource,
                    StartedAtUtc = existingEntry.StartedAtUtc,
                };
            }

            _entries.Remove(project.ProjectId);
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = executablePath,
            Arguments = $"--path \"{project.ProjectRoot}\"",
            WorkingDirectory = project.ProjectRoot,
            UseShellExecute = false,
        };

        var process = Process.Start(startInfo);
        if (process is null)
        {
            throw new CentralToolException("Failed to start Godot editor process.");
        }

        var entry = new EditorProcessEntry
        {
            ProjectId = project.ProjectId,
            ProcessId = process.Id,
            StartedAtUtc = DateTimeOffset.UtcNow,
        };
        _entries[project.ProjectId] = entry;

        return new EditorLaunchResult
        {
            ProjectId = project.ProjectId,
            ProjectRoot = project.ProjectRoot,
            AlreadyRunning = false,
            ProcessId = process.Id,
            ExecutablePath = executablePath,
            ExecutableSource = executableSource,
            StartedAtUtc = entry.StartedAtUtc,
        };
    }

    public EditorProcessStatus GetStatus(string projectId)
    {
        if (!_entries.TryGetValue(projectId, out var entry))
        {
            return new EditorProcessStatus
            {
                ProjectId = projectId,
                Running = false,
            };
        }

        var running = TryGetLiveProcess(entry.ProcessId, out _);
        if (!running)
        {
            _entries.Remove(projectId);
        }

        return new EditorProcessStatus
        {
            ProjectId = projectId,
            Running = running,
            ProcessId = running ? entry.ProcessId : null,
            StartedAtUtc = running ? entry.StartedAtUtc : null,
        };
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

    internal sealed class EditorLaunchResult
    {
        public string ProjectId { get; set; } = string.Empty;

        public string ProjectRoot { get; set; } = string.Empty;

        public bool AlreadyRunning { get; set; }

        public int ProcessId { get; set; }

        public string ExecutablePath { get; set; } = string.Empty;

        public string ExecutableSource { get; set; } = string.Empty;

        public DateTimeOffset StartedAtUtc { get; set; }
    }

    internal sealed class EditorProcessStatus
    {
        public string ProjectId { get; set; } = string.Empty;

        public bool Running { get; set; }

        public int? ProcessId { get; set; }

        public DateTimeOffset? StartedAtUtc { get; set; }
    }

    private sealed class EditorProcessEntry
    {
        public string ProjectId { get; set; } = string.Empty;

        public int ProcessId { get; set; }

        public DateTimeOffset StartedAtUtc { get; set; }
    }
}
