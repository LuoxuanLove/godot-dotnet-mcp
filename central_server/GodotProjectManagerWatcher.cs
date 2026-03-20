namespace GodotDotnetMcp.CentralServer;

internal sealed class GodotProjectManagerWatcher : IDisposable
{
    private readonly string _configDirectoryPath;
    private readonly string _projectsConfigPath;
    private FileSystemWatcher? _watcher;
    private readonly object _sync = new();
    private DateTimeOffset? _startedAtUtc;
    private DateTimeOffset? _lastChangeAtUtc;
    private string _lastError = string.Empty;
    private int _changeCount;

    public GodotProjectManagerWatcher(string configDirectoryPath, string projectsConfigPath)
    {
        _configDirectoryPath = configDirectoryPath;
        _projectsConfigPath = projectsConfigPath;
    }

    public void Start()
    {
        lock (_sync)
        {
            if (_watcher is not null || !Directory.Exists(_configDirectoryPath))
            {
                return;
            }

            _watcher = new FileSystemWatcher(_configDirectoryPath, Path.GetFileName(_projectsConfigPath))
            {
                NotifyFilter = NotifyFilters.FileName | NotifyFilters.LastWrite | NotifyFilters.CreationTime,
                IncludeSubdirectories = false,
                EnableRaisingEvents = true,
            };
            _watcher.Changed += OnConfigChanged;
            _watcher.Created += OnConfigChanged;
            _watcher.Renamed += OnConfigRenamed;
            _watcher.Deleted += OnConfigChanged;
            _watcher.Error += OnWatcherError;
            _startedAtUtc = DateTimeOffset.UtcNow;
            _lastError = string.Empty;
        }
    }

    public WatcherStatus GetStatus()
    {
        lock (_sync)
        {
            return new WatcherStatus
            {
                Watching = _watcher is not null && _watcher.EnableRaisingEvents,
                ConfigDirectoryPath = _configDirectoryPath,
                ProjectsConfigPath = _projectsConfigPath,
                StartedAtUtc = _startedAtUtc,
                LastChangeAtUtc = _lastChangeAtUtc,
                ChangeCount = _changeCount,
                LastError = _lastError,
            };
        }
    }

    public void Dispose()
    {
        lock (_sync)
        {
            if (_watcher is null)
            {
                return;
            }

            _watcher.EnableRaisingEvents = false;
            _watcher.Changed -= OnConfigChanged;
            _watcher.Created -= OnConfigChanged;
            _watcher.Renamed -= OnConfigRenamed;
            _watcher.Deleted -= OnConfigChanged;
            _watcher.Error -= OnWatcherError;
            _watcher.Dispose();
            _watcher = null;
        }
    }

    private void OnConfigChanged(object sender, FileSystemEventArgs e)
    {
        lock (_sync)
        {
            _lastChangeAtUtc = DateTimeOffset.UtcNow;
            _changeCount += 1;
        }
    }

    private void OnConfigRenamed(object sender, RenamedEventArgs e)
    {
        lock (_sync)
        {
            _lastChangeAtUtc = DateTimeOffset.UtcNow;
            _changeCount += 1;
        }
    }

    private void OnWatcherError(object sender, ErrorEventArgs e)
    {
        lock (_sync)
        {
            _lastError = e.GetException().Message;
        }
    }

    internal sealed class WatcherStatus
    {
        public bool Watching { get; set; }

        public string ConfigDirectoryPath { get; set; } = string.Empty;

        public string ProjectsConfigPath { get; set; } = string.Empty;

        public DateTimeOffset? StartedAtUtc { get; set; }

        public DateTimeOffset? LastChangeAtUtc { get; set; }

        public int ChangeCount { get; set; }

        public string LastError { get; set; } = string.Empty;
    }
}
