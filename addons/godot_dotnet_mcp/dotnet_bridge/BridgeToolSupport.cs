using System.Globalization;
using System.Text.Json;

namespace GodotDotnetMcp.DotnetBridge;

internal sealed record BridgeToolCallResponse(bool IsError, object StructuredContent, string TextContent)
{
    public static BridgeToolCallResponse Success(object structuredContent)
    {
        return new BridgeToolCallResponse(false, structuredContent, BridgeSerialization.SerializeCompact(structuredContent));
    }

    public static BridgeToolCallResponse Error(string message, object? structuredContent = null)
    {
        return new BridgeToolCallResponse(
            true,
            structuredContent ?? new { message },
            message);
    }
}

internal static class BridgeArgumentReader
{
    public static bool TryGetString(JsonElement arguments, string name, out string? value)
    {
        value = null;
        return TryGetProperty(arguments, name, out var property)
               && property.ValueKind == JsonValueKind.String
               && (value = property.GetString()) is not null;
    }

    public static string GetRequiredString(JsonElement arguments, string name)
    {
        if (!TryGetString(arguments, name, out var value) || string.IsNullOrWhiteSpace(value))
        {
            throw new BridgeToolException($"Missing required string argument '{name}'.");
        }

        return value;
    }

    public static string GetStringOrDefault(JsonElement arguments, string name, string defaultValue)
    {
        return TryGetString(arguments, name, out var value) && !string.IsNullOrWhiteSpace(value)
            ? value!
            : defaultValue;
    }

    public static IReadOnlyList<string> GetStringArray(JsonElement arguments, string name)
    {
        if (!TryGetProperty(arguments, name, out var property))
        {
            return Array.Empty<string>();
        }

        if (property.ValueKind != JsonValueKind.Array)
        {
            throw new BridgeToolException($"Argument '{name}' must be an array of strings.");
        }

        var values = new List<string>();
        foreach (var item in property.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.String)
            {
                throw new BridgeToolException($"Argument '{name}' must only contain strings.");
            }

            values.Add(item.GetString() ?? string.Empty);
        }

        return values;
    }

    private static bool TryGetProperty(JsonElement arguments, string name, out JsonElement property)
    {
        property = default;
        return arguments.ValueKind == JsonValueKind.Object && arguments.TryGetProperty(name, out property);
    }
}

internal sealed class BridgeToolException : Exception
{
    public BridgeToolException(string message)
        : base(message)
    {
    }
}

internal sealed record DiagnosticSummary(
    string Severity,
    string Code,
    string Message,
    string? FilePath,
    int? Line,
    int? Column);

internal static class DiagnosticSummaryExtensions
{
    public static IReadOnlyDictionary<string, int> BuildSummary(IEnumerable<DiagnosticSummary> diagnostics)
    {
        var items = diagnostics.ToArray();
        return new Dictionary<string, int>
        {
            ["errorCount"] = items.Count(item => item.Severity.Equals("error", StringComparison.OrdinalIgnoreCase)),
            ["warningCount"] = items.Count(item => item.Severity.Equals("warning", StringComparison.OrdinalIgnoreCase)),
        };
    }
}
