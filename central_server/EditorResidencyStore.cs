using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorResidencyStore
{
    private readonly string _storeDirectory;
    private readonly string _storePath;
    private readonly Dictionary<string, ResidencyEntry> _entries = new(StringComparer.OrdinalIgnoreCase);

    public EditorResidencyStore()
    {
        _storeDirectory = CentralServerPaths.GetStoreDirectory();
        _storePath = Path.Combine(_storeDirectory, "editor_residency.json");
        Load();
    }

    public string StorePath => _storePath;

    public ResidencyEntry? Get(string projectId)
    {
        return _entries.TryGetValue(projectId, out var entry)
            ? entry with { }
            : null;
    }

    public ResidencyEntry? FindByProjectRoot(string? projectRoot)
    {
        if (string.IsNullOrWhiteSpace(projectRoot))
        {
            return null;
        }

        var normalizedProjectRoot = NormalizeProjectRoot(projectRoot);
        return _entries.Values
            .Where(entry => !string.IsNullOrWhiteSpace(entry.ProjectRoot)
                            && string.Equals(NormalizeProjectRoot(entry.ProjectRoot), normalizedProjectRoot, StringComparison.OrdinalIgnoreCase))
            .OrderByDescending(entry => entry.StartedAtUtc)
            .FirstOrDefault()
            is { } entry
                ? entry with { }
                : null;
    }

    public void Upsert(ResidencyEntry entry)
    {
        if (string.IsNullOrWhiteSpace(entry.ProjectId))
        {
            return;
        }

        _entries[entry.ProjectId] = entry with { };
        Save();
    }

    public bool Remove(string projectId)
    {
        var removed = _entries.Remove(projectId);
        if (removed)
        {
            Save();
        }

        return removed;
    }

    public void Prune(Func<int, bool> isProcessRunning)
    {
        var staleProjectIds = _entries.Values
            .Where(entry => entry.ProcessId <= 0 || !isProcessRunning(entry.ProcessId))
            .Select(entry => entry.ProjectId)
            .ToArray();

        if (staleProjectIds.Length == 0)
        {
            return;
        }

        foreach (var projectId in staleProjectIds)
        {
            _entries.Remove(projectId);
        }

        Save();
    }

    private void Load()
    {
        if (!File.Exists(_storePath))
        {
            return;
        }

        try
        {
            var json = File.ReadAllText(_storePath);
            var store = JsonSerializer.Deserialize<ResidencyStoreData>(json, CentralServerSerialization.JsonOptions);
            if (store?.Entries is null)
            {
                return;
            }

            _entries.Clear();
            foreach (var entry in store.Entries.Where(entry => entry is not null && !string.IsNullOrWhiteSpace(entry.ProjectId)))
            {
                _entries[entry!.ProjectId] = entry!;
            }
        }
        catch
        {
            _entries.Clear();
        }
    }

    private void Save()
    {
        Directory.CreateDirectory(_storeDirectory);
        var store = new ResidencyStoreData
        {
            Entries = _entries.Values
                .OrderBy(entry => entry.ProjectId, StringComparer.OrdinalIgnoreCase)
                .ToArray(),
        };
        var json = JsonSerializer.Serialize(store, CentralServerSerialization.JsonOptions);
        File.WriteAllText(_storePath, json);
    }

    internal sealed record ResidencyEntry
    {
        public string ProjectId { get; init; } = string.Empty;

        public string ProjectRoot { get; init; } = string.Empty;

        public int ProcessId { get; init; }

        public DateTimeOffset StartedAtUtc { get; init; }

        public string ExecutablePath { get; init; } = string.Empty;

        public string ExecutableSource { get; init; } = string.Empty;

        public string ServerHost { get; init; } = string.Empty;

        public int ServerPort { get; init; }

        public string LaunchReason { get; init; } = string.Empty;
    }

    private sealed class ResidencyStoreData
    {
        public ResidencyEntry[] Entries { get; set; } = [];
    }

    private static string NormalizeProjectRoot(string projectRoot)
    {
        if (string.IsNullOrWhiteSpace(projectRoot))
        {
            return string.Empty;
        }

        return Path.GetFullPath(Environment.ExpandEnvironmentVariables(projectRoot))
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
    }
}
