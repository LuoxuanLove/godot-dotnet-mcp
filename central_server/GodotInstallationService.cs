namespace GodotDotnetMcp.CentralServer;

internal sealed class GodotInstallationService
{
    private static readonly string[] IgnoredExecutableTokens =
    [
        "CentralServer",
    ];

    private static readonly HashSet<string> IgnoredDirectoryNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "WindowsApps",
        "$Recycle.Bin",
        "System Volume Information",
    };

    private static readonly string[] CandidateRoots =
    [
        Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
        Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads"),
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
    ];

    public IReadOnlyList<GodotInstallationCandidate> ListCandidates()
    {
        var candidates = new Dictionary<string, GodotInstallationCandidate>(StringComparer.OrdinalIgnoreCase);

        foreach (var root in CandidateRoots)
        {
            if (string.IsNullOrWhiteSpace(root) || !Directory.Exists(root))
            {
                continue;
            }

            foreach (var file in EnumerateExecutableCandidates(root))
            {
                if (IgnoredExecutableTokens.Any(token => file.Contains(token, StringComparison.OrdinalIgnoreCase)))
                {
                    // These binaries are MCP host tools, not actual Godot editor executables.
                    continue;
                }

                if (candidates.ContainsKey(file))
                {
                    continue;
                }

                candidates[file] = new GodotInstallationCandidate
                {
                    ExecutablePath = file,
                    DisplayName = Path.GetFileName(file),
                    Source = root,
                };
            }
        }

        return candidates.Values
            .OrderBy(candidate => candidate.DisplayName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(candidate => candidate.ExecutablePath, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public GodotExecutableResolution ResolveExecutable(
        ProjectRegistryService.RegisteredProject? project,
        string explicitExecutablePath,
        CentralConfigurationService configuration)
    {
        if (!string.IsNullOrWhiteSpace(explicitExecutablePath))
        {
            var normalizedPath = NormalizeExecutablePath(explicitExecutablePath);
            return new GodotExecutableResolution
            {
                ExecutablePath = normalizedPath,
                Source = "explicit",
            };
        }

        if (project is not null && !string.IsNullOrWhiteSpace(project.GodotExecutablePath))
        {
            var normalizedPath = NormalizeExecutablePath(project.GodotExecutablePath);
            return new GodotExecutableResolution
            {
                ExecutablePath = normalizedPath,
                Source = "project",
            };
        }

        if (configuration.HasDefaultGodotExecutable)
        {
            return new GodotExecutableResolution
            {
                ExecutablePath = configuration.DefaultGodotExecutablePath,
                Source = "default",
            };
        }

        var candidate = ListCandidates().FirstOrDefault();
        if (candidate is not null)
        {
            return new GodotExecutableResolution
            {
                ExecutablePath = candidate.ExecutablePath,
                Source = "discovered",
            };
        }

        throw new CentralToolException("No Godot executable is configured or discoverable.");
    }

    private static IEnumerable<string> EnumerateExecutableCandidates(string root)
    {
        var stack = new Stack<string>();
        stack.Push(root);

        while (stack.Count > 0)
        {
            var current = stack.Pop();
            IEnumerable<string> files;
            try
            {
                files = Directory.EnumerateFiles(current, "Godot*.exe", SearchOption.TopDirectoryOnly);
            }
            catch (UnauthorizedAccessException)
            {
                continue;
            }
            catch (IOException)
            {
                continue;
            }

            foreach (var file in files)
            {
                yield return file;
            }

            IEnumerable<string> childDirectories;
            try
            {
                childDirectories = Directory.EnumerateDirectories(current);
            }
            catch (UnauthorizedAccessException)
            {
                continue;
            }
            catch (IOException)
            {
                continue;
            }

            foreach (var child in childDirectories)
            {
                var name = Path.GetFileName(child);
                if (IgnoredDirectoryNames.Contains(name))
                {
                    continue;
                }

                stack.Push(child);
            }
        }
    }

    private static string NormalizeExecutablePath(string executablePath)
    {
        var normalizedPath = Path.GetFullPath(Environment.ExpandEnvironmentVariables(executablePath));
        if (!File.Exists(normalizedPath))
        {
            throw new CentralToolException($"Godot executable not found: {executablePath}");
        }

        return normalizedPath;
    }

    internal sealed class GodotInstallationCandidate
    {
        public string ExecutablePath { get; set; } = string.Empty;

        public string DisplayName { get; set; } = string.Empty;

        public string Source { get; set; } = string.Empty;
    }

    internal sealed class GodotExecutableResolution
    {
        public string ExecutablePath { get; set; } = string.Empty;

        public string Source { get; set; } = string.Empty;
    }
}
