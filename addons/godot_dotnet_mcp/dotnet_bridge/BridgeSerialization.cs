using System.Text.Json;

namespace GodotDotnetMcp.DotnetBridge;

internal static class BridgeSerialization
{
    internal static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
    };

    internal static string SerializeCompact<T>(T value)
    {
        return JsonSerializer.Serialize(value, JsonOptions);
    }
}
