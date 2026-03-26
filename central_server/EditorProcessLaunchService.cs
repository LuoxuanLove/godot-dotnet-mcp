using System.Diagnostics;
using System.Globalization;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorProcessLaunchService
{
    private const string RuntimeServerHostEnvName = "GODOT_DOTNET_MCP_SERVER_HOST";
    private const string RuntimeServerPortEnvName = "GODOT_DOTNET_MCP_SERVER_PORT";

    private readonly EditorProcessResidencyService _residencyService;

    public EditorProcessLaunchService(EditorProcessResidencyService residencyService)
    {
        _residencyService = residencyService;
    }

    public EditorProcessService.EditorLaunchResult OpenProject(
        ProjectRegistryService.RegisteredProject project,
        string executablePath,
        string executableSource,
        string launchReason,
        EditorAttachEndpoint? attachEndpoint = null)
    {
        var existingEntry = _residencyService.GetResidency(project.ProjectId, project.ProjectRoot);
        if (existingEntry is not null && EditorProcessSupport.TryGetLiveProcess(existingEntry.ProcessId, out _))
        {
            return BuildLaunchResult(project, existingEntry, alreadyRunning: true);
        }

        var runtimeServerHost = "127.0.0.1";
        var runtimeServerPort = EditorProcessSupport.GetFreeTcpPort();
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

        var entry = _residencyService.UpsertLaunchResidency(
            project,
            process.Id,
            executablePath,
            executableSource,
            launchReason,
            runtimeServerHost,
            runtimeServerPort);

        return BuildLaunchResult(project, entry, alreadyRunning: false);
    }

    private static EditorProcessService.EditorLaunchResult BuildLaunchResult(
        ProjectRegistryService.RegisteredProject project,
        EditorResidencyStore.ResidencyEntry entry,
        bool alreadyRunning)
    {
        return new EditorProcessService.EditorLaunchResult
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
}
