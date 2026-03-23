using System.Diagnostics;
using System.Globalization;
using System.Net;
using System.Net.Sockets;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorProcessService
{
    private const string RuntimeServerHostEnvName = "GODOT_DOTNET_MCP_SERVER_HOST";
    private const string RuntimeServerPortEnvName = "GODOT_DOTNET_MCP_SERVER_PORT";
    private readonly Dictionary<string, EditorProcessEntry> _entries = new(StringComparer.OrdinalIgnoreCase);

    public EditorLaunchResult OpenProject(
        ProjectRegistryService.RegisteredProject project,
        string executablePath,
        string executableSource,
        EditorAttachEndpoint? attachEndpoint = null)
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
                    ServerHost = existingEntry.ServerHost,
                    ServerPort = existingEntry.ServerPort,
                };
            }

            _entries.Remove(project.ProjectId);
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

        var entry = new EditorProcessEntry
        {
            ProjectId = project.ProjectId,
            ProcessId = process.Id,
            StartedAtUtc = DateTimeOffset.UtcNow,
            ServerHost = runtimeServerHost,
            ServerPort = runtimeServerPort,
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
            ServerHost = runtimeServerHost,
            ServerPort = runtimeServerPort,
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

        public string ServerHost { get; set; } = string.Empty;

        public int ServerPort { get; set; }
    }
}
