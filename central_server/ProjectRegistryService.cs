using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class ProjectRegistryService
{
    private static readonly HashSet<string> IgnoredDirectoryNames = new(StringComparer.OrdinalIgnoreCase)
    {
        ".git",
        ".godot",
        ".import",
        ".mono",
        ".vs",
        ".vscode",
        "bin",
        "obj",
        "Library",
        "Temp",
    };

    private readonly string _storeDirectory;
    private readonly string _storePath;
    private readonly Dictionary<string, RegisteredProject> _projects = new(StringComparer.OrdinalIgnoreCase);

    public ProjectRegistryService()
    {
        _storeDirectory = CentralServerPaths.GetStoreDirectory();
        _storePath = Path.Combine(_storeDirectory, "projects.json");
        Load();
    }

    public string StorePath => _storePath;

    public IReadOnlyList<RegisteredProject> ListProjects()
    {
        return _projects.Values
            .OrderBy(project => project.ProjectName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(project => project.ProjectRoot, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public IReadOnlyList<string> GetRegisteredProjectRoots()
    {
        return _projects.Values
            .Select(project => project.ProjectRoot)
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public RegisteredProject RegisterProject(string projectPath, string source = "manual")
    {
        var projectRoot = ResolveProjectRoot(projectPath);
        var existing = FindByRoot(projectRoot);
        if (existing is not null)
        {
            return existing;
        }

        var project = new RegisteredProject
        {
            ProjectId = Guid.NewGuid().ToString("N"),
            ProjectName = ReadProjectName(projectRoot),
            ProjectRoot = projectRoot,
            GodotProjectFile = Path.Combine(projectRoot, "project.godot"),
            SolutionPath = FindSolutionPath(projectRoot),
            Source = source,
            VerificationStatus = "valid",
            CreatedAtUtc = DateTimeOffset.UtcNow,
            LastVerifiedAtUtc = DateTimeOffset.UtcNow,
        };

        _projects[project.ProjectId] = project;
        Save();
        return project;
    }

    public RegisteredProject AssignGodotExecutablePath(string projectId, string executablePath)
    {
        if (!_projects.TryGetValue(projectId, out var project))
        {
            throw new CentralToolException("Registered project not found.");
        }

        var normalizedPath = Path.GetFullPath(Environment.ExpandEnvironmentVariables(executablePath));
        if (!File.Exists(normalizedPath))
        {
            throw new CentralToolException($"Godot executable not found: {executablePath}");
        }

        project.GodotExecutablePath = normalizedPath;
        project.LastVerifiedAtUtc = DateTimeOffset.UtcNow;
        Save();
        return project;
    }

    public bool RemoveProject(string? projectId, string? projectPath, out RegisteredProject? removedProject)
    {
        removedProject = null;
        var project = ResolveProject(projectId, projectPath);
        if (project is null)
        {
            return false;
        }

        if (_projects.Remove(project.ProjectId))
        {
            Save();
            removedProject = project;
            return true;
        }

        return false;
    }

    public RegisteredProject? ResolveProject(string? projectId, string? projectPath)
    {
        if (!string.IsNullOrWhiteSpace(projectId) && _projects.TryGetValue(projectId, out var byId))
        {
            return byId;
        }

        if (!string.IsNullOrWhiteSpace(projectPath))
        {
            var projectRoot = ResolveProjectRoot(projectPath);
            return FindByRoot(projectRoot);
        }

        return null;
    }

    public RescanResult RescanProjects(IReadOnlyList<string> roots, bool importDiscovered)
    {
        var normalizedRoots = roots
            .Where(root => !string.IsNullOrWhiteSpace(root))
            .Select(root => Path.GetFullPath(Environment.ExpandEnvironmentVariables(root)))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var discoveredRoots = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var imported = new List<RegisteredProject>();
        var duplicates = new List<string>();

        foreach (var root in normalizedRoots)
        {
            if (!Directory.Exists(root))
            {
                continue;
            }

            foreach (var projectRoot in EnumerateProjectRoots(root))
            {
                discoveredRoots.Add(projectRoot);
                var existing = FindByRoot(projectRoot);
                if (existing is not null)
                {
                    duplicates.Add(projectRoot);
                    continue;
                }

                if (importDiscovered)
                {
                    imported.Add(RegisterProject(projectRoot, "workspace_scan"));
                }
            }
        }

        return new RescanResult
        {
            Roots = normalizedRoots,
            DiscoveredProjectRoots = discoveredRoots.OrderBy(path => path, StringComparer.OrdinalIgnoreCase).ToArray(),
            ImportedProjects = imported,
            DuplicateProjectRoots = duplicates.Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(path => path, StringComparer.OrdinalIgnoreCase).ToArray(),
        };
    }

    public ServiceStatus BuildStatus(string activeProjectId)
    {
        var activeProject = ResolveProject(activeProjectId, null);
        return new ServiceStatus
        {
            RegisteredProjectCount = _projects.Count,
            ActiveProjectId = activeProjectId,
            ActiveProjectName = activeProject?.ProjectName ?? string.Empty,
            StorePath = _storePath,
            LastUpdatedAtUtc = _projects.Values.Count == 0
                ? null
                : _projects.Values.Max(project => project.LastVerifiedAtUtc),
        };
    }

    private RegisteredProject? FindByRoot(string projectRoot)
    {
        return _projects.Values.FirstOrDefault(project =>
            string.Equals(project.ProjectRoot, projectRoot, StringComparison.OrdinalIgnoreCase));
    }

    private static string ResolveProjectRoot(string projectPath)
    {
        var resolved = Path.GetFullPath(Environment.ExpandEnvironmentVariables(projectPath));
        if (File.Exists(resolved) && string.Equals(Path.GetFileName(resolved), "project.godot", StringComparison.OrdinalIgnoreCase))
        {
            return Path.GetDirectoryName(resolved)
                   ?? throw new CentralToolException($"Invalid project path: {projectPath}");
        }

        if (!Directory.Exists(resolved))
        {
            throw new CentralToolException($"Project directory not found: {projectPath}");
        }

        var projectFile = Path.Combine(resolved, "project.godot");
        if (!File.Exists(projectFile))
        {
            throw new CentralToolException($"Not a Godot project root (missing project.godot): {resolved}");
        }

        return resolved;
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

    private static string? FindSolutionPath(string projectRoot)
    {
        return Directory.EnumerateFiles(projectRoot, "*.sln", SearchOption.TopDirectoryOnly)
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault();
    }

    private static IEnumerable<string> EnumerateProjectRoots(string root)
    {
        var stack = new Stack<string>();
        stack.Push(root);

        while (stack.Count > 0)
        {
            var current = stack.Pop();
            if (File.Exists(Path.Combine(current, "project.godot")))
            {
                yield return current;
                continue;
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

    private void Load()
    {
        _projects.Clear();
        if (!File.Exists(_storePath))
        {
            return;
        }

        var json = File.ReadAllText(_storePath);
        var store = JsonSerializer.Deserialize<ProjectStore>(json, CentralServerSerialization.JsonOptions);
        if (store?.Projects is null)
        {
            return;
        }

        foreach (var project in store.Projects)
        {
            if (string.IsNullOrWhiteSpace(project.ProjectId) || string.IsNullOrWhiteSpace(project.ProjectRoot))
            {
                continue;
            }

            _projects[project.ProjectId] = project;
        }
    }

    private void Save()
    {
        Directory.CreateDirectory(_storeDirectory);
        var store = new ProjectStore
        {
            Projects = ListProjects().ToList(),
        };
        var json = JsonSerializer.Serialize(store, CentralServerSerialization.JsonOptions);
        File.WriteAllText(_storePath, json);
    }

    internal sealed class RegisteredProject
    {
        public string ProjectId { get; set; } = string.Empty;

        public string ProjectName { get; set; } = string.Empty;

        public string ProjectRoot { get; set; } = string.Empty;

        public string GodotProjectFile { get; set; } = string.Empty;

        public string? SolutionPath { get; set; }

        public string? GodotExecutablePath { get; set; }

        public string Source { get; set; } = "manual";

        public string VerificationStatus { get; set; } = "valid";

        public DateTimeOffset CreatedAtUtc { get; set; }

        public DateTimeOffset LastVerifiedAtUtc { get; set; }
    }

    internal sealed class RescanResult
    {
        public IReadOnlyList<string> Roots { get; set; } = Array.Empty<string>();

        public IReadOnlyList<string> DiscoveredProjectRoots { get; set; } = Array.Empty<string>();

        public IReadOnlyList<RegisteredProject> ImportedProjects { get; set; } = Array.Empty<RegisteredProject>();

        public IReadOnlyList<string> DuplicateProjectRoots { get; set; } = Array.Empty<string>();
    }

    internal sealed class ServiceStatus
    {
        public int RegisteredProjectCount { get; set; }

        public string ActiveProjectId { get; set; } = string.Empty;

        public string ActiveProjectName { get; set; } = string.Empty;

        public string StorePath { get; set; } = string.Empty;

        public DateTimeOffset? LastUpdatedAtUtc { get; set; }
    }

    private sealed class ProjectStore
    {
        public List<RegisteredProject> Projects { get; set; } = [];
    }
}
