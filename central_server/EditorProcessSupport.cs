using System.Diagnostics;
using System.Net;
using System.Net.Sockets;

namespace GodotDotnetMcp.CentralServer;

internal static class EditorProcessSupport
{
    public static bool IsProcessRunning(int processId)
    {
        return TryGetLiveProcess(processId, out _);
    }

    public static bool TryGetLiveProcess(int processId, out Process? process)
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

    public static int GetFreeTcpPort()
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

    public static string ResolveProjectRoot(string? projectRoot, string fallbackProjectRoot)
    {
        if (!string.IsNullOrWhiteSpace(projectRoot))
        {
            return NormalizeProjectRoot(projectRoot);
        }

        return NormalizeProjectRoot(fallbackProjectRoot);
    }

    public static string NormalizeProjectRoot(string projectRoot)
    {
        return Path.GetFullPath(Environment.ExpandEnvironmentVariables(projectRoot))
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
    }

    public static DateTimeOffset? TryGetProcessStartTime(int processId)
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
}
