using System.Text.Json;
using GodotDotnetMcp.CentralServer;

internal static class ContractAssertions
{
    public static void EnsureSuccess(CentralToolCallResponse response, string toolName)
    {
        if (response.IsError)
        {
            var payloadText = ContractPayloadSupport.TrySerializeForDiagnostic(response.StructuredContent);
            throw new CentralToolException($"{toolName} failed during host contract test: {response.TextContent}. Payload: {payloadText}");
        }
    }

    public static JsonElement EnsureExpectedError(CentralToolCallResponse response, string toolName, string expectedError)
    {
        var payload = ContractPayloadSupport.SerializeToElement(response.StructuredContent);
        if (!response.IsError)
        {
            throw new CentralToolException(
                $"{toolName} was expected to fail with {expectedError}, but it succeeded. Payload: {ContractPayloadSupport.TrySerializeForDiagnostic(response.StructuredContent)}");
        }

        if (payload.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} returned a non-object error payload during host contract test.");
        }

        if (!payload.TryGetProperty("error", out var errorElement) || errorElement.ValueKind != JsonValueKind.String)
        {
            throw new CentralToolException($"{toolName} error payload is missing a string error code.");
        }

        var actualError = errorElement.GetString() ?? string.Empty;
        if (!string.Equals(actualError, expectedError, StringComparison.Ordinal))
        {
            throw new CentralToolException($"{toolName} returned unexpected error '{actualError}'. Expected '{expectedError}'. Payload: {payload.GetRawText()}");
        }

        return payload;
    }

    public static void AssertContains(IEnumerable<string> values, string expected)
    {
        if (!values.Any(value => string.Equals(value, expected, StringComparison.Ordinal)))
        {
            throw new InvalidOperationException($"Expected value '{expected}' was not found.");
        }
    }

    public static void AssertNestedString(JsonElement root, string expected, params string[] path)
    {
        var actual = GetNestedString(root, path);
        if (!string.Equals(actual, expected, StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Expected '{expected}' at path '{string.Join(".", path)}', got '{actual}'.");
        }
    }

    public static void AssertNestedBoolean(JsonElement root, bool expected, params string[] path)
    {
        var current = GetNestedElement(root, path);
        var actual = current.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            _ => throw new InvalidOperationException($"Expected boolean at path '{string.Join(".", path)}', got {current.ValueKind}."),
        };

        if (actual != expected)
        {
            throw new InvalidOperationException($"Expected '{expected}' at path '{string.Join(".", path)}', got '{actual}'.");
        }
    }

    public static void AssertDifferentStrings(string first, string second, string description)
    {
        if (string.Equals(first, second, StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Expected different values for {description}, but both were '{first}'.");
        }
    }

    public static string GetNestedString(JsonElement root, params string[] path)
    {
        var current = GetNestedElement(root, path);
        if (current.ValueKind != JsonValueKind.String)
        {
            throw new InvalidOperationException($"Expected string at path '{string.Join(".", path)}', got {current.ValueKind}.");
        }

        return current.GetString() ?? string.Empty;
    }

    private static JsonElement GetNestedElement(JsonElement root, params string[] path)
    {
        var current = root;
        foreach (var segment in path)
        {
            if (current.ValueKind != JsonValueKind.Object || !current.TryGetProperty(segment, out current))
            {
                throw new InvalidOperationException($"Missing property '{segment}' while resolving path '{string.Join(".", path)}'.");
            }
        }

        return current;
    }
}
