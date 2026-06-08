using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace GodotDotnetMcp.DotnetBridge;

internal static class WorkspacePathResolver
{
    private static readonly string ProjectRoot = ResolveProjectRoot();

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
        var resolvedPath = ResolvePath(path);
        var currentDirectory = File.Exists(resolvedPath) ? Path.GetDirectoryName(resolvedPath) : resolvedPath;
        if (string.IsNullOrWhiteSpace(currentDirectory))
        {
            return null;
        }

        var directory = new DirectoryInfo(currentDirectory);
        var root = new DirectoryInfo(ProjectRoot);
        while (directory is not null && IsPathInsideProject(directory.FullName))
        {
            var projectFiles = directory.GetFiles("*.csproj", SearchOption.TopDirectoryOnly);
            if (projectFiles.Length > 0)
            {
                return projectFiles[0].FullName;
            }

            if (SamePath(directory.FullName, root.FullName))
            {
                break;
            }

            directory = directory.Parent;
        }

        return null;
    }

    private static string ResolvePath(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            throw new BridgeToolException("Path is required.");
        }

        var normalized = Environment.ExpandEnvironmentVariables(path.Trim()).Replace('\\', '/');
        if (normalized.StartsWith("user://", StringComparison.OrdinalIgnoreCase))
        {
            throw ProjectPathException(path);
        }

        var candidate = normalized.StartsWith("res://", StringComparison.OrdinalIgnoreCase)
            ? Path.Combine(ProjectRoot, normalized["res://".Length..].TrimStart('/'))
            : normalized;

        if (HasUriScheme(candidate) || HasTraversalSegment(candidate))
        {
            throw ProjectPathException(path);
        }

        var resolved = Path.GetFullPath(candidate, ProjectRoot);
        if (!IsPathInsideProject(resolved))
        {
            throw ProjectPathException(path);
        }

        if (PathUsesReparsePointSegment(ProjectRoot, resolved))
        {
            throw ProjectPathException(path);
        }

        return resolved;
    }

    private static string ResolveProjectRoot()
    {
        var candidates = new List<string?>
        {
            Environment.GetEnvironmentVariable("GODOT_DOTNET_MCP_PROJECT_ROOT"),
            Environment.CurrentDirectory,
            AppContext.BaseDirectory,
            Path.GetDirectoryName(typeof(WorkspacePathResolver).Assembly.Location)
        };

        foreach (var candidate in candidates)
        {
            var root = FindProjectRootFrom(candidate);
            if (root is null)
            {
                continue;
            }

            var filesystemRoot = Path.GetPathRoot(root) ?? root;
            if (PathUsesReparsePointSegment(filesystemRoot, root))
            {
                throw new BridgeToolException("The .NET bridge project root must not traverse symlink, junction, or reparse-point segments.");
            }

            return root;
        }

        throw new BridgeToolException("The .NET bridge project root must point at a Godot project directory containing project.godot.");
    }

    private static string? FindProjectRootFrom(string? startPath)
    {
        if (string.IsNullOrWhiteSpace(startPath))
        {
            return null;
        }

        var resolved = Path.GetFullPath(Environment.ExpandEnvironmentVariables(startPath));
        if (File.Exists(resolved))
        {
            resolved = Path.GetDirectoryName(resolved) ?? resolved;
        }

        var directory = new DirectoryInfo(resolved);
        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "project.godot")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        return null;
    }

    private static bool IsPathInsideProject(string path)
    {
        var resolved = Path.GetFullPath(path);
        return SamePath(resolved, ProjectRoot)
            || resolved.StartsWith(EnsureTrailingSeparator(ProjectRoot), PathComparison);
    }

    private static bool SamePath(string left, string right)
    {
        return string.Equals(
            Path.TrimEndingDirectorySeparator(Path.GetFullPath(left)),
            Path.TrimEndingDirectorySeparator(Path.GetFullPath(right)),
            PathComparison);
    }

    private static bool HasUriScheme(string path)
    {
        var marker = path.IndexOf(':', StringComparison.Ordinal);
        if (marker <= 0)
        {
            return false;
        }

        for (var index = 0; index < marker; index++)
        {
            var character = path[index];
            if (index == 0 && !char.IsAsciiLetter(character))
            {
                return false;
            }

            if (!char.IsAsciiLetterOrDigit(character) && character is not '+' and not '-' and not '.')
            {
                return false;
            }
        }

        if (OperatingSystem.IsWindows() && marker == 1 && path.Length > 2 && (path[2] == '/' || path[2] == '\\'))
        {
            return false;
        }

        return !path.StartsWith("res://", StringComparison.OrdinalIgnoreCase);
    }

    private static bool HasTraversalSegment(string path)
    {
        var normalized = path.Replace('\\', '/');
        foreach (var segment in normalized.Split('/', StringSplitOptions.RemoveEmptyEntries))
        {
            if (segment is "." or "..")
            {
                return true;
            }
        }

        return false;
    }

    private static bool PathUsesReparsePointSegment(string rootPath, string path)
    {
        var root = Path.GetFullPath(rootPath);
        var resolved = Path.GetFullPath(path);
        if (SamePath(resolved, root))
        {
            return IsReparsePoint(resolved);
        }

        var relativePath = Path.GetRelativePath(root, resolved);
        if (IsParentRelativePath(relativePath) || Path.IsPathRooted(relativePath))
        {
            return true;
        }

        var currentPath = root;
        foreach (var segment in relativePath.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar))
        {
            if (string.IsNullOrWhiteSpace(segment))
            {
                continue;
            }

            currentPath = Path.Combine(currentPath, segment);
            if (!File.Exists(currentPath) && !Directory.Exists(currentPath))
            {
                return false;
            }

            if (IsReparsePoint(currentPath))
            {
                return true;
            }
        }

        return false;
    }

    private static bool IsReparsePoint(string path)
    {
        try
        {
            return (File.GetAttributes(path) & FileAttributes.ReparsePoint) == FileAttributes.ReparsePoint;
        }
        catch (IOException)
        {
            return true;
        }
        catch (UnauthorizedAccessException)
        {
            return true;
        }
    }

    private static bool IsParentRelativePath(string path)
    {
        return string.Equals(path, "..", StringComparison.Ordinal)
            || path.StartsWith("../", StringComparison.Ordinal)
            || path.StartsWith(@"..\", StringComparison.Ordinal);
    }

    private static string EnsureTrailingSeparator(string path)
    {
        var normalized = Path.GetFullPath(path);
        return Path.EndsInDirectorySeparator(normalized)
            ? normalized
            : normalized + Path.DirectorySeparatorChar;
    }

    private static BridgeToolException ProjectPathException(string path)
    {
        return new BridgeToolException($"Path must stay inside the Godot project root and avoid traversal or external schemes: {path}");
    }

    private static StringComparison PathComparison =>
        OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;
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
