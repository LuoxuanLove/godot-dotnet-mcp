using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace GodotDotnetMcp.HostShared;

internal static class WorkspacePathResolver
{
    public static string ResolveExistingPath(string path)
    {
        var resolved = ResolvePath(path);
        if (!File.Exists(resolved) && !Directory.Exists(resolved))
        {
            throw new BridgeToolException($"Path does not exist: {path}");
        }

        return resolved;
    }

    public static string ResolveSolutionFile(string path)
    {
        var resolved = ResolvePath(path);
        if (Directory.Exists(resolved))
        {
            var solutionFiles = Directory.GetFiles(resolved, "*.sln", SearchOption.TopDirectoryOnly);
            if (solutionFiles.Length == 0)
            {
                throw new BridgeToolException($"No .sln file found in directory: {path}");
            }

            if (solutionFiles.Length > 1)
            {
                throw new BridgeToolException($"Multiple .sln files found in directory: {path}. Please specify one explicitly.");
            }

            return Path.GetFullPath(solutionFiles[0]);
        }

        if (!resolved.EndsWith(".sln", StringComparison.OrdinalIgnoreCase))
        {
            throw new BridgeToolException("solution_analyze requires a .sln file or a directory containing exactly one .sln file.");
        }

        if (!File.Exists(resolved))
        {
            throw new BridgeToolException($"Solution file not found: {path}");
        }

        return resolved;
    }

    public static string? FindNearestProjectFile(string path)
    {
        var currentDirectory = File.Exists(path) ? Path.GetDirectoryName(path) : path;
        if (string.IsNullOrWhiteSpace(currentDirectory))
        {
            return null;
        }

        var directory = new DirectoryInfo(currentDirectory);
        while (directory is not null)
        {
            var projectFiles = directory.GetFiles("*.csproj", SearchOption.TopDirectoryOnly);
            if (projectFiles.Length > 0)
            {
                return projectFiles[0].FullName;
            }

            directory = directory.Parent;
        }

        return null;
    }

    private static string ResolvePath(string path)
    {
        return Path.GetFullPath(Environment.ExpandEnvironmentVariables(path));
    }
}

internal sealed record DotnetBuildResult(
    string Path,
    string Operation,
    string CommandLine,
    int ExitCode,
    bool Success,
    long DurationMs,
    string StdOut,
    string StdErr,
    IReadOnlyList<DiagnosticSummary> Diagnostics,
    IReadOnlyDictionary<string, int> Summary);

internal static class DotnetCliRunner
{
    public static async Task<DotnetBuildResult> RunAsync(string path, string operation, string configuration, string? framework, string verbosity, CancellationToken cancellationToken)
    {
        if (operation is not ("restore" or "build" or "test"))
        {
            throw new BridgeToolException("dotnet_build operation must be restore, build, or test.");
        }

        if (!File.Exists(path))
        {
            throw new BridgeToolException($"dotnet_build target does not exist: {path}");
        }

        var workingDirectory = Path.GetDirectoryName(path) ?? Environment.CurrentDirectory;
        var psi = new ProcessStartInfo("dotnet")
        {
            WorkingDirectory = workingDirectory,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };

        psi.ArgumentList.Add(operation);
        psi.ArgumentList.Add(path);
        psi.ArgumentList.Add("-nologo");
        psi.ArgumentList.Add("-v");
        psi.ArgumentList.Add(verbosity);
        psi.ArgumentList.Add("-p:Configuration=" + configuration);

        if (!string.IsNullOrWhiteSpace(framework))
        {
            psi.ArgumentList.Add("-p:TargetFramework=" + framework);
        }

        var commandLine = BuildCommandLine(psi);
        var stopwatch = Stopwatch.StartNew();

        using var process = new Process { StartInfo = psi, EnableRaisingEvents = true };
        if (!process.Start())
        {
            throw new BridgeToolException("Failed to start dotnet process.");
        }

        var stdoutTask = process.StandardOutput.ReadToEndAsync();
        var stderrTask = process.StandardError.ReadToEndAsync();

        await process.WaitForExitAsync(cancellationToken);
        var stdout = await stdoutTask;
        var stderr = await stderrTask;
        stopwatch.Stop();

        var diagnostics = ParseDiagnostics(stdout + Environment.NewLine + stderr);

        return new DotnetBuildResult(
            Path: path,
            Operation: operation,
            CommandLine: commandLine,
            ExitCode: process.ExitCode,
            Success: process.ExitCode == 0,
            DurationMs: (long)stopwatch.Elapsed.TotalMilliseconds,
            StdOut: stdout,
            StdErr: stderr,
            Diagnostics: diagnostics,
            Summary: DiagnosticSummaryExtensions.BuildSummary(diagnostics));
    }

    private static IReadOnlyList<DiagnosticSummary> ParseDiagnostics(string text)
    {
        var diagnostics = new List<DiagnosticSummary>();
        var regex = new Regex(
            @"^(?<file>.+?)\((?<line>\d+),(?<column>\d+)\):\s+(?<severity>error|warning)\s+(?<code>[A-Z]+\d+):\s+(?<message>.+)$",
            RegexOptions.Compiled | RegexOptions.Multiline | RegexOptions.CultureInvariant);

        foreach (Match match in regex.Matches(text))
        {
            diagnostics.Add(new DiagnosticSummary(
                Severity: match.Groups["severity"].Value,
                Code: match.Groups["code"].Value,
                Message: match.Groups["message"].Value.Trim(),
                FilePath: match.Groups["file"].Value.Trim(),
                Line: int.Parse(match.Groups["line"].Value, CultureInfo.InvariantCulture),
                Column: int.Parse(match.Groups["column"].Value, CultureInfo.InvariantCulture)));
        }

        return diagnostics;
    }

    private static string BuildCommandLine(ProcessStartInfo psi)
    {
        var builder = new StringBuilder(psi.FileName);
        foreach (var argument in psi.ArgumentList)
        {
            builder.Append(' ');
            builder.Append(Quote(argument));
        }

        return builder.ToString();
    }

    private static string Quote(string value)
    {
        return value.Contains(' ') || value.Contains('"')
            ? "\"" + value.Replace("\"", "\\\"", StringComparison.Ordinal) + "\""
            : value;
    }
}
