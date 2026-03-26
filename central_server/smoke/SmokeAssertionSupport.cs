using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal static class SmokeAssertionSupport
{
    public static void EnsureSuccess(CentralToolCallResponse response, string toolName)
    {
        if (response.IsError)
        {
            var payloadText = SmokePayloadSupport.TrySerializeForDiagnostic(response.StructuredContent);
            throw new CentralToolException($"{toolName} failed during smoke test: {response.TextContent}. Payload: {payloadText}");
        }
    }

    public static JsonElement EnsureExpectedError(CentralToolCallResponse response, string toolName, string expectedError)
    {
        var payload = SmokePayloadSupport.SerializeToElement(response.StructuredContent);
        if (!response.IsError)
        {
            throw new CentralToolException(
                $"{toolName} was expected to fail with {expectedError}, but it succeeded. Payload: {SmokePayloadSupport.TrySerializeForDiagnostic(response.StructuredContent)}");
        }

        if (payload.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} returned a non-object error payload during smoke test.");
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

    public static JsonElement EnsurePayloadDataObject(
        JsonElement payload,
        string propertyName,
        JsonValueKind expectedValueKind,
        string toolName,
        string? expectedStringValue = null)
    {
        if (payload.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} payload is not an object.");
        }

        if (!payload.TryGetProperty("data", out var dataElement) || dataElement.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} payload is missing a data object.");
        }

        if (!dataElement.TryGetProperty(propertyName, out var propertyElement))
        {
            throw new CentralToolException($"{toolName} payload data is missing '{propertyName}'.");
        }

        if (propertyElement.ValueKind != expectedValueKind)
        {
            throw new CentralToolException($"{toolName} payload data '{propertyName}' has unexpected kind {propertyElement.ValueKind}; expected {expectedValueKind}.");
        }

        if (expectedValueKind == JsonValueKind.String && expectedStringValue is not null)
        {
            var actualValue = propertyElement.GetString();
            if (!string.Equals(actualValue, expectedStringValue, StringComparison.Ordinal))
            {
                throw new CentralToolException($"{toolName} payload data '{propertyName}' returned '{actualValue}', expected '{expectedStringValue}'.");
            }
        }

        return propertyElement;
    }
}
