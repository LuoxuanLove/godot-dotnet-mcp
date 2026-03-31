using System.Reflection;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace GodotDotnetMcp.HostShared;

public static class McpProtocolFacts
{
    private static readonly Lazy<ProtocolFactsSnapshot> Snapshot = new(LoadSnapshot);

    public static string ProtocolVersion => Snapshot.Value.ProtocolVersion;
    public static string ToolSchemaVersion => Snapshot.Value.ToolSchemaVersion;
    public static string ServerName => Snapshot.Value.ServerName;
    public static string ServerVersion => Snapshot.Value.ServerVersion;
    public static IReadOnlyDictionary<string, string> ErrorCodes => Snapshot.Value.ErrorCodes;

    public static string GetErrorCode(string key)
    {
        return ErrorCodes.TryGetValue(key, out var value) ? value : key;
    }

    public static class Codes
    {
        public const string BridgeVersionMismatch = "bridge_version_mismatch";
        public const string RuntimeNotRunning = "runtime_not_running";
        public const string RuntimeControlDisabled = "runtime_control_disabled";
        public const string RuntimeSessionLost = "runtime_session_lost";
        public const string RuntimeCommandTimeout = "runtime_command_timeout";
        public const string RuntimeBridgeUnavailable = "runtime_bridge_unavailable";
        public const string RuntimeCaptureFailed = "runtime_capture_failed";
        public const string InvalidArgument = "invalid_argument";
        public const string PermissionDenied = "permission_denied";
        public const string ToolLoadFailed = "tool_load_failed";
        public const string ToolRuntimeMissing = "tool_runtime_missing";
        public const string ToolExecutionFailed = "tool_execution_failed";
        public const string ParseError = "parse_error";
        public const string MissingExecutable = "missing_executable";
        public const string InvalidWorkingDirectory = "invalid_working_directory";
        public const string PrecheckReadError = "precheck_read_error";
        public const string BackupError = "backup_error";
        public const string WriteError = "write_error";
        public const string DirError = "dir_error";
    }

    private static ProtocolFactsSnapshot LoadSnapshot()
    {
        var assembly = typeof(McpProtocolFacts).Assembly;
        var resourceName = assembly
            .GetManifestResourceNames()
            .SingleOrDefault(name => name.EndsWith("mcp_protocol_facts.json", StringComparison.OrdinalIgnoreCase));
        if (string.IsNullOrWhiteSpace(resourceName))
        {
            throw new InvalidOperationException("Embedded MCP protocol facts resource was not found.");
        }

        using var stream = assembly.GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException("Unable to open embedded MCP protocol facts resource.");
        using var document = JsonDocument.Parse(stream);
        var root = document.RootElement;

        var errorCodes = new Dictionary<string, string>(StringComparer.Ordinal);
        if (root.TryGetProperty("error_codes", out var errorCodesElement) && errorCodesElement.ValueKind == JsonValueKind.Object)
        {
            foreach (var property in errorCodesElement.EnumerateObject())
            {
                errorCodes[property.Name] = property.Value.GetString() ?? string.Empty;
            }
        }

        return new ProtocolFactsSnapshot(
            GetRequiredString(root, "protocol_version"),
            GetRequiredString(root, "tool_schema_version"),
            GetRequiredString(root, "server_name"),
            GetRequiredString(root, "server_version"),
            errorCodes);
    }

    private static string GetRequiredString(JsonElement root, string propertyName)
    {
        if (!root.TryGetProperty(propertyName, out var element) || element.ValueKind != JsonValueKind.String)
        {
            throw new InvalidOperationException($"MCP protocol facts are missing required string property '{propertyName}'.");
        }

        return element.GetString() ?? string.Empty;
    }

    private sealed record ProtocolFactsSnapshot(
        string ProtocolVersion,
        string ToolSchemaVersion,
        string ServerName,
        string ServerVersion,
        IReadOnlyDictionary<string, string> ErrorCodes);
}