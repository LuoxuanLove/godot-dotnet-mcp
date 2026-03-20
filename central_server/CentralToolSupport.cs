using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed record CentralToolCallResponse(bool IsError, object StructuredContent, string TextContent)
{
    public static CentralToolCallResponse Success(object structuredContent)
    {
        return new CentralToolCallResponse(false, structuredContent, CentralServerSerialization.SerializeCompact(structuredContent));
    }

    public static CentralToolCallResponse Error(string message, object? structuredContent = null)
    {
        return new CentralToolCallResponse(
            true,
            structuredContent ?? new { message },
            message);
    }
}

internal static class CentralArgumentReader
{
    public static bool TryGetString(JsonElement arguments, string name, out string? value)
    {
        value = null;
        return TryGetProperty(arguments, name, out var property)
               && property.ValueKind == JsonValueKind.String
               && (value = property.GetString()) is not null;
    }

    public static string? GetOptionalString(JsonElement arguments, string name)
    {
        return TryGetString(arguments, name, out var value) && !string.IsNullOrWhiteSpace(value)
            ? value
            : null;
    }

    public static string GetRequiredString(JsonElement arguments, string name)
    {
        var value = GetOptionalString(arguments, name);
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new CentralToolException($"Missing required string argument '{name}'.");
        }

        return value;
    }

    public static bool GetBooleanOrDefault(JsonElement arguments, string name, bool defaultValue)
    {
        if (!TryGetProperty(arguments, name, out var property))
        {
            return defaultValue;
        }

        return property.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            _ => defaultValue,
        };
    }

    public static IReadOnlyList<string> GetStringArray(JsonElement arguments, string name)
    {
        if (!TryGetProperty(arguments, name, out var property))
        {
            return Array.Empty<string>();
        }

        if (property.ValueKind != JsonValueKind.Array)
        {
            throw new CentralToolException($"Argument '{name}' must be an array of strings.");
        }

        var values = new List<string>();
        foreach (var item in property.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.String)
            {
                throw new CentralToolException($"Argument '{name}' must only contain strings.");
            }

            var value = item.GetString();
            if (!string.IsNullOrWhiteSpace(value))
            {
                values.Add(value);
            }
        }

        return values;
    }

    public static object GetObjectOrEmpty(JsonElement arguments, string name)
    {
        if (!TryGetProperty(arguments, name, out var property))
        {
            return new Dictionary<string, object?>();
        }

        if (property.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"Argument '{name}' must be an object.");
        }

        return JsonSerializer.Deserialize<object>(property.GetRawText(), CentralServerSerialization.JsonOptions)
               ?? new Dictionary<string, object?>();
    }

    public static JsonElement GetObjectElementOrEmpty(JsonElement arguments, string name)
    {
        if (!TryGetProperty(arguments, name, out var property))
        {
            using var emptyDocument = JsonDocument.Parse("{}");
            return emptyDocument.RootElement.Clone();
        }

        if (property.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"Argument '{name}' must be an object.");
        }

        return property.Clone();
    }

    private static bool TryGetProperty(JsonElement arguments, string name, out JsonElement property)
    {
        property = default;
        return arguments.ValueKind == JsonValueKind.Object && arguments.TryGetProperty(name, out property);
    }
}

internal sealed class CentralToolException : Exception
{
    public CentralToolException(string message)
        : base(message)
    {
    }
}
