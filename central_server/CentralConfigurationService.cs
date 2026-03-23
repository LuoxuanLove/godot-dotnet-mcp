using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class CentralConfigurationService
{
    private readonly string _storeDirectory;
    private readonly string _storePath;
    private ConfigurationStore _store = new();

    public CentralConfigurationService()
    {
        _storeDirectory = CentralServerPaths.GetStoreDirectory();
        _storePath = Path.Combine(_storeDirectory, "config.json");
        Load();
    }

    public string StorePath => _storePath;

    public string DefaultGodotExecutablePath => _store.DefaultGodotExecutablePath ?? string.Empty;

    public bool HasDefaultGodotExecutable => !string.IsNullOrWhiteSpace(DefaultGodotExecutablePath)
                                             && File.Exists(DefaultGodotExecutablePath);

    public string EditorAttachHost => string.IsNullOrWhiteSpace(_store.EditorAttachHost)
        ? "127.0.0.1"
        : _store.EditorAttachHost;

    public int EditorAttachPort => _store.EditorAttachPort is > 0
        ? _store.EditorAttachPort.Value
        : 3020;

    public ConfigurationStatus BuildStatus()
    {
        return new ConfigurationStatus
        {
            StorePath = _storePath,
            DefaultGodotExecutablePath = DefaultGodotExecutablePath,
            DefaultGodotExecutableExists = HasDefaultGodotExecutable,
            EditorAttachHost = EditorAttachHost,
            EditorAttachPort = EditorAttachPort,
        };
    }

    public ConfigurationStatus SetDefaultGodotExecutablePath(string executablePath)
    {
        var normalizedPath = NormalizeExecutablePath(executablePath);
        _store.DefaultGodotExecutablePath = normalizedPath;
        Save();
        return BuildStatus();
    }

    public ConfigurationStatus ClearDefaultGodotExecutablePath()
    {
        _store.DefaultGodotExecutablePath = string.Empty;
        Save();
        return BuildStatus();
    }

    private void Load()
    {
        if (!File.Exists(_storePath))
        {
            return;
        }

        var json = File.ReadAllText(_storePath);
        var loaded = JsonSerializer.Deserialize<ConfigurationStore>(json, CentralServerSerialization.JsonOptions);
        if (loaded is not null)
        {
            _store = loaded;
        }
    }

    private void Save()
    {
        Directory.CreateDirectory(_storeDirectory);
        var json = JsonSerializer.Serialize(_store, CentralServerSerialization.JsonOptions);
        File.WriteAllText(_storePath, json);
    }

    private static string NormalizeExecutablePath(string executablePath)
    {
        var normalizedPath = Path.GetFullPath(Environment.ExpandEnvironmentVariables(executablePath));
        if (!File.Exists(normalizedPath))
        {
            throw new CentralToolException(
                $"Godot executable not found: {executablePath}. Ask the user to provide the correct Godot editor path before calling workspace_godot_set_default_executable.");
        }

        return normalizedPath;
    }

    internal sealed class ConfigurationStatus
    {
        public string StorePath { get; set; } = string.Empty;

        public string DefaultGodotExecutablePath { get; set; } = string.Empty;

        public bool DefaultGodotExecutableExists { get; set; }

        public string EditorAttachHost { get; set; } = string.Empty;

        public int EditorAttachPort { get; set; }
    }

    private sealed class ConfigurationStore
    {
        public string? DefaultGodotExecutablePath { get; set; }

        public string? EditorAttachHost { get; set; }

        public int? EditorAttachPort { get; set; }
    }
}
