using System.Net.Http.Json;
using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorProxyService : IDisposable
{
    private readonly HttpClient _httpClient;

    public EditorProxyService()
    {
        _httpClient = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(10),
        };
    }

    public async Task<ForwardedToolCallResult> ForwardToolCallAsync(
        EditorSessionService.EditorSessionStatus session,
        string toolName,
        JsonElement toolArguments,
        CancellationToken cancellationToken)
    {
        ValidateSession(session);

        var endpoint = BuildEndpoint(session);
        return await ForwardToolCallToEndpointAsync(endpoint, toolName, toolArguments, cancellationToken);
    }

    public Task<ForwardedToolCallResult> ForwardToolCallToEndpointAsync(
        string serverHost,
        int serverPort,
        string toolName,
        JsonElement toolArguments,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(serverHost) || serverPort <= 0)
        {
            throw new CentralToolException("A valid proxy endpoint is required.");
        }

        return ForwardToolCallToEndpointAsync(BuildEndpoint(serverHost, serverPort), toolName, toolArguments, cancellationToken);
    }

    private async Task<ForwardedToolCallResult> ForwardToolCallToEndpointAsync(
        string endpoint,
        string toolName,
        JsonElement toolArguments,
        CancellationToken cancellationToken)
    {
        var rpcRequest = new
        {
            jsonrpc = "2.0",
            id = $"central-proxy-{Guid.NewGuid():N}",
            method = "tools/call",
            @params = new
            {
                name = toolName,
                arguments = toolArguments,
            },
        };

        using var response = await _httpClient.PostAsJsonAsync(endpoint, rpcRequest, CentralServerSerialization.JsonOptions, cancellationToken);
        var responseText = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            throw new CentralToolException($"Editor proxy HTTP request failed with status {(int)response.StatusCode}.");
        }

        try
        {
            using var document = JsonDocument.Parse(responseText);
            var root = document.RootElement;

            if (root.TryGetProperty("error", out var errorElement))
            {
                var message = errorElement.TryGetProperty("message", out var messageElement) && messageElement.ValueKind == JsonValueKind.String
                    ? messageElement.GetString() ?? "Editor proxy JSON-RPC error."
                    : "Editor proxy JSON-RPC error.";
                return new ForwardedToolCallResult(false, message, endpoint, new Dictionary<string, object?>
                {
                    ["jsonRpcError"] = JsonSerializer.Deserialize<object>(errorElement.GetRawText(), CentralServerSerialization.JsonOptions),
                });
            }

            if (!root.TryGetProperty("result", out var resultElement) || resultElement.ValueKind != JsonValueKind.Object)
            {
                throw new CentralToolException("Editor proxy response did not contain a JSON-RPC result object.");
            }

            var isError = resultElement.TryGetProperty("isError", out var isErrorElement)
                          && isErrorElement.ValueKind is JsonValueKind.True or JsonValueKind.False
                          && isErrorElement.GetBoolean();

            var contentText = ExtractPrimaryContentText(resultElement);
            object? parsedToolResult = null;
            if (!string.IsNullOrWhiteSpace(contentText))
            {
                parsedToolResult = JsonSerializer.Deserialize<object>(contentText, CentralServerSerialization.JsonOptions);
            }

            return new ForwardedToolCallResult(!isError, string.Empty, endpoint, parsedToolResult);
        }
        catch (JsonException ex)
        {
            throw new CentralToolException($"Editor proxy response parsing failed: {ex.Message}");
        }
    }

    private static void ValidateSession(EditorSessionService.EditorSessionStatus session)
    {
        if (!session.Attached)
        {
            throw new CentralToolException("Editor proxy requires an attached editor session.");
        }

        var transportMode = session.TransportMode.Trim();
        if (!string.Equals(transportMode, "http", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(transportMode, "both", StringComparison.OrdinalIgnoreCase))
        {
            throw new CentralToolException("Attached editor session does not expose an HTTP MCP endpoint.");
        }

        if (!session.ServerRunning)
        {
            throw new CentralToolException("Attached editor session is not currently serving MCP over HTTP.");
        }

        if (string.IsNullOrWhiteSpace(session.ServerHost) || session.ServerPort is null || session.ServerPort <= 0)
        {
            throw new CentralToolException("Attached editor session did not report a valid HTTP endpoint.");
        }
    }

    private static string BuildEndpoint(EditorSessionService.EditorSessionStatus session)
    {
        return BuildEndpoint(session.ServerHost, session.ServerPort ?? 0);
    }

    private static string BuildEndpoint(string serverHost, int serverPort)
    {
        return $"http://{serverHost}:{serverPort}/mcp";
    }

    private static string ExtractPrimaryContentText(JsonElement resultElement)
    {
        if (!resultElement.TryGetProperty("content", out var contentElement) || contentElement.ValueKind != JsonValueKind.Array)
        {
            return string.Empty;
        }

        foreach (var item in contentElement.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object)
            {
                continue;
            }

            if (item.TryGetProperty("text", out var textElement) && textElement.ValueKind == JsonValueKind.String)
            {
                return textElement.GetString() ?? string.Empty;
            }
        }

        return string.Empty;
    }

    public void Dispose()
    {
        _httpClient.Dispose();
    }

    internal sealed record ForwardedToolCallResult(bool Success, string Message, string Endpoint, object? ToolResult);
}
