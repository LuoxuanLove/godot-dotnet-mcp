using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal static class CentralServerSerialization
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
