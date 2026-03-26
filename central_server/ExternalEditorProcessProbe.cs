using System.Globalization;
using System.Management;
using System.Text.RegularExpressions;

namespace GodotDotnetMcp.CentralServer;

internal interface IExternalEditorProcessProbe
{
    IEnumerable<ExternalEditorProcessInfo> EnumerateEditorProcesses();
}

internal sealed record ExternalEditorProcessInfo(
    int ProcessId,
    string ProjectRoot,
    string ExecutablePath,
    string CommandLine);

internal sealed class NullExternalEditorProcessProbe : IExternalEditorProcessProbe
{
    public IEnumerable<ExternalEditorProcessInfo> EnumerateEditorProcesses()
    {
        return Array.Empty<ExternalEditorProcessInfo>();
    }
}

internal sealed class WindowsWmiExternalEditorProcessProbe : IExternalEditorProcessProbe
{
    public IEnumerable<ExternalEditorProcessInfo> EnumerateEditorProcesses()
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
            projectRoot = Path.GetFullPath(Environment.ExpandEnvironmentVariables(value))
                .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            return !string.IsNullOrWhiteSpace(projectRoot);
        }
        catch
        {
            projectRoot = string.Empty;
            return false;
        }
    }
}
