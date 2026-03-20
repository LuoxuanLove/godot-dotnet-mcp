namespace GodotDotnetMcp.CentralServer;

internal sealed class GodotProjectManagerProvider
{
    private readonly CentralConfigurationService _configuration;
    private readonly GodotProjectManagerWatcher _watcher;

    public GodotProjectManagerProvider(CentralConfigurationService configuration)
    {
        _configuration = configuration;
        _watcher = new GodotProjectManagerWatcher(ConfigDirectoryPath, ProjectsConfigPath);
    }

    public string ConfigDirectoryPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "Godot");

    public string ProjectsConfigPath => Path.Combine(ConfigDirectoryPath, "projects.cfg");

    public void StartWatcher()
    {
        _watcher.Start();
    }

    public ProjectManagerStatus GetStatus(IReadOnlyCollection<string> registeredProjectRoots)
    {
        var candidates = ListProjects(registeredProjectRoots);
        return new ProjectManagerStatus
        {
            ConfigDirectoryPath = ConfigDirectoryPath,
            ConfigDirectoryExists = Directory.Exists(ConfigDirectoryPath),
            ProjectsConfigPath = ProjectsConfigPath,
            ProjectsConfigExists = File.Exists(ProjectsConfigPath),
            CandidateCount = candidates.Count,
            LastScannedAtUtc = DateTimeOffset.UtcNow,
            DefaultGodotExecutablePath = _configuration.DefaultGodotExecutablePath,
            DefaultGodotExecutableExists = _configuration.HasDefaultGodotExecutable,
            Watcher = _watcher.GetStatus(),
        };
    }

    public IReadOnlyList<ProjectManagerCandidate> ListProjects(IReadOnlyCollection<string> registeredProjectRoots)
    {
        if (!File.Exists(ProjectsConfigPath))
        {
            return Array.Empty<ProjectManagerCandidate>();
        }

        var registeredRoots = new HashSet<string>(registeredProjectRoots, StringComparer.OrdinalIgnoreCase);
        var candidates = new List<ProjectManagerCandidate>();
        string? currentPath = null;
        var currentFavorite = false;

        foreach (var rawLine in File.ReadLines(ProjectsConfigPath))
        {
            var line = rawLine.Trim();
            if (string.IsNullOrWhiteSpace(line))
            {
                if (!string.IsNullOrWhiteSpace(currentPath))
                {
                    candidates.Add(BuildCandidate(currentPath, currentFavorite, registeredRoots));
                    currentPath = null;
                    currentFavorite = false;
                }
                continue;
            }

            if (line.StartsWith('[') && line.EndsWith(']'))
            {
                if (!string.IsNullOrWhiteSpace(currentPath))
                {
                    candidates.Add(BuildCandidate(currentPath, currentFavorite, registeredRoots));
                    currentFavorite = false;
                }

                currentPath = line[1..^1];
                continue;
            }

            if (line.StartsWith("favorite=", StringComparison.OrdinalIgnoreCase))
            {
                currentFavorite = line.EndsWith("true", StringComparison.OrdinalIgnoreCase);
            }
        }

        if (!string.IsNullOrWhiteSpace(currentPath))
        {
            candidates.Add(BuildCandidate(currentPath, currentFavorite, registeredRoots));
        }

        return candidates
            .OrderBy(candidate => candidate.ProjectName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(candidate => candidate.ProjectRoot, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private ProjectManagerCandidate BuildCandidate(string rawProjectRoot, bool favorite, IReadOnlyCollection<string> registeredRoots)
    {
        var projectRoot = Path.GetFullPath(Environment.ExpandEnvironmentVariables(rawProjectRoot));
        var projectFile = Path.Combine(projectRoot, "project.godot");
        var exists = Directory.Exists(projectRoot);
        var hasProjectFile = File.Exists(projectFile);
        var projectName = hasProjectFile ? ReadProjectName(projectRoot) : new DirectoryInfo(projectRoot).Name;

        return new ProjectManagerCandidate
        {
            CandidateId = $"{projectRoot.ToLowerInvariant()}::{favorite}",
            ProjectRoot = projectRoot,
            ProjectName = projectName,
            Exists = exists,
            HasProjectFile = hasProjectFile,
            AlreadyRegistered = registeredRoots.Contains(projectRoot),
            Favorite = favorite,
            PendingImport = exists && hasProjectFile && !registeredRoots.Contains(projectRoot),
            DiscoveredFrom = ProjectsConfigPath,
            LastSeenAtUtc = DateTimeOffset.UtcNow,
        };
    }

    private static string ReadProjectName(string projectRoot)
    {
        var projectFile = Path.Combine(projectRoot, "project.godot");
        foreach (var line in File.ReadLines(projectFile))
        {
            if (!line.StartsWith("config/name=", StringComparison.Ordinal))
            {
                continue;
            }

            var value = line["config/name=".Length..].Trim();
            if (value.Length >= 2 && value.StartsWith('"') && value.EndsWith('"'))
            {
                value = value[1..^1];
            }

            if (!string.IsNullOrWhiteSpace(value))
            {
                return value;
            }
        }

        return new DirectoryInfo(projectRoot).Name;
    }

    internal sealed class ProjectManagerCandidate
    {
        public string CandidateId { get; set; } = string.Empty;

        public string ProjectRoot { get; set; } = string.Empty;

        public string ProjectName { get; set; } = string.Empty;

        public bool Exists { get; set; }

        public bool HasProjectFile { get; set; }

        public bool AlreadyRegistered { get; set; }

        public bool Favorite { get; set; }

        public bool PendingImport { get; set; }

        public string DiscoveredFrom { get; set; } = string.Empty;

        public DateTimeOffset LastSeenAtUtc { get; set; }
    }

    internal sealed class ProjectManagerStatus
    {
        public string ConfigDirectoryPath { get; set; } = string.Empty;

        public bool ConfigDirectoryExists { get; set; }

        public string ProjectsConfigPath { get; set; } = string.Empty;

        public bool ProjectsConfigExists { get; set; }

        public int CandidateCount { get; set; }

        public DateTimeOffset LastScannedAtUtc { get; set; }

        public string DefaultGodotExecutablePath { get; set; } = string.Empty;

        public bool DefaultGodotExecutableExists { get; set; }

        public GodotProjectManagerWatcher.WatcherStatus? Watcher { get; set; }
    }
}
